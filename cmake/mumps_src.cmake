# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

# Modifications Copyright (c) 2021-2025 Advanced Micro Devices, Inc. All rights reserved

#=======================================================================

# a few versions of MUMPS are known to work and are specifically listed in the
# libraries.json file.

include(FetchContent)
set(FETCHCONTENT_QUIET off)

if(NOT CMAKE_EXTERNAL_BUILD_DIR)
    set(CMAKE_EXTERNAL_BUILD_DIR "./external")
endif()
get_filename_component(fc_base ${CMAKE_EXTERNAL_BUILD_DIR}
                      REALPATH BASE_DIR "${CMAKE_BINARY_DIR}")
set(FETCHCONTENT_BASE_DIR ${fc_base})

string(TOLOWER ${PROJECT_NAME}_src name)

if(local)

  find_file(${name}_archive
  NAMES ${name}.tar.bz2 ${name}.tar.gz ${name}.tar ${name}.zip ${name}.tar.zstd ${name}.tar.xz ${name}.tar.lz
  HINTS ${local}
  NO_DEFAULT_PATH
  )

  if(NOT ${name}_archive)
    message(FATAL_ERROR "Archive file for ${name} does not exist under ${local}")
  endif()

  message(STATUS "${name}: using source archive ${${name}_archive}")

  FetchContent_Declare(${PROJECT_NAME}
  URL ${${name}_archive}
  )

else(local)

  if(NOT MUMPS_UPSTREAM_VERSION)
    message(FATAL_ERROR "please specify MUMPS_UPSTREAM_VERSION")
  endif()

  if(MUMPS_UPSTREAM_VERSION VERSION_LESS 5.6.0)
    set(urls)
    set(sha256)

    file(READ ${CMAKE_CURRENT_LIST_DIR}/libraries.json json)

    string(JSON N LENGTH ${json} ${name} ${MUMPS_UPSTREAM_VERSION} urls)
    if(NOT "${N}")
      message(FATAL_ERROR "MUMPS ${MUMPS_UPSTREAM_VERSION} not found in ${CMAKE_CURRENT_LIST_DIR}/libraries.json
      ${N}")
    endif()
    math(EXPR N "${N}-1")
    foreach(i RANGE ${N})
      string(JSON _u GET ${json} ${name} ${MUMPS_UPSTREAM_VERSION} urls ${i})
      list(APPEND urls ${_u})
    endforeach()

    string(JSON sha256 GET ${json} ${name} ${MUMPS_UPSTREAM_VERSION} sha256)

    if(NOT urls)
      message(FATAL_ERROR "unknown MUMPS_UPSTREAM_VERSION ${MUMPS_UPSTREAM_VERSION}.
      Make a GitHub issue to request this in ${CMAKE_CURRENT_LIST_DIR}/libraries.json
      ")
    endif()

    message(DEBUG "MUMPS archive source URLs: ${urls}")

    message(STATUS "[mumps_src] MUMPS_UPSTREAM_VERSION = ${MUMPS_UPSTREAM_VERSION}")
    FetchContent_Declare(${PROJECT_NAME}
      URL ${urls}
      URL_HASH SHA256=${sha256}
      GIT_REMOTE_UPDATE_STRATEGY "CHECKOUT"
      INACTIVITY_TIMEOUT 60
      )  
  endif()                        
endif(local)

FetchContent_GetProperties(${PROJECT_NAME})
if(NOT ${PROJECT_NAME}_POPULATED)
  if(MUMPS_UPSTREAM_VERSION VERSION_LESS 5.6.0)
    message(STATUS "[mumps_src] less than 5.6.0")
    FetchContent_Populate(${PROJECT_NAME})
  else()
    message(STATUS "[mumps_src] greater than equal 5.6.0")
    set(url "https://mumps-solver.org/MUMPS_${MUMPS_UPSTREAM_VERSION}.tar.gz")
    FetchContent_Populate(${PROJECT_NAME}
    SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/mumps-src/${MUMPS_UPSTREAM_VERSION}
    URL ${url}
    TLS_VERIFY ${CMAKE_TLS_VERIFY}
    )    
  endif()
endif()

if(MUMPS_UPSTREAM_VERSION VERSION_EQUAL 5.4.0 OR MUMPS_UPSTREAM_VERSION VERSION_EQUAL 5.4.1)
  message(STATUS "Applying mumps patch for 5.4.0/5.4.1 versions")
  include(${CMAKE_CURRENT_LIST_DIR}/mumps_patch.cmake)
endif()
