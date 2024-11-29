# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

# Modifications Copyright (c) 2021-2025 Advanced Micro Devices, Inc. All rights reserved

#[=======================================================================[.rst:

FindLapack
----------

* Michael Hirsch, Ph.D. www.scivision.dev
* David Eklund

Let Michael know if there are more MKL / Lapack / compiler combination you want.
Refer to https://software.intel.com/en-us/articles/intel-mkl-link-line-advisor

Finds LAPACK libraries for C / C++ / Fortran.
Works with Netlib Lapack / LapackE, Atlas and Intel MKL.
Intel MKL relies on having environment variable MKLROOT set, typically by sourcing
mklvars.sh beforehand.

Why not the FindLapack.cmake built into CMake? It has a lot of old code for
infrequently used Lapack libraries and is unreliable for me.

Tested on Linux, MacOS and Windows with:
* GCC / Gfortran
* Clang / Flang
* Intel (icc, ifort)
* Cray


Parameters
^^^^^^^^^^

COMPONENTS default to Netlib LAPACK / LapackE, otherwise:

``MKL``
  Intel MKL -- sequential by default, or add TBB or MPI as well
``MKL64``
  MKL only: 64-bit integers  (default is 32-bit integers)
``TBB``
  Intel MPI + TBB for MKL
``AOCL``
  AMD Optimizing CPU Libraries

``LAPACKE``
  Netlib LapackE for C / C++
``Netlib``
  Netlib Lapack for Fortran
``OpenBLAS``
  OpenBLAS Lapack for Fortran

``LAPACK95``
  get Lapack95 interfaces for MKL or Netlib (must also specify one of MKL, Netlib)

``STATIC``
  Library search default on non-Windows is shared then static. On Windows default search is static only.
  Specifying STATIC component searches for static libraries only.


Result Variables
^^^^^^^^^^^^^^^^

``LAPACK_FOUND``
  Lapack libraries were found
``LAPACK_<component>_FOUND``
  LAPACK <component> specified was found
