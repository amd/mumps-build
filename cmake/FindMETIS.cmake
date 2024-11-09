# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

# Modifications Copyright (c) 2021-2024 Advanced Micro Devices, Inc. All rights reserved

#[=======================================================================[.rst:
FindMETIS
-------
Michael Hirsch, Ph.D.

Finds the METIS library.
NOTE: If libparmetis used, libmetis must also be linked.

Imported Targets
^^^^^^^^^^^^^^^^

METIS::METIS

Result Variables
^^^^^^^^^^^^^^^^

METIS_LIBRARIES
  libraries to be linked

METIS_INCLUDE_DIRS
  dirs to be included

#]=======================================================================]


if(parallel IN_LIST METIS_FIND_COMPONENTS)
  find_library(PARMETIS_LIBRARY
    NAMES parmetis
    HINTS ${USER_PROVIDED_METIS_LIBRARY_PATH}    
    DOC "ParMETIS library"
    )
  if(PARMETIS_LIBRARY)
    set(METIS_parallel_FOUND true)
  endif()
endif()

find_library(
  METIS_LIBRARY
  NAMES metis
  HINTS ${USER_PROVIDED_METIS_LIBRARY_PATH} ${CMAKE_METIS_ROOT}/metis ${CMAKE_METIS_ROOT} 
  PATH_SUFFIXES "lib/${ILP_DIR}/shared" "lib/${ILP_DIR}" "lib_${ILP_DIR}" "lib"
  DOC "External Metis library")
if(NOT METIS_LIBRARY)
  message(FATAL_ERROR "Metis library not found")
endif()    

if(parallel IN_LIST METIS_FIND_COMPONENTS)
  set(metis_inc parmetis.h)
else()
  set(metis_inc metis.h)
endif()

find_path(
  METIS_INCLUDE_DIR
  NAMES ${metis_inc}
  HINTS ${USER_PROVIDED_METIS_INCLUDE_PATH} ${CMAKE_METIS_ROOT}/metis ${CMAKE_METIS_ROOT}
  PATH_SUFFIXES "include/${ILP_DIR}" "include_${ILP_DIR}" "include"
  DOC "External Metis headers")
if(NOT METIS_INCLUDE_DIR)
  message(FATAL_ERROR "Metis Headers not found")
endif()    

configure_file(
  ${METIS_INCLUDE_DIR}/${metis_inc}
  ${CMAKE_SOURCE_DIR}/include/${metis_inc} @ONLY)
  
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(METIS
REQUIRED_VARS METIS_LIBRARY METIS_INCLUDE_DIR
HANDLE_COMPONENTS
)

if(METIS_FOUND)

set(METIS_LIBRARIES ${PARMETIS_LIBRARY} ${METIS_LIBRARY})
set(METIS_INCLUDE_DIRS ${METIS_INCLUDE_DIR})

message(VERBOSE "METIS libraries: ${METIS_LIBRARIES}
METIS include directories: ${METIS_INCLUDE_DIRS}")

if(NOT TARGET METIS::METIS)
  add_library(METIS::METIS INTERFACE IMPORTED)
  set_property(TARGET METIS::METIS PROPERTY INTERFACE_LINK_LIBRARIES "${METIS_LIBRARIES}")
  set_property(TARGET METIS::METIS PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${METIS_INCLUDE_DIR}")
endif()
endif(METIS_FOUND)

message(STATUS "Dependencies (libraries and includes)")
message(STATUS "  \$METIS LIBRARY......${METIS_LIBRARY}")
message(STATUS "  \$METIS Headers......${METIS_INCLUDE_DIR}")
mark_as_advanced(METIS_INCLUDE_DIR METIS_LIBRARY PARMETIS_LIBRARY)
