/*
    MIT License

    Copyright (c) 2021-2025 Advanced Micro Devices, Inc. All rights reserved

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

// =======================================================
//
// Purpose: Read a matrix market in coordinate format to solve by MUMPS
//
// Usage : mpirun -np X "executable" --mtx <mtx input file> --perf_mode <enable_perf_mode> --iter <no_of_performance_iterations>
// Standard C++ includes
//
#ifdef MUMPS_MPI
#include <mpi.h>
#endif
#include <omp.h>
#include "cblas.hh"
#include "dmumps_c.h"
#include <math.h>
#include <cstdlib>
#include <iomanip>
#include <cstdio>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <boost/algorithm/string.hpp>

/* Check that the size of integers in the used libraries is OK. */
static_assert(
    sizeof(f77_int) == sizeof(MUMPS_INT),
    "Error: Incompatible size of ints in blis. Using wrong header or compilation of the library?");

#define JOB_INIT -1
#define JOB_END -2
#define USE_COMM_WORLD -987654

//
// Timing includes
//
# include  <chrono>
using ns = std::chrono::nanoseconds;
using get_time = std::chrono::steady_clock;

using namespace std;

/*
    structure to store matrix data from mtx file in co-ordinate storage format
*/
template<typename ILP_INT, typename T>
struct _coo_matrix {
    ILP_INT m;
    ILP_INT n;
    ILP_INT nnz;
    std::vector<ILP_INT> row_idxs;
    std::vector<ILP_INT> col_idxs;
    std::vector<double> values;
};
typedef struct _coo_matrix<MUMPS_INT, double> coo_matrix;

