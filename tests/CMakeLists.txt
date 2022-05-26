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

# testing what we just built

set(Boost_USE_STATIC_LIBS OFF) 
set(Boost_USE_MULTITHREADED ON)  
set(Boost_USE_STATIC_RUNTIME OFF) 
find_package(Boost 1.77 REQUIRED) # header only libraries must not be added here

#copy the libraries into tests directory to run executable successfully

if(ENABLE_AOCL)	
	configure_file(${USER_PROVIDED_BLIS_LIBRARY_PATH}/AOCL-LibBlis-Win-MT-dll.lib ${CMAKE_BINARY_DIR}/tests/ COPYONLY)
	configure_file(${USER_PROVIDED_BLIS_LIBRARY_PATH}/AOCL-LibBlis-Win-MT-dll.dll ${CMAKE_BINARY_DIR}/tests/ COPYONLY)

	configure_file(${USER_PROVIDED_LAPACK_LIBRARY_PATH}/AOCL-LibFLAME-Win.lib ${CMAKE_BINARY_DIR}/tests/ COPYONLY)
	configure_file(${USER_PROVIDED_LAPACK_LIBRARY_PATH}/AOCL-LibFLAME-Win.dll ${CMAKE_BINARY_DIR}/tests/ COPYONLY)

	configure_file(${USER_PROVIDED_SCALAPACK_LIBRARY_PATH}/scalapack.lib ${CMAKE_BINARY_DIR}/tests/ COPYONLY)
	configure_file(${USER_PROVIDED_SCALAPACK_LIBRARY_PATH}/scalapack.dll ${CMAKE_BINARY_DIR}/tests/ COPYONLY)
	configure_file(${USER_PROVIDED_METIS_LIBRARY_PATH}/metis.lib ${CMAKE_BINARY_DIR}/tests/ COPYONLY)
endif()
if("d" IN_LIST arith)
	add_executable(amd_aocl amd_mumps.cpp)
	target_compile_options(amd_aocl PRIVATE /Qopenmp /Qopenmp-threadprivate:compat -DAdd_)
	if(intsize64)
	   add_definitions("-DInt=__int64" "-Dintsize64" "-DUInt=unsigned __int64" "-i8")
	else(intsize64)
	   add_definitions("-DUInt=unsigned int")
	endif(intsize64)
	set(CMAKE_POSITION_INDEPENDENT_CODE ON)
	target_include_directories(amd_aocl PUBLIC ${Boost_INCLUDE_DIRS}) 	
  target_link_libraries(amd_aocl PRIVATE ${IMPI_LIB_ILP64} ${MPI_C_LIBRARIES} MUMPS::MUMPS ${NUMERIC_LIBS} ${Boost_LIBRARIES})
endif()

if("d" IN_LIST arith)
	add_executable(Csimple simple.c)
	target_compile_options(Csimple PRIVATE /Qopenmp /Qopenmp-threadprivate:compat -DAdd_)
	if(intsize64)
	   add_definitions("-DInt=__int64" "-Dintsize64" "-DUInt=unsigned __int64" "-i8")
	else(intsize64)
	   add_definitions("-DUInt=unsigned int")
	endif(intsize64)
	set(CMAKE_POSITION_INDEPENDENT_CODE ON)	
  target_link_libraries(Csimple PRIVATE ${IMPI_LIB_ILP64} ${MPI_C_LIBRARIES} MUMPS::MUMPS ${NUMERIC_LIBS})
endif()

if(MUMPS_UPSTREAM_VERSION VERSION_LESS 5.1)
  return()
endif()

# Windows DLL
get_property(test_names DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY TESTS)

set_tests_properties(${test_names} PROPERTIES
RESOURCE_LOCK cpu_mpi
TIMEOUT 30
)

if(WIN32 AND CMAKE_VERSION VERSION_GREATER_EQUAL 3.22)
  set_tests_properties(${test_names} PROPERTIES
  ENVIRONMENT_MODIFICATION "PATH=path_list_append:${CMAKE_INSTALL_PREFIX}/bin;PATH=path_list_append:${CMAKE_PREFIX_PATH}/bin;PATH=path_list_append:${PROJECT_BINARY_DIR}"
  )
endif()
