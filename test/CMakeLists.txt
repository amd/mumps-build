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

set(Boost_USE_STATIC_LIBS OFF) 
set(Boost_USE_MULTITHREADED ON)  
set(Boost_USE_STATIC_RUNTIME OFF) 
find_package(Boost 1.77 REQUIRED) # header only libraries must not be added here

set_property(DIRECTORY PROPERTY LABELS "unit;mumps")

include(${PROJECT_SOURCE_DIR}/cmake/launcher.cmake)

if(MUMPS_UPSTREAM_VERSION VERSION_LESS 5.1)
  message(STATUS "Mumps version set is less than 5.1. Not supported.")
  return()
endif()

if(BUILD_DOUBLE)
	if(intsize64)
	   add_definitions("-DInt=__int64" "-Dintsize64" "-DUInt=unsigned __int64" "-i8")
	else(intsize64)
	   add_definitions("-DUInt=unsigned int")
	endif(intsize64)
	
	add_executable(amd_aocl amd_mumps.cpp)
	target_include_directories(amd_aocl PUBLIC ${Boost_INCLUDE_DIRS}) 	
  	target_link_libraries(amd_aocl PRIVATE ${IMPI_LIB_ILP64} ${MPI_C_LIBRARIES} MUMPS::MUMPS ${NUMERIC_LIBS} ${Boost_LIBRARIES})
	target_compile_options(amd_aocl PRIVATE /Qopenmp /Qopenmp-threadprivate:compat -DAdd_)
  	target_compile_definitions(amd_aocl PUBLIC MUMPS_MPI=$<BOOL:${MUMPS_parallel}>
                                                      MUMPS_ILP64=$<BOOL:${intsize64}>)   

	add_executable(d_example d_example.cpp)
	target_include_directories(d_example PUBLIC ${Boost_INCLUDE_DIRS}) 	
  	target_link_libraries(d_example PRIVATE ${IMPI_LIB_ILP64} ${MPI_C_LIBRARIES} MUMPS::MUMPS ${NUMERIC_LIBS} ${Boost_LIBRARIES})
	target_compile_options(d_example PRIVATE /Qopenmp /Qopenmp-threadprivate:compat -DAdd_)
  	target_compile_definitions(d_example PUBLIC MUMPS_MPI=$<BOOL:${MUMPS_parallel}>
                                                      MUMPS_ILP64=$<BOOL:${intsize64}>)                                                                                                               
						      	
endif()

get_property(test_names DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY TESTS)

set_property(TEST ${test_names} PROPERTY RESOURCE_LOCK cpu_mpi)

# Windows DLL
if(BUILD_SHARED_LIBS AND CMAKE_VERSION VERSION_GREATER_EQUAL 3.22)
  if(WIN32)
    set_property(TEST ${test_names} PROPERTY
    ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:${CMAKE_INSTALL_FULL_BINDIR};PATH=path_list_prepend:${CMAKE_PREFIX_PATH}/bin;PATH=path_list_prepend:${PROJECT_BINARY_DIR}"
    )
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set_property(TEST ${test_names} PROPERTY
    ENVIRONMENT_MODIFICATION "LIBRARY_PATH=path_list_prepend:${CMAKE_INSTALL_FULL_LIBDIR};LIBRARY_PATH=path_list_prepend:${PROJECT_BINARY_DIR}"
    )
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set_property(TEST ${test_names} PROPERTY
    ENVIRONMENT_MODIFICATION "LD_LIBRARY_PATH=path_list_prepend:${CMAKE_INSTALL_FULL_LIBDIR};LD_LIBRARY_PATH=path_list_prepend:${PROJECT_BINARY_DIR}"
    )
  endif()
endif()
