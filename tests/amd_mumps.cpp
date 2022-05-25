/*
    MIT License

    Copyright (c) <2021> Advanced Micro Devices, Inc. All rights reserved

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
// Usage : mpirun -np X "executable" "inputmatrix"
// Standard C++ includes
//
#include <mpi.h>
#include <math.h>
#include <sstream>
#include <fstream>
#include <iostream>
#include <cstdlib>
#include <iomanip>
#include <vector>
#include <string>
#include <cstdio>
#include <boost/algorithm/string.hpp>
//#include <mkl.h>
#include <omp.h>
#include "dmumps_c.h"
#define JOB_INIT -1
#define JOB_END -2
#define USE_COMM_WORLD -987654
#define PARAM_LOG

//
// Timing includes
//
# include  <chrono>
using ns = std::chrono::nanoseconds;
using get_time = std::chrono::steady_clock;

int main(int argc, char* argv[]) {

    if (argc != 3) //checks the amount of CL args
    {
        printf("Usage: amd_aocl.exe <input mtx file> <symmetry_type>\n");
		printf("\t symmetry_type = 0: A is unsymmetric\n");
		printf("\t symmetry_type = 1: A is SPD\n");
		printf("\t symmetry_type = 2: A is general symmetric\n");
        return 1;
    }
    const std::string matrix_name = argv[1];
    const int symVal = atoi(argv[2]);
    std::string fileline;
    std::vector<std::string> vecstrng;
    char* filechar;

    DMUMPS_STRUC_C id;
    MUMPS_INT nrows, ncols;
    MUMPS_INT nnz, i, nrhs;
    MUMPS_INT* irn;
    MUMPS_INT* jcn;
    double* aa;
    double* rhs, * duprhs;

    int myid, ierr;
    int comm_size;

    FILE* f;
    nrhs = 1;

    // =======================================
    //   Beginning of Executable Statements
    // =======================================

#ifdef VERBOSE_OUTPUT
    std::cout << "before mpiInit" << std::endl;
#endif
    ierr = MPI_Init(&argc, &argv);
    ierr = MPI_Comm_rank(MPI_COMM_WORLD, &myid);
    ierr = MPI_Comm_size(MPI_COMM_WORLD, &comm_size);


    if (myid == 0)
    {
#ifdef VERBOSE_OUTPUT
        std::cout << " - matrix_name = " << matrix_name << std::endl;
        std::cout << "MPI comm size  = " << comm_size << std::endl;
#endif
    }

    vecstrng.reserve(5);
    // -----------------------------------------
    //   Read in the matrix
    // -----------------------------------------

    //   Create the ifstream reader  
    std::ifstream mmfile(matrix_name.c_str());

    //   Get first line which is junk
    std::getline(mmfile, fileline);

    //   Get second line which has dimension data
    std::getline(mmfile, fileline);
    boost::algorithm::trim(fileline);
    boost::algorithm::split(vecstrng, fileline, boost::is_any_of(" "), boost::token_compress_on);

    nrows = atoi(vecstrng[0].c_str());
    ncols = atoi(vecstrng[1].c_str());
    nnz = atoi(vecstrng[2].c_str());

    //   Allocate arrays with the given dimensional data
    irn = new MUMPS_INT[nnz]; // row index
    jcn = new MUMPS_INT[nnz]; // col index
    aa = new double[nnz];    // value
    rhs = new double[nrows]; // dummy rhs.

    std::cout << std::fixed << std::setprecision(20);
    int cnt = 0;
    while (getline(mmfile, fileline)) {
        filechar = strtok((char*)fileline.c_str(), " ");
        irn[cnt] = atoi(filechar);
        filechar = strtok(NULL, " ");
        jcn[cnt] = atoi(filechar);
        filechar = strtok(NULL, " ");
        aa[cnt] = atof(filechar);
        cnt++;
    }
    mmfile.close();
#ifdef VERBOSE_OUTPUT
    std::cout << " Done reading in the matrix ..." << std::endl;
#endif
    // --- Set DUM RHS ---
    for (i = 0; i < nrows; i++)
    {
        rhs[i] = 0.0;
    }

    // --------------------------------------------- 
    //   Done reading in the matrix
    // ---------------------------------------------

    // ---------------------------------------------
    //   Setup the MUMPS Solver  
    // ---------------------------------------------

              /* Initialize a MUMPS instance. Use MPI_COMM_WORLD */
    id.job = JOB_INIT; /* JOB = -1 : initializes an instance of the package */
    id.comm_fortran = USE_COMM_WORLD;
    /*
    * SYM = 0: A is unsymmetric
    * SYM = 1: A is SPD
    * SYM = 2: A is general symmetric
    */
    id.sym = symVal;
    id.par = 1; /* The host is also involved in the parallel steps of the factorization and solve phases */

