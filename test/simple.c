/*
    MIT License

    Copyright (c) 2021-2022 Advanced Micro Devices, Inc. All rights reserved

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

/* Example program using the C interface to the
 * double real arithmetic version of MUMPS, dmumps_c.
 * We solve the system A x = RHS with
 *   A = diag(1 2) and RHS = [1 4]^T
 * Solution is [1 2]^T */
#include <stdio.h>
#include <string.h>

#include "mpi.h"
#include "dmumps_c.h"

#define INIT_ERROR_CHECK
#define ANALYSE_ERROR_CHECK
#define FACT_ERROR_CHECK
#define SOLUTION_ERROR_CHECK
#define JOB_INIT -1
#define JOB_END -2
#define USE_COMM_WORLD -987654


int main(int argc, char ** argv)
{
  DMUMPS_STRUC_C id;
  MUMPS_INT n = 2;
  MUMPS_INT8 nnz = 2;
  MUMPS_INT irn[] = {1,2};
  MUMPS_INT jcn[] = {1,2};
  double a[2];
  double rhs[2];

/* When compiling with -DINTSIZE64, MUMPS_INT is 64-bit but MPI
   ilp64 versions may still require standard int for C interface. */
/* MUMPS_INT myid, ierr; */
  int myid, ierr;
  int error = 0;

  ierr = MPI_Init(&argc, &argv);
  if (ierr != 0) {
     fprintf(stderr, "failed to init MPI");
     return 1;
  }
  ierr = MPI_Comm_rank(MPI_COMM_WORLD, &myid);
  MPI_Comm_size(MPI_COMM_WORLD, &p);     /* get number of processes */
  /* Define A and rhs */
  rhs[0]=1.0;rhs[1]=4.0;
  a[0]=1.0;a[1]=2.0;

  MPI_Errhandler_set(MPI_COMM_WORLD, MPI_ERRORS_RETURN); /* return info about
    errors */
  printf("No of Processes = %d, My Rank = %d\n", p, myid);
  
  /* Initialize a MUMPS instance. Use MPI_COMM_WORLD */
  id.comm_fortran=USE_COMM_WORLD;
  id.par=1; id.sym=0;
  id.job=JOB_INIT;
  printf("Start Mumps Init\n");
  fflush(stdout);  
  dmumps_c(&id);
#ifdef INIT_ERROR_CHECK
  if (id.infog[0] < 0)
  {
      printf("[PROC %d] Error Return in Test application, id.infog[0] = %d\n", myid, id.infog[0]);
      fflush(stdout);
      printf("[PROC %d] Error Return in Test application, id.infog[1] = %d\n", myid, id.infog[1]);
      fflush(stdout);
      printf("[PROC %d] id.infog[2] = %d\n", myid, id.infog[2]);
      fflush(stdout);
      return 1;
  }
#endif
  printf("Done Mumps Init, infog[0] = %d\n", id.infog[0]);
  fflush(stdout);

  /* Define the problem on the host */
  if (myid == 0) {
    id.n = n; id.nnz =nnz; id.irn=irn; id.jcn=jcn;
    id.a = a; id.rhs = rhs;
  }
#define ICNTL(I) icntl[(I)-1] /* macro s.t. indices match documentation */
  /* No outputs */
  id.ICNTL(1)=-1; id.ICNTL(2)=-1; id.ICNTL(3)=-1; id.ICNTL(4)=0;

  /* Call the MUMPS package (analyse, factorization and solve). */
  id.job=1;
  id.job=1;
  printf("Start Mumps Analyse\n");
  fflush(stdout);  
  dmumps_c(&id);
#ifdef ANALYSE_ERROR_CHECK
  if (id.infog[0] < 0)
  {
      printf("[PROC %d] [Analyse] Error Return in Test application, id.infog[0] = %d\n", myid, id.infog[0]);
      fflush(stdout);
      printf("[PROC %d] [Analyse] Error Return in Test application, id.infog[1] = %d\n", myid, id.infog[1]);
      fflush(stdout);
      printf("[PROC %d] [Analyse] id.infog[2] = %d\n", myid, id.infog[2]);
      fflush(stdout);
      return 1;
  }
#endif
  printf("Done Mumps Analyse, infog[0] = %d\n", id.infog[0]);
  fflush(stdout);

  id.job = 2;
  printf("Start Mumps Fact\n");
  fflush(stdout);
  dmumps_c(&id);
#ifdef FACT_ERROR_CHECK
  if (id.infog[0] < 0)
  {
      printf("[PROC %d] [Factorize] Error Return in Test application, id.infog[0] = %d\n", myid, id.infog[0]);
      fflush(stdout);
      printf("[PROC %d] [Factorize] Error Return in Test application, id.infog[1] = %d\n", myid, id.infog[1]);
      fflush(stdout);
      printf("[PROC %d] [Factorize] id.infog[2] = %d\n", myid, id.infog[2]);
      fflush(stdout);
      return 1;
  }
#endif
  printf("Done Mumps Fact, infog[0] = %d\n", id.infog[0]);
  fflush(stdout);

  id.job = 3;
  printf("Start Mumps Solve\n");
  fflush(stdout);
  dmumps_c(&id);
#ifdef SOLUTION_ERROR_CHECK
  if (id.infog[0] < 0)
  {
      printf("[PROC %d] [Solution] Error Return in Test application, id.infog[0] = %d\n", myid, id.infog[0]);
      fflush(stdout);
      printf("[PROC %d] [Solution] Error Return in Test application, id.infog[1] = %d\n", myid, id.infog[1]);
      fflush(stdout);
      printf("[PROC %d] [Solution] id.infog[2] = %d\n", myid, id.infog[2]);
      fflush(stdout);
      return 1;
  }
#endif
  printf("Done Mumps Solve, infog[0] = %d\n", id.infog[0]);
  fflush(stdout);  

  /* Terminate instance. */
  id.job=JOB_END;
  printf("Start Mumps Termination\n");
  fflush(stdout);  
  dmumps_c(&id);
#ifdef TERMINATE_ERROR_CHECK
  if (id.infog[0] < 0)
  {
      printf("[PROC %d] Error Return in Test application, id.infog[0] = %d\n", myid, id.infog[0]);
      fflush(stdout);
      printf("[PROC %d] Error Return in Test application, id.infog[1] = %d\n", myid, id.infog[1]);
      fflush(stdout);
      printf("[PROC %d] id.infog[2] = %d\n", myid, id.infog[2]);
      fflush(stdout);
      return 1;
  }
#endif
  printf("Done Mumps Termination, infog[0] = %d\n", id.infog[0]);
  fflush(stdout);
    
  if (myid == 0) printf("Solution is : (%8.2f  %8.2f)\n", rhs[0],rhs[1]);
  ierr = MPI_Finalize();
  return 0;
}
