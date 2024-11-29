**Note** The presets feature is experimental and work in progress

## Prerequisites
Define the following environment variables for presets to pick up.
```
set "AOCL_ROOT=<path\\to\\AOCL\\dependencies>"
set "METIS_ROOT=<path\\to\\METIS\\installation>"
set "BOOST_ROOT=<path\\to\\Boost\\Headers>"
set "MKL_IMPI_ILP64_ROOT=<path\\to\\64-bit\\MPI\\MKL\\libraries>"
set "MUMPS_VERSION=<supported versions of MUMPS: 5.5.1, 5.6.0, 5.6.1, 5.6.2, 5.7.0, 5.7.1, 5.7.2, 5.7.3>"
```
# How to list all available CMake-Presets?
```
cmake --list-presets
```
# How to configure using CMake-Presets?
```
cmake --preset <preset-config-from-list>
eg.,
    cmake --preset win-ninja-mt-mpi-ilp64-static
```
# How to build the configured preset?
## Using CMake
```
cmake --build build/win-ninja-mt-mpi-ilp64-static --target install --verbose -j 128
```
## Using Presets
```
cmake --build --preset <preset-config-from-list>
eg.,
    cmake --build --preset win-ninja-mt-mpi-ilp64-static
```
# How to run a workflow preset that runs all steps such as configure and build?
```
cmake --workflow --preset <preset-config-from-list>
eg.,
    cmake --workflow --preset win-ninja-mt-mpi-ilp64-static
```