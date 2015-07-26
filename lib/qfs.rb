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

      return f unless block_given?

      yield f
      ensure
        f.close
    end

    ##
    # Open a connection on the specified host ane post, and yield it
    # to a block
    def self.with_client(host, port)
      c = new(host, port)
      begin
        yield c
      ensure
        c.release
      end
    end

    alias_method :exists?, :exists
    alias_method :exist?, :exists?

    alias_method :file?, :isfile

    alias_method :directory?, :isdirectory

    ##
    # Remove a regular file.  Pass 'true' to stop exceptions from
    # being thrown if the file doesn't exist.
    def remove(path, force = false)
      force_remove(force) { super(path) }
    end

    ##
    # Create a directory
    def mkdir(path, mode = 600)
      super(path, mode)
    end

    # Create a directory
    def mkdir_p(path, mode = 600)
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

    ##
    # Recursively remove directories
    def rm_rf(path, force = false)
      force_remove(force) do
        return remove(path) if file?(path)
        readdir(path) do |f|
          fpath = ::File.join(path, f.filename)
          rm_rf(fpath) if directory?(fpath)
          remove(fpath) if file?(fpath)
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
    # Write to a file
    def write(path, data)
      open(path, 'w') { |f| f.write(data) }
    end

    ##
    # Read from a directory, optionally outputting a list of Attr
    # objects or yielding to a block
    def readdir(path)
      attrs = []
      super(path) do |attr|
        unless current_or_previous_dir?(attr.filename)
          block_given? ? yield(attr) : attrs.push(attr)
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

    ##
    # Get an Attr object for the file at the specified path
    def stat(path)
      super(path)
    end

    private

    ##
    # Return if the specified string is the path to the current
    # directory '.' or to the previous directory '..'
    def current_or_previous_dir?(name)
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
      'w' => Qfs::O_WRONLY | Qfs::O_TRUNC | Qfs::O_CREAT
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

  class Attr
    def to_s
      "#{directory? ? 'd' : '-'}#{mode_to_s} #{filename}"
    end

    private

    ##
    # Get the mode as a typically formatted string
    def mode_to_s
      m = mode
      perms = %w(x w r)
      (0..8).to_a.reverse.reduce('') do |sum, i|
        sum + ((m & (1 << i)) != 0 ? perms[i % perms.length] : '-')
      end
    end
  end
end
