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
