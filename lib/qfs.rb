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

  # A higher-level Client to interact with QFS.  This attempts to use
  # a similar interface to ruby's native IO functionality.
  class Client < BaseClient
    # Open a file on QFS.  This method uses a very similar interface to the
    # 'open' method standard in ruby.
    #
    # Modes
    #   * 'r': Read only
    #   * 'w': Write only, overwrite or create new file
    #
    # @param [String] path the path to the file
    # @param [Int] mode_str One of the mode types above
    # @option options [Int] :mode permissions to set on the file
    # @option options [String] :params
    #
    # @return [File] a Qfs::File
    # @yield [File] a Qfs::File
    def open(path, mode_str, options = {})
      flags = mode_to_flags(mode_str)
      raise Qfs::Error, "#{mode_str} is not a valid mode string" if flags.nil?

      mode ||= options[:mode]
      params ||= options[:params]
      f = super(path, flags, mode, params)

      return f unless block_given?

      begin
        yield f
      ensure
        f.close
      end
    end

    # Open a connection on the specified host and post, and yield it
    # to a block
    #
    # @example Open a connection and yield to a block
    #   Qfs::Client.with_client('localhost', 10000) do |client|
    #     client.write('/file', '')
    #   end
    #
    # @param [String] host the hostname to connect to
    # @param [Int] port the port to connect to
    #
    # @yield [Client] a new client
    def self.with_client(host, port)
      c = new(host, port)
      begin
        yield c
      ensure
        c.release
      end
    end

    alias exists? exists
    alias exist? exists?

    alias file? isfile

    alias directory? isdirectory

    # Remove a regular file.  Pass 'true' to stop exceptions from
    # being thrown if the file doesn't exist.
    #
    # @param [String] path the path to the file
    # @param [Bool] force Wheather or not to throw an exception if file doesn't
    #                     exist.
    #
    # @raise [Error] if force=false
    #
    # @return [Bool] if or if not the method succeeded
    def remove(path, force = false)
      force_remove(force) { super(path) }
    end

    # Create a directory
    #
    # @param [String] path the path to the directory to make
    # @param [Int] mode the permissions to set on the new directory
    #
    # @return [Bool] if the directory was created
    def mkdir(path, mode = 0o600)
      super(path, mode)
    end

    # Create a directory and create parent directories if needed
    #
    # @param [String] path the path to the directory to make
    # @param [Int] mode the permissions to set on the new directory
    #
    # @return [Bool] if the directory was created
    def mkdir_p(path, mode = 0o600)
      super(path, mode)
    end

    # Remove a directory
    #
    # @param [String] path the path to the file
    # @param [Bool] force Whether or not to throw an exception if the operation
    #                     fails
    #
    # @raise [Error] if force=false
    #
    # @return [Bool] if or if not the method succeeded
    def rmdir(path, force = false)
      force_remove(force) { super(path) }
    end

    # Remove a directory recursively
    #
    # @param [String] path the path to the file
    # @param [Bool] force Whether or not to throw an exception if the directory
    #                     doesn't exist.
    #
    # @raise [Error] if force=false
    #
    # @return [Bool] if or if not the method succeeded
    def rmdirs(path, force = false)
      force_remove(force) { super(path) }
    end

    # Recursively remove directories and files.
    #
    # @param [String] path the path to the file
    # @param [Bool] force Whether or not to throw an exception if the directory
    #                     doesn't exist.
    #
    # @raise [Error] if force=false
    #
    # @return [Bool] if or if not the method succeeded
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

    # Read from a file and return the data
    #
    # @param [String] path the path to the file
    # @param [Int] len the number of bytes to read
    #
    # @return [String] the data from the file
    def read(path, len = nil)
      open(path, 'r') { |f| f.read(len) }
    end

    # Write to a file
    #
    # @param [String] path the path to the file
    # @param [String] data the data to be written
    #
    # @return [String] the number of bytes written
    def write(path, data)
      open(path, 'w') { |f| f.write(data) }
    end

    # Read from a directory, optionally outputting a list of Attr
    # objects or yielding to a block
    #
    # @example Usage with a block:
    #   client.readdir('/') do |paths|
    #     puts paths.filename
    #   end
    #
    # @example Usage without a block:
    #   client.readdir('/').each do |paths|
    #     puts paths.filename
    #   end
    #
    # @param [String] path the path to read from
    #
    # @return [Array<Attr>] a list of Attr objects
    #
    # @yield [Attr] Attr objects
    def readdir(path)
      attrs = []
      super(path) do |attr|
        unless current_or_previous_dir?(attr.filename)
          block_given? ? yield(attr) : attrs.push(attr)
        end
      end

      return attrs unless block_given?
    end

    # Change the permissions of a file or directory
    #
    # @param [String] path Path to the file to chmod
    # @param [Int] mode_int The permissions to set
    # @option options [Bool] :recursive Set to recursively chmod the directory
    def chmod(path, mode_int, options = {})
      return chmod_r(path, mode_int) if options[:recursive]
      super(path, mode_int)
    end

    # Get an Attr object for the file at the specified path
    #
    # Note that this method will cache it's result for a specific file for the
    # entire lifetime of a Client object.  If you need to get an updated Attr
    # for a file/directory, you need to create a new Client.
    #
    # @param [String] path The path to the file or directory to stat
    #
    # @return [Attr] An attr object
    def stat(path)
      super(path)
    end

    # Move a file to a new path.
    #
    # @param [String] old The path to the file to move
    # @param [String] new The new destination
    def move(old, new)
      rename(old, new)
    end

    # Change the current working directory
    #
    # @param [String] path The directory to change to
    def cd(path)
      super(path)
    end

    # Set the current working directory
    #
    # @param [String] path The directory to change to
    def setwd(path)
      super(path)
    end

    # Return the current working directory
    #
    # @param [Int] len The length of the buffer that should be allocated
    #                  to store the cwd.  An exception will be thrown if it
    #                  is too small.
    #
    # @return [String] The current working directory
    def cwd
      super
    end

    private

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

    # If force is true, call the block and just return zero if it
    # throws an exception
    def force_remove(force)
      return yield unless force
      begin
        return yield
      rescue Errno::ENOENT
        return 0
      end
    end

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

  ##
  # A File on QFS.
  class File
    # Read from a file.  Don't specify a length to read the entire file.
    #
    # @param [Int] len the number of bytes to read. Omit or set to nil to
    # read the entire file.
    #
    # @return [String] the data read from the file.
    def read(len = nil)
      len ||= stat.size
      read_len(len)
    end
  end

  # A container class for the properties of a file or directory.
  # These can be retrieved with either Client::stat or File#stat.
  #
  # @attr_reader [String] filename The base name of the file/directory
  # @attr_reader [Int] id
  # @attr_reader [Int] mode The permissions set on the file/directory
  # @attr_reader [Int] uid User ID
  # @attr_reader [Int] gid Group ID
  # @attr_reader [Time] mtime The time last modified
  # @attr_reader [Time] ctime The time the file/directory's attributes were
  #                           changed
  # @attr_reader [Bool] directory If the file is a directory
  # @attr_reader [Int] size The size of the file
  # @attr_reader [Int] chunks The number of chunks in the file or files in a
  #                           directory
  # @attr_reader [Int] directories The number of subdirectories
  # @attr_reader [Int] replicas
  # @attr_reader [Int] stripes
  # @attr_reader [Int] recovery_stripes
  # @attr_reader [Int] striper_type
  # @attr_reader [Int] stripe_size
  # @attr_reader [Int] min_stier
  # @attr_reader [Int] max_stier
  class Attr
    def to_s
      "#{directory? ? 'd' : '-'}#{mode_to_s} #{filename}"
    end

    private

    ##
    # Get the mode as a typically formatted string
    # returns a string in the form 'rwxrwxrwx'
    def mode_to_s
      m = mode
      perms = %w(x w r)
      8.downto(0).reduce('') do |sum, i|
        sum + ((m & (1 << i)) != 0 ? perms[i % perms.length] : '-')
      end
    end
  end
end
