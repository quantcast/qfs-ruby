require 'mkmf'
require 'rbconfig'

INCLUDE_DIRS = [
  RbConfig::CONFIG['includedir'],
  '/usr/include',
  '/usr/local/include',
]

LIB_DIRS = [
  RbConfig::CONFIG['libdir'],
  '/usr/lib',
  '/usr/local/lib',
]

dir_config 'qfs', INCLUDE_DIRS, LIB_DIRS

with_config('qfs-local-libs', '').split(':').each do |lib|
  $LOCAL_LIBS << " #{lib} "
end

if with_config('version-script', '0') == '1'
  $LDFLAGS << " -Wl,--version-script=#{File.expand_path('../qfs_ext.version', __FILE__)} "
end

abort '"kfs/c/qfs.h" is required' unless find_header 'kfs/c/qfs.h'
abort 'libqfsc is required' unless find_library 'qfsc', 'qfs_open'

$CFLAGS << ' -std=c99 -Wall -Wextra '

$warnflags.gsub!('-Wdeclaration-after-statement', '') if $warnflags

create_makefile 'qfs_ext'