``LAPACK_LIBRARIES``
  Lapack library files (including BLAS
``LAPACK_INCLUDE_DIRS``
  Lapack include directories (for C/C++)


References
^^^^^^^^^^

* Pkg-Config and MKL:  https://software.intel.com/en-us/articles/intel-math-kernel-library-intel-mkl-and-pkg-config-tool
* MKL for Windows: https://software.intel.com/en-us/mkl-windows-developer-guide-static-libraries-in-the-lib-intel64-win-directory
* MKL Windows directories: https://software.intel.com/en-us/mkl-windows-developer-guide-high-level-directory-structure
* Atlas http://math-atlas.sourceforge.net/errata.html#LINK
* MKL LAPACKE (C, C++): https://software.intel.com/en-us/mkl-linux-developer-guide-calling-lapack-blas-and-cblas-routines-from-c-c-language-environments
#]=======================================================================]

include(CheckFortranSourceCompiles)

# clear to avoid endless appending on subsequent calls
set(LAPACK_LIBRARY)
unset(LAPACK_INCLUDE_DIR)

# ===== functions ==========

function(atlas_libs)

find_library(ATLAS_LIB
NAMES atlas
PATH_SUFFIXES atlas
DOC "ATLAS library"
)

find_library(LAPACK_ATLAS
NAMES ptlapack lapack_atlas lapack
NAMES_PER_DIR
PATH_SUFFIXES atlas
DOC "LAPACK ATLAS library"
)

find_library(BLAS_LIBRARY
NAMES ptf77blas f77blas blas
NAMES_PER_DIR
PATH_SUFFIXES atlas
DOC "BLAS ATLAS library"
)

# === C ===
find_library(BLAS_C_ATLAS
NAMES ptcblas cblas
NAMES_PER_DIR
PATH_SUFFIXES atlas
DOC "BLAS C ATLAS library"
)

find_path(LAPACK_INCLUDE_DIR
NAMES cblas-atlas.h cblas.h clapack.h
DOC "ATLAS headers"
)

#===========
if(LAPACK_ATLAS AND BLAS_C_ATLAS AND BLAS_LIBRARY AND ATLAS_LIB)
  set(LAPACK_Atlas_FOUND true PARENT_SCOPE)
  set(LAPACK_LIBRARY ${LAPACK_ATLAS} ${BLAS_C_ATLAS} ${BLAS_LIBRARY} ${ATLAS_LIB})
  list(APPEND LAPACK_LIBRARY ${CMAKE_THREAD_LIBS_INIT})
endif()

set(LAPACK_LIBRARY ${LAPACK_LIBRARY} PARENT_SCOPE)

endfunction(atlas_libs)

#=======================

function(netlib_libs)

if(LAPACK95 IN_LIST LAPACK_FIND_COMPONENTS)
  find_path(LAPACK95_INCLUDE_DIR
  NAMES f95_lapack.mod
  HINTS ${LAPACK95_ROOT} ENV LAPACK95_ROOT
  PATH_SUFFIXES include
  DOC "LAPACK95 Fortran module"
  )

  find_library(LAPACK95_LIBRARY
  NAMES lapack95
  HINTS ${LAPACK95_ROOT} ENV LAPACK95_ROOT
  DOC "LAPACK95 library"
  )

  if(NOT (LAPACK95_LIBRARY AND LAPACK95_INCLUDE_DIR))
    return()
  endif()

  set(LAPACK95_LIBRARY ${LAPACK95_LIBRARY} PARENT_SCOPE)
  set(LAPACK_LAPACK95_FOUND true PARENT_SCOPE)
endif(LAPACK95 IN_LIST LAPACK_FIND_COMPONENTS)

find_library(LAPACK_LIBRARY
NAMES lapack
PATH_SUFFIXES lapack lapack/lib
DOC "LAPACK library"
)
if(NOT LAPACK_LIBRARY)
  return()
endif()

if(LAPACKE IN_LIST LAPACK_FIND_COMPONENTS)

  find_library(LAPACKE_LIBRARY
  NAMES lapacke
  PATH_SUFFIXES lapack lapack/lib
  DOC "LAPACKE library"
  )

  # lapack/include for Homebrew
  find_path(LAPACKE_INCLUDE_DIR
  NAMES lapacke.h
  PATH_SUFFIXES lapack lapack/include
  DOC "LAPACKE include directory"
  )
  if(NOT (LAPACKE_LIBRARY AND LAPACKE_INCLUDE_DIR))
    return()
  endif()

  set(LAPACK_LAPACKE_FOUND true PARENT_SCOPE)
  list(APPEND LAPACK_INCLUDE_DIR ${LAPACKE_INCLUDE_DIR})
  list(APPEND LAPACK_LIBRARY ${LAPACKE_LIBRARY})
  mark_as_advanced(LAPACKE_LIBRARY LAPACKE_INCLUDE_DIR)
endif(LAPACKE IN_LIST LAPACK_FIND_COMPONENTS)

# Netlib on Cygwin and others

find_library(BLAS_LIBRARY
NAMES refblas blas
NAMES_PER_DIR
PATH_SUFFIXES lapack lapack/lib blas
DOC "BLAS library"
)

if(NOT BLAS_LIBRARY)
  return()
endif()

list(APPEND LAPACK_LIBRARY ${BLAS_LIBRARY})
set(LAPACK_Netlib_FOUND true PARENT_SCOPE)

list(APPEND LAPACK_LIBRARY ${CMAKE_THREAD_LIBS_INIT})

set(LAPACK_LIBRARY ${LAPACK_LIBRARY} PARENT_SCOPE)

endfunction(netlib_libs)

#===============================
function(openblas_libs)

find_library(LAPACK_LIBRARY
NAMES openblas
PATH_SUFFIXES openblas
DOC "OpenBLAS library"
)

find_path(LAPACK_INCLUDE_DIR
NAMES openblas_config.h cblas-openblas.h
DOC "OpenBLAS include directory"
)

if(NOT LAPACK_LIBRARY)
  return()
endif()

set(BLAS_LIBRARY ${LAPACK_LIBRARY} CACHE FILEPATH "OpenBLAS library")

set(LAPACK_OpenBLAS_FOUND true PARENT_SCOPE)

list(APPEND LAPACK_LIBRARY ${CMAKE_THREAD_LIBS_INIT})

set(LAPACK_LIBRARY ${LAPACK_LIBRARY} PARENT_SCOPE)

endfunction(openblas_libs)


#===============================

function(aocl_libs)
  if(WIN32)
      set(CMAKE_FIND_LIBRARY_PREFIXES "")
      set(CMAKE_FIND_LIBRARY_SUFFIXES ".lib")
      set(_blas_library "AOCL-LibBlis-Win")
      set(_flame_library "AOCL-LibFlame-Win")
      set(_utils_library "libaoclutils")
      set(_static_tag "static")
      set(_mt_tag "MT")

      # Always use Multi Threaded
      set(_blas_static_library "${_blas_library}-${_mt_tag}")
      set(_blas_dyn_library "${_blas_static_library}-dll")
      set(_flame_static_library "${_flame_library}-${_mt_tag}")
      set(_flame_dyn_library "${_flame_static_library}-dll")

      set(_utils_static_library "${_utils_library}_${_static_tag}")
      set(_utils_dyn_library "${_utils_library}")
    else(WIN32)
      set(CMAKE_FIND_LIBRARY_PREFIXES "lib")
      # No strict static-to-static and shared-to-shared library linking enforced for dependent libraries
      # CMAKE_FIND_LIBRARY_SUFFIXES which decides the library suffix(.so or .a) is not set based on BUILD_SHARED_LIBS
      set(_blas_library "blis")
      set(_flame_library "flame")
      set(_mt_tag "mt")
      set(_utils_static_library "aoclutils")
      set(_utils_dyn_library "aoclutils")

      # Always use Multi Threaded
      set(_blas_static_library "${_blas_library}-${_mt_tag}")
      set(_blas_dyn_library "${_blas_library}-${_mt_tag}")
      set(_flame_static_library "${_flame_library}")
      set(_flame_dyn_library "${_flame_library}")
    endif(WIN32)

    # Link against dynamic library by default
    find_library(
      AOCL_UTILS_LIB
      NAMES ${_utils_dyn_library} ${_utils_static_library} NAMES_PER_DIR
      HINTS ${USER_PROVIDED_UTILS_LIBRARY_PATH} ${CMAKE_AOCL_ROOT}/utils ${CMAKE_AOCL_ROOT}/amd-utils ${CMAKE_AOCL_ROOT}
      PATH_SUFFIXES "lib/${ILP_DIR}" "lib_${ILP_DIR}" "lib"
      DOC "AOCL Utils library")

    find_library(
      AOCL_BLIS_LIB
      NAMES ${_blas_dyn_library} ${_blas_static_library}
      HINTS ${USER_PROVIDED_BLIS_LIBRARY_PATH} ${CMAKE_AOCL_ROOT}/blis ${CMAKE_AOCL_ROOT}/amd-blis ${CMAKE_AOCL_ROOT} 
      PATH_SUFFIXES "lib/${ILP_DIR}" "lib_${ILP_DIR}" "lib"
      DOC "AOCL Blis library")
    
    find_library(
      AOCL_LIBFLAME
      NAMES ${_flame_dyn_library} ${_flame_static_library} NAMES_PER_DIR
      HINTS ${USER_PROVIDED_LAPACK_LIBRARY_PATH} ${CMAKE_AOCL_ROOT}/libflame ${CMAKE_AOCL_ROOT}/amd-libflame ${CMAKE_AOCL_ROOT}
      PATH_SUFFIXES "lib/${ILP_DIR}" "lib_${ILP_DIR}" "lib"
      DOC "AOCL LIBFLAME library")    
    # ====Headers
    find_path(
      AOCL_UTILS_INCLUDE_DIR
      NAMES alci_c.h alci.h arch.h cache.h enum.h macros.h
      HINTS ${USER_PROVIDED_UTILS_INCLUDE_PATH} ${CMAKE_AOCL_ROOT}/amd-utils ${CMAKE_AOCL_ROOT}/utils ${CMAKE_AOCL_ROOT}
      PATH_SUFFIXES "include/${ILP_DIR}/alci" "include_${ILP_DIR}/alci"
                    "include/alci"
      DOC "AOCL Utils headers")

    find_path(
      AOCL_BLIS_INCLUDE_DIR
      NAMES blis.h cblas.h blis.hh cblas.hh
      HINTS ${USER_PROVIDED_BLIS_INCLUDE_PATH} ${CMAKE_AOCL_ROOT}/amd-blis ${CMAKE_AOCL_ROOT}/blis ${CMAKE_AOCL_ROOT}
      PATH_SUFFIXES "include/${ILP_DIR}" "include_${ILP_DIR}" "include"
                    "include/blis"
      DOC "AOCL Blis headers")
    find_path(
      AOCL_LIBFLAME_INCLUDE_DIR
      NAMES FLAME.h lapacke.h lapacke_mangling.h lapack.h libflame.hh
            libflame_interface.hh
      HINTS ${USER_PROVIDED_LAPACK_INCLUDE_PATH} ${CMAKE_AOCL_ROOT}/libflame ${CMAKE_AOCL_ROOT}/amd-libflame ${CMAKE_AOCL_ROOT}
      PATH_SUFFIXES "include/${ILP_DIR}" "include_${ILP_DIR}" "include"
      DOC "AOCL Libflame headers")      
    # ===========
    if(AOCL_BLIS_LIB
      AND AOCL_LIBFLAME
      AND AOCL_BLIS_INCLUDE_DIR
      AND AOCL_LIBFLAME_INCLUDE_DIR
      AND AOCL_UTILS_LIB
      AND AOCL_UTILS_INCLUDE_DIR)      
      set(LAPACK_LIBRARY ${AOCL_LIBFLAME} ${AOCL_BLIS_LIB} ${AOCL_UTILS_LIB})
      list(APPEND LAPACK_LIBRARY ${CMAKE_THREAD_LIBS_INIT})
      set(LAPACK_INCLUDE_DIR ${AOCL_LIBFLAME_INCLUDE_DIR} ${AOCL_BLIS_INCLUDE_DIR} ${AOCL_UTILS_INCLUDE_DIR})
    else()
      if(NOT AOCL_LIBFLAME)
        message(STATUS "Info: could not find a suitable installation of Blas Library in \$USER_PROVIDED_LAPACK_LIBRARY_PATH=${USER_PROVIDED_LAPACK_LIBRARY_PATH}")
      endif()
      if(NOT AOCL_BLIS_LIB)
        message(STATUS "Info: could not find a suitable installation of Blas Library in \$USER_PROVIDED_BLIS_LIBRARY_PATH=${USER_PROVIDED_BLIS_LIBRARY_PATH}")
      endif()
      if(NOT AOCL_UTILS_LIB)
        message(STATUS "Info: could not find a suitable installation of Blas Library in \$USER_PROVIDED_UTILS_LIBRARY_PATH=${USER_PROVIDED_UTILS_LIBRARY_PATH}")
      endif()

      if(NOT AOCL_LIBFLAME_INCLUDE_DIR)
        message(STATUS "Info: could not find a suitable installation of Blas Library in \$USER_PROVIDED_LAPACK_INCLUDE_PATH=${USER_PROVIDED_LAPACK_INCLUDE_PATH}")
      endif()
      if(NOT AOCL_BLIS_INCLUDE_DIR)
        message(STATUS "Info: could not find a suitable installation of Blas Library in \$USER_PROVIDED_BLIS_INCLUDE_PATH=${USER_PROVIDED_BLIS_INCLUDE_PATH}")
      endif()
      if(NOT AOCL_UTILS_INCLUDE_DIR)
        message(STATUS "Info: could not find a suitable installation of Blas Library in \$USER_PROVIDED_UTILS_INCLUDE_PATH=${USER_PROVIDED_UTILS_INCLUDE_PATH}")
      endif()
      message(
        FATAL_ERROR
          "Error: could not find a suitable installation of Blas/Lapack/Utils Libraries"
      )
    endif()
    set(LAPACK_AOCL_FOUND true PARENT_SCOPE)
    set(LAPACK_LIBRARY ${LAPACK_LIBRARY} PARENT_SCOPE)
    set(LAPACK_INCLUDE_DIR ${LAPACK_INCLUDE_DIR} PARENT_SCOPE)         

    message(STATUS "Dependencies (libraries and includes)")
    message(STATUS "  \$AOCL LAPACK LIBRARY......${AOCL_LIBFLAME}")
    message(STATUS "  \$AOCL BLAS LIBRARY......${AOCL_BLIS_LIB}")
    message(STATUS "  \$AOCL Utils LIBRARY......${AOCL_UTILS_LIB}")
    message(STATUS "  \$LAPACK Headers...${AOCL_LIBFLAME_INCLUDE_DIR}")
    message(STATUS "  \$BLAS Headers.....${AOCL_BLIS_INCLUDE_DIR}")
    message(STATUS "  \$Utils Headers....${AOCL_UTILS_INCLUDE_DIR}")      
endfunction(aocl_libs)

#===============================

macro(find_mkl_libs)
# https://www.intel.com/content/www/us/en/docs/onemkl/developer-guide-linux/2023-2/cmake-config-for-onemkl.html

set(MKL_INTERFACE "lp64")
if(MKL64 IN_LIST LAPACK_FIND_COMPONENTS)
  string(PREPEND MKL_INTERFACE "i")
endif()

if(LAPACK95 IN_LIST LAPACK_FIND_COMPONENTS)
  set(ENABLE_BLAS95 true)
  set(ENABLE_LAPACK95 true)
endif()

# MKL_THREADING default: "intel_thread" which is Intel OpenMP
if(TBB IN_LIST LAPACK_FIND_COMPONENTS)
  set(MKL_THREADING "tbb_thread")
endif()

# default: dynamic
if(STATIC IN_LIST LAPACK_FIND_COMPONENTS)
  set(MKL_LINK "static")
endif()

find_package(MKL CONFIG HINTS $ENV{MKLROOT})

if(NOT MKL_FOUND)
  return()
endif()

# get_property(LAPACK_COMPILE_OPTIONS TARGET MKL::MKL PROPERTY INTERFACE_COMPILE_OPTIONS)
# flags are empty generator expressions that trip up check_source_compiles

get_property(LAPACK_INCLUDE_DIR TARGET MKL::MKL PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
get_property(LAPACK_LIBRARY TARGET MKL::MKL PROPERTY INTERFACE_LINK_LIBRARIES)


set(LAPACK_MKL_FOUND true)

foreach(c IN ITEMS TBB LAPACK95 MKL64)
  if(${c} IN_LIST LAPACK_FIND_COMPONENTS)
    set(LAPACK_${c}_FOUND true)
  endif()
endforeach()

endmacro(find_mkl_libs)

# ========== main program
if(NOT DEFINED LAPACK_CRAY AND DEFINED ENV{CRAYPE_VERSION})
  set(LAPACK_CRAY true)
endif()

if(NOT (LAPACK_CRAY
  OR OpenBLAS IN_LIST LAPACK_FIND_COMPONENTS
  OR Netlib IN_LIST LAPACK_FIND_COMPONENTS
  OR Atlas IN_LIST LAPACK_FIND_COMPONENTS
  OR MKL IN_LIST LAPACK_FIND_COMPONENTS
  OR MKL64 IN_LIST LAPACK_FIND_COMPONENTS
  OR AOCL IN_LIST LAPACK_FIND_COMPONENTS))
  if(DEFINED ENV{MKLROOT} AND IS_DIRECTORY "$ENV{MKLROOT}")
    list(APPEND LAPACK_FIND_COMPONENTS MKL)
  else()
    list(APPEND LAPACK_FIND_COMPONENTS Netlib)
  endif()
endif()

find_package(Threads)

if(STATIC IN_LIST LAPACK_FIND_COMPONENTS)
  set(_orig_suff ${CMAKE_FIND_LIBRARY_SUFFIXES})
  set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_STATIC_LIBRARY_SUFFIX})
