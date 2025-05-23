# MIT License
#  
# Copyright (c) 2021-2025 Advanced Micro Devices, Inc. All rights reserved
#  
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#  
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#  
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

cmake_minimum_required(VERSION 3.20...3.30)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
  message(FATAL_ERROR "Please use out of source build:
  cmake -B build")
endif()

get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT is_multi_config AND NOT (CMAKE_BUILD_TYPE OR DEFINED ENV{CMAKE_BUILD_TYPE}))
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Release default")
endif()

project(MUMPS
LANGUAGES C CXX Fortran
VERSION 5.7.3.1
DESCRIPTION "Sparse direct parallel solver"
HOMEPAGE_URL "http://mumps-solver.org/"
)

if(CMAKE_VERSION VERSION_GREATER 3.30.0 AND CMAKE_VERSION VERSION_LESS 3.30.4)
cmake_policy(SET CMP0168 OLD)
# workaround to stop repeat FetchContent download on each configure for CMake 3.30.0..3.30.3
endif()

enable_testing()

if(NOT MUMPS_UPSTREAM_VERSION)
  set(MUMPS_UPSTREAM_VERSION 5.7.3)
endif()

if(MSVC AND BUILD_SHARED_LIBS)
  message(WARNING "MUMPS: Windows IntelLLVM compilers with **shared** libraries is not supported and will probably fail.
  Recommend using static libraries, which does work:
  cmake -DBUILD_SHARED_LIBS=off")
endif()

# --- user options
include(options.cmake)
include(cmake/compilers.cmake)

message(STATUS "${PROJECT_NAME} ${PROJECT_VERSION} upstream ${MUMPS_UPSTREAM_VERSION} install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "CMake ${CMAKE_VERSION}  Toolchain ${CMAKE_TOOLCHAIN_FILE}")

# --- dependencies
find_package(Threads)

# Set paths to AOCLUTILS, BLAS and LAPACK installations.
set(CMAKE_AOCL_ROOT
    $ENV{AOCL_ROOT}
    CACHE
    STRING
    "AOCL_ROOT directory to be used to find BLAS/LAPACK/AOCLUTILS libraries")
if(CMAKE_AOCL_ROOT STREQUAL "")
    message(FATAL_ERROR "CMAKE_AOCL_ROOT is empty. Either set environment variable AOCL_ROOT or set -DCMAKE_AOCL_ROOT=<path_to_AOCL_libs>.")
endif()

# Set paths to Re-Ordering Library.
set(CMAKE_METIS_ROOT
    $ENV{METIS_ROOT}
    CACHE
    STRING
    "METIS_ROOT directory to be used to find ordering(Metis) libraries")
if(CMAKE_METIS_ROOT STREQUAL "")
    message(FATAL_ERROR "CMAKE_METIS_ROOT is empty. Either set environment variable METIS_ROOT or set -DCMAKE_METIS_ROOT=<path_to_Metis_ordering_lib>.")
endif()


# define int64 libraries and flags
if(intsize64)
   add_definitions("-DInt=__int64" "-Dintsize64" "-DUInt=unsigned __int64" "-i8")
   find_library(IMPI_LIB_ILP64
     NAMES libmpi_ilp64
     HINTS ${USER_PROVIDED_IMPILIB_ILP64_PATH})
else(intsize64)
   add_definitions("-DUInt=unsigned int")
   unset(IMPI_LIB_ILP64)
ENDIF(intsize64)

# --- define AOCL ILP Directory
if(intsize64)
  set(ILP_DIR "ILP64")
else(intsize64)
  set(ILP_DIR "LP64")
endif(intsize64)
# -- Scalapack / MPI

if(MUMPS_parallel)
  find_package(MPI COMPONENTS C Fortran REQUIRED)
  #if(NOT DEFINED ENV{MKLROOT} AND NOT LAPACK_VENDOR MATCHES "^MKL" OR NOT scalapack)
  if(NOT LAPACK_VENDOR MATCHES "^MKL" OR NOT scalapack)
    # oneMKL MKLConfig.cmake must be invoked only once
    include(cmake/lapack.cmake)
  endif()
  set(NUMERIC_LIBS LAPACK::LAPACK)

  if(scalapack)
    include(cmake/scalapack.cmake) # this will also create the LAPACK::LAPACK target
    list(PREPEND NUMERIC_LIBS SCALAPACK::SCALAPACK)
  endif()

  # avoid MPICH -fallow flag leakage
  set(NUMERIC_INC ${MPI_Fortran_INCLUDE_DIRS})
  list(APPEND NUMERIC_LIBS ${MPI_Fortran_LIBRARIES} MPI::MPI_C)

  if(openmp)
    find_package(OpenMP COMPONENTS C Fortran REQUIRED)
    list(APPEND NUMERIC_LIBS OpenMP::OpenMP_Fortran OpenMP::OpenMP_C)
  endif()
else()
  include(cmake/lapack.cmake)
endif()

# GEMMT is recommeded in MUMPS User Manual if available
if(gemmt)
  include(cmake/gemmt.cmake)
endif()

# --- ordering libs

set(ORDERING_LIBS)
set(ORDERING_DEFS pord)

if(scotch)
  find_package(Scotch COMPONENTS ESMUMPS REQUIRED)
  list(APPEND ORDERING_DEFS scotch)
  list(APPEND ORDERING_LIBS Scotch::Scotch)
endif()

if(parmetis)
  find_package(METIS REQUIRED COMPONENTS ParMETIS)
  list(APPEND ORDERING_DEFS parmetis metis)
  list(APPEND ORDERING_LIBS METIS::METIS)
elseif(metis)
  find_package(METIS REQUIRED)
  list(APPEND ORDERING_DEFS metis)
  list(APPEND ORDERING_LIBS METIS::METIS)
endif()

list(APPEND ORDERING_LIBS pord)

install(FILES
${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindLAPACK.cmake
${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindSCALAPACK.cmake
${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindMETIS.cmake
${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindScotch.cmake
${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindMUMPS.cmake
DESTINATION cmake
)

message(STATUS "MUMPS ORDERING_DEFS: ${ORDERING_DEFS}")
message(STATUS "MUMPS ORDERING_LIBS: ${ORDERING_LIBS}")
message(STATUS "MUMPS LAPACK_VENDOR: ${LAPACK_VENDOR}")
message(STATUS "MUMPS SCALAPACK_VENDOR: ${SCALAPACK_VENDOR}")

# --- download MUMPS source
include(cmake/mumps_src.cmake)
message(VERBOSE "fetched mumps sources ...")

# --- MUMPS build

# --- mpiseq (No MPI)
if(NOT MUMPS_parallel)
  set(NUMERIC_LIBS LAPACK::LAPACK)
  include(cmake/libseq.cmake)
endif()

list(APPEND NUMERIC_LIBS ${CMAKE_THREAD_LIBS_INIT})

# --- PORD (always used)
include(cmake/pord.cmake)

# --- MUMPS itself
include(cmake/mumps.cmake)

if(matlab)
  include(cmake/matlab.cmake)
endif()


if(${PROJECT_NAME}_BUILD_TESTING)
  add_subdirectory(test)
endif()

# --- feature summary

message(STATUS "Configured MUMPS ${MUMPS_UPSTREAM_VERSION} source in ${mumps_SOURCE_DIR}")

include(cmake/summary.cmake)

include(cmake/install.cmake)

file(GENERATE OUTPUT .gitignore CONTENT "*")