#ifdef VERBOSE_OUTPUT
    printf("Start Mumps Initialization, JOB Id = %d\n", id.job);
    fflush(stdout);
#endif
    dmumps_c(&id);
    if (id.infog[0] < 0)
    {
        printf("Error Return in Test application, id.infog[0] = %d\n", id.infog[0]);
        fflush(stdout);
        printf("Error Return in Test application, id.infog[1] = %d\n", id.infog[1]);
        fflush(stdout);
        printf("id.infog[2] = %d\n", id.infog[2]);
        fflush(stdout);
        return 1;
    }
#ifdef VERBOSE_OUTPUT
    printf("Done Mumps Initialization\n");
    fflush(stdout);
#endif

    /* Define the problem on the host */
    if (myid == 0) {
        id.n = nrows; id.nz = nnz; id.irn = irn; id.jcn = jcn;
        id.a = aa; id.rhs = rhs;
        id.nrhs = nrhs; id.lrhs = nrows;
    }
    //    mkl_set_dynamic(0);
    //    mkl_set_num_threads(24);
    //    omp_set_num_threads(24);


#define ICNTL(I) icntl[(I)-1] /* macro s.t. indices match documentation */
/* No outputs */

#ifndef VERBOSE_OUTPUT
    id.ICNTL(1) = 6;
    id.ICNTL(2) = 0;
    id.ICNTL(3) = 6;
    id.ICNTL(4) = 1; /* level of printing: Errors, warnings, and main statistics printed */
#endif    
    id.ICNTL(7) = 5; //5; /* use METIS ordering if previously installed by the user otherwise treated as 7*/
    /*
    id.ICNTL(7) = 7 means:
       Automatic choice by the software during analysis phase.This choice will depend on the
       ordering packages made available, on the matrix(type and size), and on the number of
       processors.
    */
    id.ICNTL(10) = 0; /* max num of iterative refinements */
    id.ICNTL(22) = 0; /* in core factorization */
    id.ICNTL(24) = 1; // null pivot detection
    id.ICNTL(14) = 20; /* percentage increase in the estimated working space - Default value: 20 (which corresponds to a 20 % increase) */
    /* When significant extra fill-in is caused by numerical pivoting, increasing ICNTL(14) may help */
    id.ICNTL(23) = 250000; // / 16; /* max size of the working memory (MB) that can allocate per processor - node2 on 16 processors*/
    //id.ICNTL(16) = num_thrds; /* SMP Threads*/
//    for (MUMPS_INT ii=0; ii<60; ii++) std::cout << "id.ICNTL ="<< id.ICNTL(ii) <<std::endl;
    // ---------------------------------------------
    //   Done with MUMPS Solver Setup  
    // ---------------------------------------------

    // ---------------------------------------------
    //   Symbolic Factorization
    // ---------------------------------------------     
    auto SymbolicFactorizationTimeBegin = get_time::now();
    id.job = 1; /* performs the analysis */
#ifdef VERBOSE_OUTPUT
    printf("Start Mumps Analysis, JOB Id = %d\n", id.job);
    fflush(stdout);
#endif
    dmumps_c(&id);
    if (id.infog[0] < 0)
    {
        printf("Error Return in Test application, id.infog[0] = %d\n", id.infog[0]);
        fflush(stdout);
        printf("Error Return in Test application, id.infog[1] = %d\n", id.infog[1]);
        fflush(stdout);
        printf("id.infog[2] = %d\n", id.infog[2]);
        fflush(stdout);
        return 1;
    }
#ifdef VERBOSE_OUTPUT
    printf("End Mumps Analysis\n");
    fflush(stdout);
#endif
    auto SymbolicFactorizationTime = get_time::now() - SymbolicFactorizationTimeBegin;

    // ---------------------------------------------
    //   Numeric Factorization
    // ---------------------------------------------
    auto NumericFactorizationTimeBegin = get_time::now();
    id.job = 2; /* performs the factorization */
#ifdef VERBOSE_OUTPUT
    printf("Start Mumps Factorization, JOB Id = %d\n", id.job);
    fflush(stdout);
#endif
    dmumps_c(&id);
    if (id.infog[0] < 0)
    {
        printf("Error Return in Test application, id.infog[0] = %d\n", id.infog[0]);
        fflush(stdout);
        printf("Error Return in Test application, id.infog[1] = %d\n", id.infog[1]);
        fflush(stdout);
        printf("id.infog[2] = %d\n", id.infog[2]);
        fflush(stdout);
        return 1;
    }
#ifdef VERBOSE_OUTPUT
    printf("End Mumps Factorization\n");
    fflush(stdout);
#endif
    auto NumericFactorizationTime = get_time::now() - NumericFactorizationTimeBegin;

    // ---------------------------------------------
    //   Back substitution
    // ---------------------------------------------
    auto FBSolveTimeBegin = get_time::now();
    id.job = 3; /* computes the solution */
