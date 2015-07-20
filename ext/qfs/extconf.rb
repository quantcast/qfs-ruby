require 'mkmf'

abort '"kfs/c/qfs.h" is required' unless find_header 'kfs/c/qfs.h'
abort 'libkfs_access is required' unless find_library 'qfsc', 'qfs_open'

create_makefile 'qfs'
