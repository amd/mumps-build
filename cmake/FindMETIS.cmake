# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

# Modifications Copyright (c) 2021-2025 Advanced Micro Devices, Inc. All rights reserved

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


if(ParMETIS IN_LIST METIS_FIND_COMPONENTS)
  find_library(PARMETIS_LIBRARY
  NAMES parmetis
  PATH_SUFFIXES METIS libmetis
  DOC "ParMETIS library"
  )
  if(PARMETIS_LIBRARY)
    set(METIS_ParMETIS_FOUND true)
  endif()
endif()
find_library(METIS_LIBRARY
NAMES metis
PATH_SUFFIXES METIS libmetis
HINTS ${USER_PROVIDED_METIS_LIBRARY_PATH} ${CMAKE_METIS_ROOT}/metis ${CMAKE_METIS_ROOT} 
DOC "METIS library"
)
if(NOT METIS_LIBRARY)
  message(FATAL_ERROR "Metis library not found")
endif() 

if(ParMETIS IN_LIST METIS_FIND_COMPONENTS)
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

set(METIS_LIBRARIES ${PARMETIS_LIBRARY} ${METIS_LIBRARY})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(METIS
REQUIRED_VARS METIS_LIBRARIES METIS_INCLUDE_DIR
HANDLE_COMPONENTS
)

if(METIS_FOUND)
  set(METIS_INCLUDE_DIRS ${METIS_INCLUDE_DIR})

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