#ifdef VERBOSE_OUTPUT
    printf("Start Mumps Solution, JOB Id = %d\n", id.job);
    fflush(stdout);
#endif
    dmumps_c(&id);
    if (id.infog[0] < 0)
    {
        printf("Error Return in Test application, id.infog[0] = %d\n", id.infog[0]);
        fflush(stdout);
        printf("Error Return in Test application, id.infog[1] = %d\n", id.infog[1]);
        fflush(stdout);
        printf("id.infog[2] = %d\n", id.infog[2]);
        fflush(stdout);
        return 1;
    }
#ifdef VERBOSE_OUTPUT
    printf("End Mumps Solution\n");
    fflush(stdout);
#endif

    auto FBSolveTime = get_time::now() - FBSolveTimeBegin;
    // ---------------------------------------------
    //   Termination and release of memory.
    // ---------------------------------------------
    id.job = JOB_END; /* JOB = -2 : terminates an instance of the package */
#ifdef VERBOSE_OUTPUT
    printf("Start Mumps Termination, JOB Id = %d\n", id.job);
    fflush(stdout);
#endif
    dmumps_c(&id);
    if (id.infog[0] < 0)
    {
        printf("Error Return in Test application, id.infog[0] = %d\n", id.infog[0]);
        fflush(stdout);
        printf("Error Return in Test application, id.infog[1] = %d\n", id.infog[1]);
        fflush(stdout);
        printf("id.infog[2] = %d\n", id.infog[2]);
        fflush(stdout);
        return 1;
    }
#ifdef VERBOSE_OUTPUT
    printf("End Mumps Termination\n");
    fflush(stdout);
#endif
    free(irn);
    free(jcn);
    free(aa);

    double numerator = 0.0;
    for (int i = 1; i < nrows; i++)
    {
        numerator += pow((rhs[i] - 1.0), 2);
    }
    numerator = sqrt(numerator);
    double denominator = sqrt(static_cast<double>(nrows));
    double relativeError = numerator / denominator;

    ierr = MPI_Finalize();
    free(rhs);

    // ---------------------------------------------
    //   Important statistics
    // ---------------------------------------------
    if (myid == 0)
    {
        int ompNumThrds = omp_get_max_threads();
        double sparsity_percent = 0.0;
        double symbolic_t = 0.0, numeric_t = 0.0, solve_t = 0.0, sns_t = 0.0;
        sparsity_percent = (nrows * nrows) - nnz;
        sparsity_percent = sparsity_percent / (nrows * nrows);
        sparsity_percent = sparsity_percent * 100;
        symbolic_t = std::chrono::duration_cast<ns>(SymbolicFactorizationTime).count() / 1.0e9;
        numeric_t = std::chrono::duration_cast<ns>(NumericFactorizationTime).count() / 1.0e9;
        solve_t = std::chrono::duration_cast<ns>(FBSolveTime).count() / 1.0e9;
        sns_t = std::chrono::duration_cast<ns>(SymbolicFactorizationTime + NumericFactorizationTime + FBSolveTime).count() / 1.0e9;
#ifdef PARAM_LOG
    std::cout.precision(2);
    std::cout.setf(std::ios::fixed);
    std::cout.setf(std::ios::left);

    std::cout << std::setw(12) << "M" 
            << std::setw(12) << "N" 
            << std::setw(12) << "nnz"
	        << std::setw(12) << "mpi_ranks" 
            << std::setw(12) << "sparsity_%" 
            << std::setw(16) << "symbolic_time" 
            << std::setw(16) << "numeric_time" 
            << std::setw(16) << "solve_time" 
            << std::setw(16) << "sns_time" 
            << std::setw(12) << "relativeError" 
            << std::endl;

    std::cout << std::setw(12) << nrows 
            << std::setw(12) << ncols 
            << std::setw(12) << nnz
	        << std::setw(12) << comm_size 
            << std::setw(12) << sparsity_percent 
            << std::setw(16) << std::scientific << symbolic_t
	        << std::setw(16) << std::scientific << numeric_t
	        << std::setw(16) << std::scientific << solve_t 
            << std::setw(16) << std::scientific << sns_t 
            << std::setw(12) << std::fixed << relativeError << std::endl;          
#else
        //input, mpiProcs, ompThrds, symmetry, nrows, nnz, sparsity_%, symbolic_t, numeric_t, solve_t, sns_t, relError
        printf("%s, %d, %d, %d, %d, %d, %5.2f, %5.2f, %5.2f, %5.2f, %5.2f, %5.2f\n", matrix_name.c_str(), comm_size, ompNumThrds, id.sym, nrows, nnz, sparsity_percent,
            symbolic_t, numeric_t, solve_t, sns_t, relativeError);
#endif
    }


    return 0;
}
