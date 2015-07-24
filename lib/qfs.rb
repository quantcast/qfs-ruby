require 'qfs/version'
require 'qfs_ext'
require 'fcntl'

##
# Container module for QFS classes
module Qfs
  # supported oflags
  O_CREAT = Fcntl::O_CREAT
  O_EXCL = Fcntl::O_EXCL
  O_RDWR = Fcntl::O_RDWR
  O_RDONLY = Fcntl::O_RDONLY
  O_WRONLY = Fcntl::O_WRONLY
  O_TRUNC = Fcntl::O_TRUNC
  O_APPEND = Fcntl::O_APPEND

  ##
  # A higher-level Client to interact with QFS.  This attempts to use
  # a similar interface to ruby's native IO functionality.
  class Client < BaseClient
    ##
    # Open a file on QFS.  This method uses a very similar interface to the
    # 'open' method standard in ruby.
    #
    # #### Modes
    #   * 'r': Read only
    #   * 'w': Write only, overwrite or create new file
    #   * 'a': Write only, append to file or create.
    #
    # #### Options
    #   * flags: Alternative place to pass the mode strings above
    #   * mode:
    #   * params:
    def open(path, mode_str, options = {})
      flags = options[:flags]
      flags ||= mode_to_flags(mode_str)
      fail "#{mode_str} is not a valid mode string" if flags.nil?

      mode ||= options[:mode]
      params ||= options[:params]
      f = super(path, flags, mode, params)

      if block_given?
        begin
          yield f
        ensure
          f.close
        end
      else
        return f
      end
    end

    ##
    # Check if the specified (absolute) path exists.
    def exists?(path)
      exists(path)
    end

    alias file? isfile

    alias directory? isdirectory

    ##
    # Remove a regular file.  Pass 'true' to stop exceptions from
    # being thrown if the file doesn't exist.
    def remove(path, force = false)
      force_remove(force) { super(path) }
    end

    ##
    # Create a directory
    def mkdir(path, mode=600)
      super(path, mode)
    end

    # Create a directory
    def mkdir_p(path, mode=600)
      super(path, mode)
    end

    ##
    # Remove a directory
    def rmdir(path, force = false)
      force_remove(force) { super(path) }
    end

    ##
    # Remove a directory recursively
    def rmdirs(path, force = false)
      force_remove(force) { super(path) }
    end

    def rm_rf(path, force = false)
      force_remove(force) do
        return remove(path) if file?(path)
        readdir(path) do |f|
          unless f.filename == '.' || f.filename == '..'
            fpath = ::File.join(path, f.filename)
            if directory?(fpath)
              begin
                rmdir(fpath)
              rescue Qfs::Error
                rm_rf(fpath)
              end
            end
            remove(fpath)
          end
        end
        rmdir(path)
      end
    end

    ##
    # Read from a file
    def read(path, len = nil)
      open(path, 'r') { |f| f.read(len) }
    end

    ##
    # Read from a directory, optionally outputting a list of Attr
    # objects or yielding to a block
    def readdir(path)
      attrs = []
      super(path) do |attr|
        unless is_current_or_previous_dir(attr.filename)
          if block_given? then yield(attr) else attrs.push(attr) end
        end
      end

      return attrs unless block_given?
    end

    ##
    # Change the permissions of a file or directory
    # Specify "recursive: true" if needed
    def chmod(path, mode_int, options = {})
      return chmod_r(path, mode_int) if options[:recursive]
      super(path, mode_int)
    end

    private

    ##
    # Return if the specified string is the path to the current
    # directory '.' or to the previous directory '..'
    def is_current_or_previous_dir(name)
      case name
      when '.', '..'
        true
      else
        false
      end
    end

    ##
    # If force is true, call the block and just return zero if it
    # throws an exception
    def force_remove(force)
      return yield unless force
      begin
        return yield
      rescue Qfs::Error
        return 0
      end
    end

    ##
    # Maps mode strings to oflags
    MODE_STR_TO_FLAGS = {
      'r' => Qfs::O_RDONLY,
      'w' => Qfs::O_WRONLY | Qfs::O_TRUNC | Qfs::O_CREAT,
    }

    ##
    # Convert the mode strings to oflags
    def mode_to_flags(mode)
      MODE_STR_TO_FLAGS[mode]
    end
  end

  class File
    ##
    # Read from a file.  Don't specify a length to read the entire file.
    def read(len = nil)
      len ||= stat.size
      read_len(len)
    end
  end

  class BaseClient
    def self.with_client host, port
      c = self.new host, port
      begin
        yield c
      ensure
        c.release
      end
    end
    def intervals path
      readdir path do |y|
        year = y.filename
        if year.match /\d{4}/
          readdir "#{path}/#{year}" do |m|
            month = m.filename
            if month.match /\d\d/
              readdir "#{path}/#{year}/#{month}" do |d|
                day = d.filename
                if day.match /\d\d/
                  readdir "#{path}/#{year}/#{month}/#{day}" do |i|
                    if i.filename.match /\.s\d+\.e\d+/
                      yield "#{path}/#{year}/#{month}/#{day}/#{i.filename}"
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  class Attr
    def to_s
      m = mode
      "#{directory? ? 'd' : '-'
      }#{(m & (1 << 8)) != 0 ? 'r' : '-'
      }#{(m & (1 << 7)) != 0 ? 'w' : '-'
      }#{(m & (1 << 6)) != 0 ? 'x' : '-'
      }#{(m & (1 << 5)) != 0 ? 'r' : '-'
      }#{(m & (1 << 4)) != 0 ? 'w' : '-'
      }#{(m & (1 << 3)) != 0 ? 'x' : '-'
      }#{(m & (1 << 2)) != 0 ? 'r' : '-'
      }#{(m & (1 << 1)) != 0 ? 'w' : '-'
      }#{(m & (1 << 0)) != 0 ? 'x' : '-'
      } #{filename}"
    end
  end
end
