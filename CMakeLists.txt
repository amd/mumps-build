# MIT License
#  
# Copyright (c) 2021-2024 Advanced Micro Devices, Inc. All rights reserved
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

cmake_minimum_required(VERSION 3.19...3.27)

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
VERSION 5.6.2.2
DESCRIPTION "Sparse direct parallel solver"
HOMEPAGE_URL "http://mumps-solver.org/"
)

enable_testing()
if(DEFINED BUILD_TESTING)
  set(${PROJECT_NAME}_BUILD_TESTING ${BUILD_TESTING})
else()
  set(${PROJECT_NAME}_BUILD_TESTING true)
endif()

if(NOT MUMPS_UPSTREAM_VERSION)
  set(MUMPS_UPSTREAM_VERSION 5.6.2)
endif()

if(MSVC AND BUILD_SHARED_LIBS)
  message(WARNING "MUMPS: Windows Intel/IntelLLVM compilers with **shared** libraries is not supported and will probably fail.
  Recommend using static libraries, which does work:
  cmake -DBUILD_SHARED_LIBS=off")
endif()

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS true)

# --- user options
include(options.cmake)
include(cmake/compilers.cmake)

# --- download MUMPS source
include(cmake/mumps_src.cmake)

message(STATUS "${PROJECT_NAME} ${PROJECT_VERSION} upstream ${MUMPS_UPSTREAM_VERSION} install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "CMake ${CMAKE_VERSION}  Toolchain ${CMAKE_TOOLCHAIN_FILE}")

# --- dependencies
find_package(Threads)

# --- setup AOCL_ROOT(if defined)
if(DEFINED ENV{AOCL_ROOT})
  set(AOCL_ROOT $ENV{AOCL_ROOT})
endif()
# --- define AOCL ILP Directory
if(intsize64)
  set(ILP_DIR "ILP64")
else(intsize64)
  set(ILP_DIR "LP64")
endif(intsize64)

# --- BLAS AND LAPACK Dependencies
include(cmake/FindLAPACK.cmake)     
if(intsize64)
   add_definitions("-DInt=__int64" "-Dintsize64" "-DUInt=unsigned __int64" "-i8")
   find_library(IMPI_LIB_ILP64
     NAMES libmpi_ilp64
     HINTS ${USER_PROVIDED_IMPILIB_ILP64_PATH})
else(intsize64)
   add_definitions("-DUInt=unsigned int")
   unset(IMPI_LIB_ILP64)
ENDIF(intsize64)

# -- Scalapack / MPI

if(parallel)
  find_package(MPI COMPONENTS C Fortran REQUIRED)
  include(cmake/FindSCALAPACK.cmake)
  set(NUMERIC_LIBS ${SCALAPACK_LIBRARIES} ${LAPACK_LIBRARIES})

  if(find_static AND NOT WIN32 AND
    MKL IN_LIST LAPACK_VENDOR AND
    CMAKE_VERSION VERSION_GREATER_EQUAL 3.24
    )
    set(NUMERIC_LIBS $<LINK_GROUP:RESCAN,${NUMERIC_LIBS}>)
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

# --- ordering libs

set(ORDERING_LIBS)
set(ORDERING_DEFS pord)

if(scotch)
  find_package(Scotch COMPONENTS ESMUMPS REQUIRED)
  list(APPEND ORDERING_DEFS scotch)
  list(APPEND ORDERING_LIBS Scotch::Scotch)
endif()

if(parmetis)
  find_package(METIS REQUIRED COMPONENTS parallel)
  list(APPEND ORDERING_DEFS parmetis metis)
  list(APPEND ORDERING_LIBS METIS::METIS)
elseif(metis)
  include(cmake/FindMETIS.cmake)
  list(APPEND ORDERING_DEFS metis)
  list(APPEND ORDERING_LIBS METIS::METIS)  
endif()

list(APPEND ORDERING_LIBS pord)

message(STATUS "MUMPS ORDERING_DEFS: ${ORDERING_DEFS}")
message(STATUS "MUMPS ORDERING_LIBS: ${ORDERING_LIBS}")

# --- MUMPS build

# --- mpiseq (No MPI)
if(NOT parallel)
  include(cmake/libseq.cmake)
  set(NUMERIC_LIBS mpiseq LAPACK::LAPACK)
endif()

list(APPEND NUMERIC_LIBS ${CMAKE_THREAD_LIBS_INIT})

# --- PORD (always used)
include(cmake/pord.cmake)

# --- MUMPS itself
include(cmake/mumps.cmake)

if(matlab OR octave)
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
