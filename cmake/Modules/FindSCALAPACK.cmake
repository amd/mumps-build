# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

#[=======================================================================[.rst:

FindSCALAPACK
-------------

by Michael Hirsch, Ph.D. www.scivision.dev

Finds SCALAPACK libraries for MKL, OpenMPI and MPICH.
Intel MKL relies on having environment variable MKLROOT set, typically by sourcing
mklvars.sh beforehand.

This module does NOT find LAPACK.

Parameters
^^^^^^^^^^

``MKL``
  Intel MKL for MSVC, oneAPI, GCC.
  Working with IntelMPI (default Window, Linux), MPICH (default Mac) or OpenMPI (Linux only).

``MKL64``
  MKL only: 64-bit integers  (default is 32-bit integers)

Result Variables
^^^^^^^^^^^^^^^^

``SCALAPACK_FOUND``
  SCALapack libraries were found
``SCALAPACK_<component>_FOUND``
  SCALAPACK <component> specified was found
``SCALAPACK_LIBRARIES``
  SCALapack library files
``SCALAPACK_INCLUDE_DIRS``
  SCALapack include directories


References
^^^^^^^^^^

* Pkg-Config and MKL:  https://software.intel.com/en-us/articles/intel-math-kernel-library-intel-mkl-and-pkg-config-tool
* MKL for Windows: https://software.intel.com/en-us/mkl-windows-developer-guide-static-libraries-in-the-lib-intel64-win-directory
* MKL Windows directories: https://software.intel.com/en-us/mkl-windows-developer-guide-high-level-directory-structure
* MKL link-line advisor: https://software.intel.com/en-us/articles/intel-mkl-link-line-advisor
#]=======================================================================]

include(CheckSourceCompiles)

set(SCALAPACK_LIBRARY)  # avoids appending to prior FindScalapack
set(SCALAPACK_INCLUDE_DIR)

#===== functions

function(scalapack_check)

get_property(enabled_langs GLOBAL PROPERTY ENABLED_LANGUAGES)
if(NOT Fortran IN_LIST enabled_langs)
  set(SCALAPACK_links true PARENT_SCOPE)
  return()
endif()

find_package(MPI COMPONENTS C Fortran)
if(NOT LAPACK_FOUND)
  # otherwise can cause 32-bit lapack when 64-bit wanted
  find_package(LAPACK)
endif()
if(NOT (MPI_Fortran_FOUND AND LAPACK_FOUND))
  return()
endif()


set(CMAKE_REQUIRED_FLAGS)
set(CMAKE_REQUIRED_LINK_OPTIONS)
set(CMAKE_REQUIRED_INCLUDES ${SCALAPACK_INCLUDE_DIR} ${LAPACK_INCLUDE_DIRS} ${MPI_Fortran_INCLUDE_DIRS} ${MPI_C_INCLUDE_DIRS})
set(CMAKE_REQUIRED_LIBRARIES ${SCALAPACK_LIBRARY} ${LAPACK_LIBRARIES} ${MPI_Fortran_LIBRARIES} ${MPI_C_LIBRARIES})
# MPI needed for ifort

foreach(i s d)

  check_source_compiles(Fortran
    "program test
    implicit none (type, external)
    external :: p${i}lamch
    external :: blacs_pinfo, blacs_get, blacs_gridinit, blacs_gridexit, blacs_exit
    end program"
    SCALAPACK_${i}_links)

  if(SCALAPACK_${i}_links)
    set(SCALAPACK_${i}_FOUND true PARENT_SCOPE)
    set(SCALAPACK_links true)
  endif()

endforeach()

set(SCALAPACK_links ${SCALAPACK_links} PARENT_SCOPE)

endfunction(scalapack_check)


function(scalapack_mkl)

if(BUILD_SHARED_LIBS)
  set(_mkltype dynamic)
else()
  set(_mkltype static)
endif()

set(_mkl_libs ${ARGV})

foreach(s ${_mkl_libs})
  find_library(SCALAPACK_${s}_LIBRARY
    NAMES ${s}
    HINTS ${MKLROOT}
    PATH_SUFFIXES lib/intel64
    NO_DEFAULT_PATH
  )
  if(NOT SCALAPACK_${s}_LIBRARY)
    return()
  endif()

  list(APPEND SCALAPACK_LIBRARY ${SCALAPACK_${s}_LIBRARY})
endforeach()

find_path(SCALAPACK_INCLUDE_DIR
  NAMES mkl_scalapack.h
  HINTS ${MKLROOT}
  PATH_SUFFIXES include
  NO_DEFAULT_PATH
)

if(NOT SCALAPACK_INCLUDE_DIR)
  return()
endif()

