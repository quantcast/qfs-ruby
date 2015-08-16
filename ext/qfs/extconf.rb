require 'mkmf'

INCLUDE_DIRS = [
	Config::CONFIG['includedir'],
	'/usr/include',
]

LIB_DIRS = [
	Config::CONFIG['libdir'],
	'/usr/lib',
]

dir_config 'qfs', INCLUDE_DIRS, LIB_DIRS

abort '"kfs/c/qfs.h" is required' unless find_header 'kfs/c/qfs.h'
abort 'libqfsc is required' unless find_library 'qfsc', 'qfs_open'

create_makefile 'qfs_ext'