endif()

if(AOCL IN_LIST LAPACK_FIND_COMPONENTS)
  aocl_libs()
elseif(MKL IN_LIST LAPACK_FIND_COMPONENTS OR MKL64 IN_LIST LAPACK_FIND_COMPONENTS)
  find_mkl_libs()
elseif(Atlas IN_LIST LAPACK_FIND_COMPONENTS)
  atlas_libs()
elseif(Netlib IN_LIST LAPACK_FIND_COMPONENTS)
  netlib_libs()
elseif(OpenBLAS IN_LIST LAPACK_FIND_COMPONENTS)
  openblas_libs()
elseif(LAPACK_CRAY)
  # LAPACK is implicitly part of Cray PE LibSci, use Cray compiler wrapper.
endif()

if(STATIC IN_LIST LAPACK_FIND_COMPONENTS)
  if(LAPACK_LIBRARY)
    set(LAPACK_STATIC_FOUND true)
  endif()
  set(CMAKE_FIND_LIBRARY_SUFFIXES ${_orig_suff})
endif()

# -- verify library works

function(lapack_check)

get_property(enabled_langs GLOBAL PROPERTY ENABLED_LANGUAGES)
if(NOT Fortran IN_LIST enabled_langs)
  set(LAPACK_links true PARENT_SCOPE)
  return()
