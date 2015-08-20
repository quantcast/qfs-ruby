require 'mkmf'
require 'rbconfig'

INCLUDE_DIRS = [
	RbConfig::CONFIG['includedir'],
	'/usr/include',
]

LIB_DIRS = [
	RbConfig::CONFIG['libdir'],
	'/usr/lib',
]

dir_config 'qfs', INCLUDE_DIRS, LIB_DIRS

with_config('qfs-local-libs', '').split(':').each do |lib|
	$LOCAL_LIBS << " #{lib} "
end

if with_config('version-script')
	$LDFLAGS << " -Wl,--version-script=qfs_ext.version "
end

abort '"kfs/c/qfs.h" is required' unless find_header 'kfs/c/qfs.h'
abort 'libqfsc is required' unless find_library 'qfsc', 'qfs_open'

create_makefile 'qfs_ext'