/*
    usage function
*/
void print_help(char* mumps_bench)
{
    cout << "\nUsage: " << mumps_bench << " --mtx <mtx_input_file> --perf_mode <enable_perf_mode> --iter <no_of_performance_iterations>\n";
    cout << "\tmtx_input_file: input matrix in Matrix Market Format\n";    
    cout << "\tenable_perf_mode: 0 = for functional tests, >1 = perf runs)\n";
    cout << "\tno_of_performance_iterations: number of hot calls for performance runs\n";    
    return;
}
/*
    =======main=========
*/
int main(int argc, char* argv[]) 
{
    //mpi variables
    int myid, ierr;
    int comm_size;

#ifdef MUMPS_MPI
    ierr = MPI_Init(&argc, &argv);
    ierr = MPI_Comm_rank(MPI_COMM_WORLD, &myid);
    ierr = MPI_Comm_size(MPI_COMM_WORLD, &comm_size);        
#endif 

    // args
    string matrix_name;
    bool enable_perf_mode = false;
    int number_hot_calls = 1;

    // data     
        /*
        * SYM = 0: A is unsymmetric
        * SYM = 1: A is SPD
        * SYM = 2: A is general symmetric
        */    
    int symVal = 1;
    coo_matrix matrix;
    DMUMPS_STRUC_C id;
    MUMPS_INT nnz, i, nrhs;
    MUMPS_INT m, n;
    MUMPS_INT rid, cid;
    std::vector<double> rhs, x;    
    double value, relativeError = 0;

    // file reading
    std::string fileline;
    int cnt = 0;
    bool are_dimensions_read = false;
    std::string ignore;
    std::string matrix_format;
    std::string arithmetic_field;
    std::string symmetry_structure;    
    if (argc < 7) 
    {
        print_help(argv[0]);
        return 1;
    } 

    // read arguments
    for (int i = 1; i < argc; i+=2) 
    {
        if (strcmp(argv[i], "--mtx") == 0) 
        {
            matrix_name = argv[i+1];
        } else if (strcmp(argv[i], "--perf_mode") == 0) 
        {
            enable_perf_mode = std::stoi(argv[i+1]) > 0;
        } else if (strcmp(argv[i], "--iter") == 0) 
        {
            number_hot_calls = (std::max)(1, std::stoi(argv[i+1]));
        } else 
        {
            cout << "Invalid option " << argv[i] << endl;
            print_help(argv[0]);
            return 1;
        }
    }

    nrhs = 1;
    //   Create the ifstream reader  
    std::ifstream mmfile(matrix_name);
    if (!mmfile) {
        std::cerr << "Failed to open file " << matrix_name << std::endl;
        return 1;
    }
    
    // -----------------------------------------
    //   Read the matrix
    // -----------------------------------------
    
    while (getline(mmfile, fileline)) 
    {
        if(fileline.empty() || (fileline[0] == '%' && fileline[1] != '%')) 
        {           
            //comment ignore
            continue;
        }
        else if(fileline.empty() || (fileline[0] == '%' && fileline[1] == '%')) 
        {
            //header banner
            std::stringstream ss;
            ss << fileline;
            ss >> ignore;
            ss >> ignore;

            ss >> matrix_format;
            ss >> arithmetic_field;
            ss >> symmetry_structure; 

            //banner validation checks
            if (matrix_format != "coordinate" && matrix_format != "array") {
                std::cerr << "Invalid Matrix format in the header banner: " << matrix_format << std::endl;
                exit(1);
            }
            if (arithmetic_field != "real" && arithmetic_field != "complex" && arithmetic_field != "integer" && arithmetic_field != "pattern") {
                std::cerr << "Invalid arithmetic field in the header banner: " << arithmetic_field << std::endl;
                exit(1);
            }
            //todo: to_lower() conversions to be done on 'symmetry_structure' before comparison to "skew-symmetric" and "hermitian" cases
            if (symmetry_structure != "general" && symmetry_structure != "symmetric" && symmetry_structure != "skew-symmetric" && symmetry_structure != "hermitian") {
                std::cerr << "Invalid symmetry structure in the header banner: " << symmetry_structure << std::endl;
                exit(1);
            }     

            //unsupported cases
            if (matrix_format != "coordinate") {
                std::cerr << "array matrix format not supported" << std::endl;
                exit(1);
            }       
            if (arithmetic_field != "real" && arithmetic_field != "integer") {
                std::cerr << "complex/pattern fields not supported" << std::endl;
                exit(1);
            } 
            if (symmetry_structure != "symmetric" && symmetry_structure != "general") {
                std::cerr << "skew-symmetric and hermitian structures not supported" << std::endl;
                exit(1);
            }                              
        }
        else if(!are_dimensions_read)
        {
            //read dimensions
            std::stringstream ss_dims;
            ss_dims << fileline;
            ss_dims >> m;
            ss_dims >> n;
            ss_dims >> nnz;
            matrix.m = m;
            matrix.n = n;
            matrix.nnz = nnz;             

            // Allocate arrays with the given dimensional data
            try{
                matrix.row_idxs.resize(nnz);
            }
            catch(std::bad_alloc &){
                exit(1);
            }
            try{
                matrix.col_idxs.resize(nnz);
            }
            catch(std::bad_alloc &){
                exit(1);
            } 
            try{
                matrix.values.resize(nnz);
            }
            catch(std::bad_alloc &){
                exit(1);
            } 
            
            are_dimensions_read = true;
        }        
        else if(are_dimensions_read)
        {
            //read data triplet
            std::stringstream ss_data;
            ss_data << fileline;
            ss_data >> rid;
            ss_data >> cid;   
            ss_data >> value;         

            //negative indices since row/col indices are not 1-based, which is expected in mtx/coo format
            if(((rid - 1) < 0) || ((cid - 1) < 0))
            {
                exit(1);
            }
            matrix.row_idxs[cnt] = rid;
            matrix.col_idxs[cnt] = cid;
            matrix.values[cnt] = value;
            cnt++;
        }        
    }    
    mmfile.close();
    // Allocate arrays and initialize RHS 
    rhs.resize(nnz, 0.0); 
    x.resize(nnz, 0.0); 

    if(m != n)
    {
        std::cerr << "MUMPS requires a square sparse matrix that can be either unsymmetric, symmetric positive definite, or general symmetric"
                  << std::endl;
        return -1;
    }

    // ---------------------------------------------
    //   Setup the MUMPS Solver  
    // ---------------------------------------------

    /* Initialize a MUMPS instance. Use MPI_COMM_WORLD */
    id.job = JOB_INIT; /* JOB = -1 : initializes an instance of the package */
    id.comm_fortran = USE_COMM_WORLD;
    id.sym = symVal;
    id.par = 1; /* The host is also involved in the parallel steps of the factorization and solve phases */

    dmumps_c(&id);
    if (id.infog[0] < 0){
        std::cout << "[PROCESS: " << myid << "] Mumps Init phase failed. Error returned: \n\tINFOG(1)=" << id.infog[0] << "\n\tINFOG(2)=" << id.infog[1] << "\n";
        return 1;
    }

    #define ICNTL(I) icntl[(I)-1] /* macro s.t. indices match documentation */
    id.ICNTL(1) = 6; /*output stream for error messages: TO STD OUTPUT STREAM*/
    id.ICNTL(2) = 0; /*put stream for diagnostic printing and statistics local to each MPI process: SUPPRESSED*/
    id.ICNTL(3) = 6; /*utput stream for global information, collected on the host: TO STD OUTPUT STREAM*/
    id.ICNTL(4) = 1; /* level of printing: Errors, warnings, and main statistics printed: ONLY ERROR MSGES PRINTED */
    id.ICNTL(7) = 5; /* computes a symmetric permutation (ordering) to determine the pivot order to be used for the factorization in case of sequential analysis: METIS*/
    id.ICNTL(10) = 0; /* max num of iterative refinements: Fixed number of steps of iterative refinement. No stopping criterion is used */
    id.ICNTL(14) = 20; /* controls the percentage increase in the estimated working space: 20 (which corresponds to a 20 % increase) */
    id.ICNTL(22) = 0; /* controls the in-core/out-of-core (OOC) factorization and solve: In-core factorization and solution phases */
    id.ICNTL(23) = 250000; /* max size of the working memory (MB) that can allocate per processor: each processor will allocate workspace based on the estimates computed during the analysis*/    
    id.ICNTL(24) = 1; /* controls the detection of �null pivot rows�: Null pivot row detection*/  

    /* Define the problem on the host */
    if (myid == 0) {
        id.n = n; 
        id.nz = nnz; 
        id.irn = &matrix.row_idxs[0]; 
        id.jcn = &matrix.col_idxs[0];
        id.a = &matrix.values[0]; 
        id.rhs = &x[0];
        id.nrhs = nrhs; 
        id.lrhs = n;
    }
    
    // ---------------------------------------------
    //   Analysis: Preprocessing and Symbolic Factorization
    // ---------------------------------------------     
    id.job = 1; /* performs the analysis */
    dmumps_c(&id);
    if (id.infog[0] < 0){
        std::cout << "[PROCESS: " << myid << "] Mumps analysis phase failed. Error returned: \n\tINFOG(1)=" << id.infog[0] << "\n\tINFOG(2)=" << id.infog[1] << "\n";
        return 1;
    }

    // ---------------------------------------------
    //   Factorization
    // ---------------------------------------------
    id.job = 2; /* performs the factorization */
    dmumps_c(&id);
    if (id.infog[0] < 0){
        std::cout << "[PROCESS: " << myid << "] Mumps factorization phase failed. Error returned: \n\tINFOG(1)=" << id.infog[0] << "\n\tINFOG(2)=" << id.infog[1] << "\n";
        return 1;
    }

    // ---------------------------------------------
    //   Solution
    // ---------------------------------------------
    id.job = 3; /* computes the solution */
    dmumps_c(&id);
    if (id.infog[0] < 0){
        std::cout << "[PROCESS: " << myid << "] Mumps solution phase failed. Error returned: \n\tINFOG(1)=" << id.infog[0] << "\n\tINFOG(2)=" << id.infog[1] << "\n";
        return 1;
    } 

    // ---------------------------------------------
    //  Configure Hot calls / Cold Calls
    // --------------------------------------------
    std::fill(x.begin(), x.end(), 0.0); //reinitialize rhs
    const int number_cold_calls = 5;    
    std::chrono::duration<double, std::nano> analysis_time, factorization_time, solution_time;
    if(enable_perf_mode)
    {
        // ---------------------------------------------
        //  Performance Mode - Warmp up
        // --------------------------------------------
        for(int q=0; q<number_cold_calls;q++)
        {    
            id.job = 1;     /* performs the analysis */
            dmumps_c(&id);     
        }
        for(int q=0; q<number_cold_calls;q++)
        {    
            id.job = 2;     /* performs the factorization */
            dmumps_c(&id);     
        }
        for(int q=0; q<number_cold_calls;q++)
        {    
            id.job = 3;     /* performs the solution */
            dmumps_c(&id);     
        }   

        // ---------------------------------------------
        //  Performance Mode - Hot calls
        // --------------------------------------------
        std::fill(x.begin(), x.end(), 0.0); //reinitialize rhs
        // ---------------------------------------------
        //   Analysis
        // ---------------------------------------------  
        auto t1 = get_time::now();
        for(int q=0; q<number_hot_calls;q++)
        {    
            id.job = 1;     /* performs the analysis */
            dmumps_c(&id);     
        }
        analysis_time = (get_time::now() - t1)/number_hot_calls;

        // ---------------------------------------------
        //   Factorization
        // ---------------------------------------------    
        auto t2 = get_time::now();
        for(int q=0; q<number_hot_calls;q++)
        {    
            id.job = 2; /* performs the factorization */    
            dmumps_c(&id);     
        }
        factorization_time = (get_time::now() - t2)/number_hot_calls;
        // ---------------------------------------------
        //   Solution
        // ---------------------------------------------                
        auto t3 = get_time::now();
        for(int q=0; q<number_hot_calls;q++)
        {    
            id.job = 3; /* computes the solution */
            dmumps_c(&id);     
        }
        solution_time = (get_time::now() - t3)/number_hot_calls;                        
    } 

    // ---------------------------------------------
    //   Termination and release of memory.
    // ---------------------------------------------
    id.job = JOB_END; /* JOB = -2 : terminates an instance of the package */
    dmumps_c(&id);
    if (id.infog[0] < 0){
        std::cout << "[PROCESS: " << myid << "] Mumps temination phase failed. Error returned: \n\tINFOG(1)=" << id.infog[0] << "\n\tINFOG(2)=" << id.infog[1] << "\n";
        return 1;
    }

    //todo: relook at relative error computation
    double numerator = 0.0;
    for (int i = 1; i < n; i++)
    {
        numerator += pow((x[i] - 1.0), 2);
    }
    numerator = sqrt(numerator);
    double denominator = sqrt(static_cast<double>(n));
    relativeError = numerator / denominator;
   
    // MPI terminate
#ifdef MUMPS_MPI
    ierr = MPI_Finalize();
#endif

    // ---------------------------------------------
    //   Important statistics
    // ---------------------------------------------
    if (myid == 0)
    {
        int ompNumThrds = omp_get_num_threads();
        double sparsity_percent = 0.0;
        double analysis_t = 0.0, factor_t = 0.0, solve_t = 0.0, afs_t = 0.0, fs_t = 0.0;
        sparsity_percent = (n * n) - nnz;
        sparsity_percent = sparsity_percent / (n * n);
        sparsity_percent = sparsity_percent * 100;
        analysis_t = std::chrono::duration_cast<ns>(analysis_time).count() / 1.0e9;
        factor_t = std::chrono::duration_cast<ns>(factorization_time).count() / 1.0e9;
        solve_t = std::chrono::duration_cast<ns>(solution_time).count() / 1.0e9;
        afs_t = std::chrono::duration_cast<ns>(analysis_time + factorization_time + solution_time).count() / 1.0e9;
        fs_t = std::chrono::duration_cast<ns>(factorization_time + solution_time).count() / 1.0e9;
        std::cout << std::endl;  
        std::cout.precision(2);
        std::cout.setf(std::ios::fixed);
        std::cout.setf(std::ios::left);

        std::cout << std::setw(12) << "M" 
                << std::setw(12) << "N" 
                << std::setw(12) << "nnz"
                << std::setw(12) << "mpi_ranks" 
                << std::setw(12) << "omp_thrds" 
                << std::setw(12) << "sparsity_%" 
                << std::setw(16) << "analysis_time" 
                << std::setw(16) << "fact_time" 
                << std::setw(16) << "solve_time" 
                << std::setw(16) << "afs_time" 
                << std::setw(16) << "fs_time" 
                << std::setw(12) << "relativeError" 
                << std::endl;

        std::cout << std::setw(12) << m
                << std::setw(12) << n 
                << std::setw(12) << nnz
                << std::setw(12) << comm_size 
                << std::setw(12) << ompNumThrds 
                << std::setw(12) << sparsity_percent 
                << std::setw(16) << std::scientific << analysis_t
                << std::setw(16) << std::scientific << factor_t
                << std::setw(16) << std::scientific << solve_t 
                << std::setw(16) << std::scientific << afs_t 
                << std::setw(16) << std::scientific << fs_t
                << std::setw(12) << std::fixed << relativeError << std::endl;          

    }

    return 0;
}