endif()

set(CMAKE_REQUIRED_FLAGS)
set(CMAKE_REQUIRED_LINK_OPTIONS)
set(CMAKE_REQUIRED_INCLUDES ${LAPACK_INCLUDE_DIR})
set(CMAKE_REQUIRED_LIBRARIES ${LAPACK_LIBRARY})

check_fortran_source_compiles(
"program check_lapack
use, intrinsic :: iso_fortran_env, only : real32
implicit none
real(real32), external :: snrm2
print *, snrm2(1, [0._real32], 1)
end program"
LAPACK_s_FOUND
SRC_EXT f90
)

check_fortran_source_compiles(
"program check_lapack
use, intrinsic :: iso_fortran_env, only : real64
implicit none
real(real64), external :: dnrm2
print *, dnrm2(1, [0._real64], 1)
end program"
LAPACK_d_FOUND
SRC_EXT f90
)

if(LAPACK_s_FOUND OR LAPACK_d_FOUND)
  set(LAPACK_links true PARENT_SCOPE)
endif()

endfunction(lapack_check)

# --- Check library links
if(LAPACK_CRAY OR LAPACK_LIBRARY)
  lapack_check()
endif()


include(FindPackageHandleStandardArgs)

if(LAPACK_CRAY)
  find_package_handle_standard_args(LAPACK HANDLE_COMPONENTS
  REQUIRED_VARS LAPACK_links
  )
