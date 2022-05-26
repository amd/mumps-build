# MIT License
#  
# Copyright (c) <2021> Advanced Micro Devices, Inc. All rights reserved
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

cmake_minimum_required(VERSION 3.19...3.23)

get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT is_multi_config AND NOT (CMAKE_BUILD_TYPE OR DEFINED ENV{CMAKE_BUILD_TYPE}))
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Release default")
endif()

file(READ ${CMAKE_CURRENT_LIST_DIR}/codemeta.json _j)
string(JSON PROJECT_VERSION GET ${_j} version)

project(MUMPS
LANGUAGES C CXX Fortran
VERSION ${PROJECT_VERSION}
DESCRIPTION "Sparse direct parallel solver"
HOMEPAGE_URL "http://mumps-solver.org/"
)

include(CTest)

message(STATUS "MUMPS_UPSTREAM_VERSION = ${MUMPS_UPSTREAM_VERSION}")
if(NOT MUMPS_UPSTREAM_VERSION)
  set(MUMPS_UPSTREAM_VERSION 5.5.0)
endif()

if(MSVC AND BUILD_SHARED_LIBS)
  message(WARNING "MUMPS: Windows Intel/IntelLLVM compilers with **shared** libraries is not supported and will probably fail.
  Recommend using static libraries, which does work:
  cmake -DBUILD_SHARED_LIBS=off")
endif()

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS true)

# --- user options
include(cmake/options.cmake)
include(cmake/compilers.cmake)

# --- download MUMPS source
include(cmake/mumps_src.cmake)

# --- dependencies
find_package(Threads)

include(cmake/Modules/FindLAPACK.cmake)

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
  include(cmake/Modules/FindSCALAPACK.cmake)

  set(NUMERIC_LIBS SCALAPACK::SCALAPACK MPI::MPI_Fortran MPI::MPI_C)
  if(openmp)
    find_package(OpenMP COMPONENTS C Fortran REQUIRED)
  endif()
else(parallel)
  configure_file(libseq/CMakeLists.txt ${mumps_SOURCE_DIR}/libseq/ COPYONLY)
  add_subdirectory(${mumps_SOURCE_DIR}/libseq ${mumps_BINARY_DIR}/libseq)
  set(NUMERIC_LIBS mpiseq)
endif(parallel)
list(APPEND NUMERIC_LIBS LAPACK::LAPACK ${CMAKE_THREAD_LIBS_INIT})

# --- ordering libs

set(ORDERING_LIBS)
set(ORDERING_FLAGS -Dpord)
if(scotch)
  include(cmake/Modules/FindMETIS.cmake)
  list(APPEND ORDERING_FLAGS -Dmetis)
  list(APPEND ORDERING_LIBS METIS::METIS)
endif()
list(APPEND ORDERING_LIBS pord)

message(STATUS "ORDERING_FLAGS = ${ORDERING_FLAGS}")
message(STATUS "ORDERING_LIBS = ${ORDERING_LIBS}")
message(STATUS "End of Linking Ordering Lib(PORD)")

# --- MUMPS build
message(STATUS "mumps_SOURCE_DIR = ${mumps_SOURCE_DIR}")

configure_file(PORD/lib/CMakeLists.txt ${mumps_SOURCE_DIR}/PORD/lib/ COPYONLY)
add_subdirectory(${mumps_SOURCE_DIR}/PORD/lib ${mumps_BINARY_DIR}/PORD/lib)

configure_file(src/CMakeLists.txt ${mumps_SOURCE_DIR}/src/ COPYONLY)
add_subdirectory(${mumps_SOURCE_DIR}/src ${mumps_BINARY_DIR}/src)

if(BUILD_TESTING)
  add_subdirectory(tests)
endif()

# --- feature summary

include(cmake/summary.cmake)

include(cmake/install.cmake)
