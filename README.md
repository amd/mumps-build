# MUMPS sparse solver

We avoid distributing extracted MUMPS sources ourselves--instead CMake will download the tarfile and extract, then we inject the CMakeLists.txt and build.

CMake:

* builds MUMPS in parallel 10x faster than the Makefiles
* allows easy reuse of MUMPS in external projects via CMake FetchContent

## Prerequisites
1. Cmake and Ninja Makefile Generator. Make sure Ninja is installed/updated in the Microsoft Visual Studio installation folder @ "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
	a. Latest Ninja Binary at https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip
1. Intel OneAPI toolkit, should include C, C++, Fortran Compilers, MPI, MKL libraries (refer https://software.intel.com/content/www/us/en/develop/articles/oneapi-standalone-components.html#vtune)
2. Prebuilt AOCL libraries for BLAS, LAPACK and Scalapack
	a. AOCL-BLAS, AOCL-LAPACK and Scalapack libraries can be built from source or extracted from AOCL_Windows-setup-xxxx-AMD.exe based on integer size needed, LP64 or ILP64. Refer https://developer.amd.com/amd-aocl/ for more details.
		1. Choose MT Shared libraries for AOCL-BLAS: AOCL-LibBlis-Win-MT-dll.lib and AOCL-LibBlis-Win-MT-dll.dll
		2. Shared libraries for AOCL-LAPACK: AOCL-LibFlame-Win-MT-dll.lib and AOCL-LibFlame-Win-MT-dll.dll
	b. LP64/ILP64 libraries of the dependent libraries (AOCL-BLAS, AOCL-LAPACK and Scalapack) need to be linked with the corresponding Mumps LP64/ILP64 builds

3. If reordering library is chosen to be Metis, Prebuilt Metis Library from SuiteSparse public repo (https://github.com/group-gu/SuiteSparse.git). Build Metis library separately from metis folder. 
	a. cd SuiteSparse\metis-5.1.0
	b. Define IDXTYPEWIDTH and REALTYPEWIDTH to 32/64 based on integer size required in metis/include/metis.h
	c. Configure 
		```
		cmake S . -B ninja_build_dir -G "Ninja" -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON
		```
	d. Build the project		
		```
		cmake --build ninja_build_dir --verbose	
		```	
	3. Library metis.lib should be generated at ninja_build_dir\lib
5. Boost libraries on windows
	a. Required to read mtx files efficiently and quickly
	b. Needed for aocl_amd.cpp test application that links to Mumps libraries and measure performance for a SPD .mtx file	
	c. Download sources and bootstrap as instructed in https://www.boost.org/doc/libs/1_55_0/more/getting_started/windows.html	
	d. Define BOOST_ROOT in tests/CMakeLists.txt

## Build
1. Open Intel oneAPI command prompt for Intel 64 for Visual Studio 2019 from Windows Search box
2. Configure Mumps Project using Ninja:
	```
	cmake S . -B ninja_build_dir -G "Ninja" -DENABLE_AOCL=ON -DENABLE_MKL=OFF -DBUILD_TESTING=ON -DCMAKE_INSTALL_PREFIX="</mumps/install/path>" -Dscotch=ON -Dopenmp=ON -DBUILD_SHARED_LIBS=OFF -Dparallel=ON -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DCMAKE_BUILD_TYPE=Release -DUSER_PROVIDED_BLIS_LIBRARY_PATH="<path/to/blis/library/path>" -DUSER_PROVIDED_BLIS_INCLUDE_PATH="<path/to/blis/headers/path>" -DUSER_PROVIDED_LAPACK_LIBRARY_PATH="<path/to/lapack/library/path>" -DUSER_PROVIDED_LAPACK_INCLUDE_PATH="<path/to/lapack/headers/path>" -DUSER_PROVIDED_SCALAPACK_LIBRARY_PATH="<path/to/scalapack/library/path>" -DUSER_PROVIDED_METIS_LIBRARY_PATH="<path/to/metis/library/path>" -DUSER_PROVIDED_METIS_INCLUDE_PATH="<path/to/metis/include/path>" -DUSER_PROVIDED_IMPILIB_ILP64_PATH=“<path/to/intel/mpi/lib/ilp64>” -DCMAKE_C_COMPILER="C:/Program Files (x86)/Intel/oneAPI/compiler/2021.3.0/windows/bin/intel64/icl.exe" -DCMAKE_CXX_COMPILER="C:/Program Files (x86)/Intel/oneAPI/compiler/2021.3.0/windows/bin/intel64/icl.exe" -DCMAKE_Fortran_COMPILER="C:/Program Files (x86)/Intel/oneAPI/compiler/2021.3.0/windows/bin/intel64/ifort.exe" -DBOOST_ROOT="<path/to/boost>" -Dintsize64=OFF -DMUMPS_UPSTREAM_VERSION="<mumps_src_version>"
	```
	Following options are enabled in the command:
	-DBUILD_TESTING=ON															<Enable Mumps linking to test application to test>
	-Dscotch=OFF 																<Enable Scotch Library for Reordering>
    -Dparmetis=OFF 																<Enable parmetis Library for Reordering>
    -Dmetis=ON 																	<Enable Metis Library for Reordering>
	-Dopenmp=ON 																<Enable Multithreading using openmp>
	-Dintsize64=OFF 															<Enable LP64 i.e., 32 bit integer size>
	-DBUILD_SHARED_LIBS=OFF 													<Enable Static Library>
	-Dparallel=ON 																<Enable Multithreading>
	-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON 											<Enable verbose build log>
	-DCMAKE_BUILD_TYPE=Release 													<Enable Release build>
	-DUSER_PROVIDED_BLIS_LIBRARY_PATH=“<path/to/blis/lib/path>”					<path to AOCL-BLAS library>
	-DUSER_PROVIDED_BLIS_INCLUDE_PATH=“<path/to/blis/include/header>”			<path to AOCL-BLAS's Include header>
	-DUSER_PROVIDED_LAPACK_LIBRARY_PATH=“<path/to/lapack/lib/path>”				<path to AOCL-LAPACK library>
	-DUSER_PROVIDED_LAPACK_INCLUDE_PATH=“<path/to/lapack/include/header>”		<path to AOCL-LAPACK's Include header>
	-DUSER_PROVIDED_SCALAPACK_LIBRARY_PATH=“<path/to/scalapack/lib/path>”		<path to AOCL built Scalapack library>	
	-DUSER_PROVIDED_METIS_LIBRARY_PATH=“<path/to/metis/lib>”					<path to Metis library>
	-DUSER_PROVIDED_METIS_INCLUDE_PATH=“<path/to/metis/header>”					<path to Metis Include header>
	-DUSER_PROVIDED_IMPILIB_ILP64_PATH=“<path/to/intel/mpi/lib/ilp64>”			<path to Intel's ILP64 MPI library>
	-DCMAKE_C_COMPILER=“<path/to/intel c compiler>”								<path to Intel C Compiler>
	-DCMAKE_Fortran_COMPILER=“<path/to/intel fortran compiler>”					<path to Intel Fortran Compiler>
	-DBOOST_ROOT=“<path/to/BOOST/INSTALLATION>”									<path to Boost libraries/headers>
	-DMUMPS_UPSTREAM_VERSION="mumps sources version"							<mumps src tarball versions. Tested for 5.4.1, 5.5.0>
3. AOCL dependencies can also be configured using AOCL_ROOT. Define the environment variable AOCL_ROOT to point to AOCL libs installation
	```
	set "AOCL_ROOT=C:\Program Files\AMD\AOCL-Windows"
	```
	```
	cmake S . -B ninja_build_dir -G "Ninja" -DENABLE_AOCL=ON -DENABLE_MKL=OFF -DBUILD_TESTING=ON -DCMAKE_INSTALL_PREFIX="</mumps/install/path>" -Dscotch=ON -Dopenmp=ON -DBUILD_SHARED_LIBS=OFF -Dparallel=ON -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DCMAKE_BUILD_TYPE=Release -DUSER_PROVIDED_METIS_LIBRARY_PATH="<path/to/metis/library/path>" -DUSER_PROVIDED_METIS_INCLUDE_PATH="<path/to/metis/include/path>" -DUSER_PROVIDED_IMPILIB_ILP64_PATH=“<path/to/intel/mpi/lib/ilp64>” -DCMAKE_C_COMPILER="C:/Program Files (x86)/Intel/oneAPI/compiler/2021.3.0/windows/bin/intel64/icl.exe" -DCMAKE_CXX_COMPILER="C:/Program Files (x86)/Intel/oneAPI/compiler/2021.3.0/windows/bin/intel64/icl.exe" -DCMAKE_Fortran_COMPILER="C:/Program Files (x86)/Intel/oneAPI/compiler/2021.3.0/windows/bin/intel64/ifort.exe" -DBOOST_ROOT="<path/to/boost_1_77_0>" -Dintsize64=OFF -DMUMPS_UPSTREAM_VERSION="<mumps_src_version>"
	```
4. 	Toggle/Edit above options to get
	1. Debug or Release build
	2. LP64 or ILP64 libs
	
5. Build the project
	```
	cmake --build ninja_build_dir --verbose
	```
6. Run the executable at ninja_build_dir\test
	```
	mpiexec -env I_MPI_PIN_DOMAIN cache3 -n 2 amd_mumps_aocl LFAT5.mtx 1 1 1
	```
## Note
1. Cmake Build system will download latest Mumps tar ball by default and proceed with configuration and build generation
2. Currently Metis Reordering is tested. Disabling the option "-Dscotch=OFF" would enable Mumps's internal reordering. Set the appropriate init parameter before calling MUMPS API in the linking test code