else()
  find_package_handle_standard_args(LAPACK HANDLE_COMPONENTS
  REQUIRED_VARS LAPACK_LIBRARY LAPACK_links
  )
endif()

set(BLAS_LIBRARIES ${BLAS_LIBRARY})
set(LAPACK_LIBRARIES ${LAPACK_LIBRARY})
set(LAPACK_INCLUDE_DIRS ${LAPACK_INCLUDE_DIR})
if(LAPACK_FOUND)
# need if _FOUND guard as can't overwrite imported target even if bad
if(NOT TARGET BLAS::BLAS)
  add_library(BLAS::BLAS INTERFACE IMPORTED)
  set_property(TARGET BLAS::BLAS PROPERTY INTERFACE_LINK_LIBRARIES "${BLAS_LIBRARY}")
endif()

if(NOT TARGET LAPACK::LAPACK)
  add_library(LAPACK::LAPACK INTERFACE IMPORTED)
  set_property(TARGET LAPACK::LAPACK PROPERTY INTERFACE_COMPILE_OPTIONS "${LAPACK_COMPILE_OPTIONS}")
  set_property(TARGET LAPACK::LAPACK PROPERTY INTERFACE_LINK_LIBRARIES "${LAPACK_LIBRARY}")
  set_property(TARGET LAPACK::LAPACK PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${LAPACK_INCLUDE_DIR}")
endif()

if(LAPACK_LAPACK95_FOUND)
  set(LAPACK95_LIBRARIES ${LAPACK95_LIBRARY})
  set(LAPACK95_INCLUDE_DIRS ${LAPACK95_INCLUDE_DIR})

  if(NOT TARGET LAPACK::LAPACK95)
    add_library(LAPACK::LAPACK95 INTERFACE IMPORTED)
    set_property(TARGET LAPACK::LAPACK95 PROPERTY INTERFACE_LINK_LIBRARIES "${LAPACK95_LIBRARY}")
    set_property(TARGET LAPACK::LAPACK95 PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${LAPACK95_INCLUDE_DIR}")
  endif()
endif()

endif(LAPACK_FOUND)

message(STATUS "Dependencies (libraries and includes)")
message(STATUS "  \$LAPACK LIBRARIES......${LAPACK_LIBRARIES}")
message(STATUS "  \$LAPACK_INCLUDE_DIRS...${LAPACK_INCLUDE_DIRS}")

mark_as_advanced(LAPACK_LIBRARY LAPACK_INCLUDE_DIR)
