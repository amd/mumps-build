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

option(MUMPS_BUILD_TESTING "Build tests" ${MUMPS_IS_TOP_LEVEL})
option(MUMPS_BUILD_SAMPLES "Build Examples" ${MUMPS_IS_TOP_LEVEL})

option(find_static "Find static libraries for Lapack and Scalapack (default shared then static search)")

if(MUMPS_UPSTREAM_VERSION VERSION_GREATER_EQUAL 5.2)
  option(gemmt "GEMMT is recommended in User Manual if available" ON)
endif()

option(MUMPS_parallel "parallel (use MPI)" ON)

option(intsize64 "use 64-bit integers in C and Fortran" ON)

option(scalapack "Use ScalaPACK to speed up the solution of linear systems" ON)
if(MUMPS_UPSTREAM_VERSION VERSION_LESS 5.7 AND NOT scalapack)
  message(FATAL_ERROR "MUMPS version < 5.7 requires scalapack=on")
endif()

option(scotch "use Scotch orderings" OFF)

option(parmetis "use parallel METIS ordering" OFF)
option(metis "use sequential METIS ordering" ON)
if(parmetis AND NOT MUMPS_parallel)
  message(FATAL_ERROR "parmetis requires MUMPS_parallel=on")
endif()

option(openmp "use OpenMP" ON)

option(matlab "Matlab interface" OFF)
if(matlab AND MUMPS_parallel)
  message(FATAL_ERROR "Matlab requires -DMUMPS_parallel=off")
endif()

option(find "find [SCA]LAPACK" on)

option(CMAKE_BUILD_TYPE "Build configuration" Release)
option(BUILD_SHARED_LIBS "Build shared libraries" OFF)

include(CheckPIESupported)
check_pie_supported()
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(BUILD_SINGLE "Build single precision float32 real" OFF)
option(BUILD_DOUBLE "Build double precision float64 real" ON)
option(BUILD_COMPLEX "Build single precision complex" OFF)
option(BUILD_COMPLEX16 "Build double precision complex" OFF)

# --- other options

set_property(DIRECTORY PROPERTY EP_UPDATE_DISCONNECTED true)

set(FETCHCONTENT_UPDATES_DISCONNECTED true)

# this is for convenience of those needing scalapaack, lapack built
if(MUMPS_IS_TOP_LEVEL AND CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set_property(CACHE CMAKE_INSTALL_PREFIX PROPERTY VALUE "${PROJECT_BINARY_DIR}/local")
endif()