# pc_mkl_INCLUDE_DIRS on Windows injects breaking garbage

set(SCALAPACK_MKL_FOUND true PARENT_SCOPE)
set(SCALAPACK_LIBRARY ${SCALAPACK_LIBRARY} PARENT_SCOPE)
set(SCALAPACK_INCLUDE_DIR ${SCALAPACK_INCLUDE_DIR} PARENT_SCOPE)

endfunction(scalapack_mkl)

#===============================
function(scalapack_aocl)
# AOCL: Include AOCL's Scalapack library

find_library(SCALAPACK_LIBRARY
  NAMES scalapack
  HINTS ${CMAKE_SOURCE_DIR}/lib/)

message(STATUS "SCALAPACK_LIBRARY = ${SCALAPACK_LIBRARY}")

if(NOT (SCALAPACK_LIBRARY))
  return()
endif()

set(SCALAPACK_AoclLibs_FOUND true PARENT_SCOPE)

list(APPEND SCALAPACK_LIBRARY ${CMAKE_THREAD_LIBS_INIT})

set(SCALAPACK_LIBRARY ${SCALAPACK_LIBRARY} PARENT_SCOPE)
set(SCALAPACK_INCLUDE_DIR ${SCALAPACK_INCLUDE_DIR} PARENT_SCOPE)
message(STATUS "End of AOCL Scalapack Linking")
endfunction(scalapack_aocl)


# === main

if(ENABLE_MKL)
  list(APPEND SCALAPACK_FIND_COMPONENTS MKL)
  if(intsize64)
      list(APPEND SCALAPACK_FIND_COMPONENTS MKL64)
  endif(intsize64)
endif()

if(MKL IN_LIST SCALAPACK_FIND_COMPONENTS)
  message(STATUS "MKL defined")
  # we have to sanitize MKLROOT if it has Windows backslashes (\) otherwise it will break at build time
  # double-quotes are necessary per CMake to_cmake_path docs.
  file(TO_CMAKE_PATH "$ENV{MKLROOT}" MKLROOT)

  if(MKL64 IN_LIST SCALAPACK_FIND_COMPONENTS)
    set(_mkl_bitflag i)
  else()
    set(_mkl_bitflag)
  endif()

  # find MKL MPI binding
  if(WIN32)
    if(BUILD_SHARED_LIBS)
      scalapack_mkl(mkl_scalapack_${_mkl_bitflag}lp64_dll mkl_blacs_${_mkl_bitflag}lp64_dll)
    else()
      scalapack_mkl(mkl_scalapack_${_mkl_bitflag}lp64 mkl_blacs_intelmpi_${_mkl_bitflag}lp64)
    endif()
  elseif(APPLE)
    scalapack_mkl(mkl_scalapack_${_mkl_bitflag}lp64 mkl_blacs_mpich_${_mkl_bitflag}lp64)
  else()
    scalapack_mkl(mkl_scalapack_${_mkl_bitflag}lp64 mkl_blacs_intelmpi_${_mkl_bitflag}lp64)
  endif()

  if(MKL64 IN_LIST SCALAPACK_FIND_COMPONENTS)
    set(SCALAPACK_MKL64_FOUND ${SCALAPACK_MKL_FOUND})
  endif()

else()

  find_library(SCALAPACK_LIBRARY
    NAMES scalapack
    NAMES_PER_DIR
    HINTS ${USER_PROVIDED_SCALAPACK_LIBRARY_PATH}    
  )
endif()

# --- Check that Scalapack links

if(SCALAPACK_LIBRARY)
  scalapack_check()
endif()

# --- Finalize

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SCALAPACK
  REQUIRED_VARS SCALAPACK_LIBRARY SCALAPACK_links
  HANDLE_COMPONENTS)

if(SCALAPACK_FOUND)
# need if _FOUND guard to allow project to autobuild; can't overwrite imported target even if bad
set(SCALAPACK_LIBRARIES ${SCALAPACK_LIBRARY})
set(SCALAPACK_INCLUDE_DIRS ${SCALAPACK_INCLUDE_DIR})

if(NOT TARGET SCALAPACK::SCALAPACK)
  add_library(SCALAPACK::SCALAPACK INTERFACE IMPORTED)
  set_target_properties(SCALAPACK::SCALAPACK PROPERTIES
                        INTERFACE_LINK_LIBRARIES "${SCALAPACK_LIBRARIES}"
                        INTERFACE_INCLUDE_DIRECTORIES "${SCALAPACK_INCLUDE_DIR}"
                      )
endif()
endif(SCALAPACK_FOUND)

mark_as_advanced(SCALAPACK_LIBRARY SCALAPACK_INCLUDE_DIR)
