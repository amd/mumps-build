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

# patching MUMPS 5.4.0, 5.4.1 mumps_io.h

if(mumps_patched)
  return()
endif()

set(mumps_orig ${mumps_SOURCE_DIR}/src/mumps_io.h)
set(mumps_patch_file ${CMAKE_CURRENT_LIST_DIR}/mumps_io.h)

# TBD: WSL not present as part of Intel OneAPI command line. So native fix of scivision patch
# application using WSL does not work. So the mumps_io.h file with the fix is copied into 
# sources after the MUMPS package download
# Once this fix moves to upstream and available through mumps_xxxx.tgz tarball, then the below copy of fixed file can be removed
# <IMPORTANT> Any other changes in mumps_io.h need to be updated inside this file before copy
configure_file(
  ${mumps_patch_file}
  ${mumps_orig} @ONLY)

set(mumps_patched true CACHE BOOL "MUMPS mumps_io.h is patched")
message(STATUS "MUMPS mumps_io.h is patched: ${mumps_patched}")
