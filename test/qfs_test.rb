require 'minitest/autorun'
require 'test_helper'
require 'qfs'

class TestQfs < Minitest::Test
  BASE_TEST_PATH = '/ruby-qfs'

  def initialize(name = nil)
    @test_name = name
    super(name) unless name.nil?
  end

  def clear_test_files
    if @client.exists?(@file)
      @client.remove(@file) if @client.file?(@file)
      @client.rm_rf(@file) if @client.directory?(@file)
    end
  end

  def setup
    @client = Qfs::Client.new 'localhost', 10000
    @client.mkdir_p(BASE_TEST_PATH, 0777) if !@client.exists?(BASE_TEST_PATH)
    @file = get_test_path(@test_name)
    clear_test_files
  end

  def teardown
    clear_test_files
    @client.release
  end

  def get_test_path(p)
    File.join(BASE_TEST_PATH, p)
  end

  def random_data(len = 20)
    (0...len).map { (65 + rand(26)).chr }.join
  end

  def stat(path)
    Qfs::Client.with_client('localhost', 10000) { |c| c.stat(path) }
  end

  def test_open
    data = random_data
    @client.open(@file, 'w') do |f|
      f.write(data)
    end
    @client.open(@file, 'r') do |f|
      assert_equal(data, f.read(data.length))
    end
  end

  def test_tell
    data = random_data
    @client.open(@file, 'w') do |f|
      f.write(data)
      assert_equal(data.length, f.tell())
    end
    @client.open(@file, 'w') do |f|
      assert_equal(0, f.tell())
    end
  end

  def test_remove
    @client.open(@file, 'w') do |f|
      f.write('');
    end
    res = @client.remove(@file)
    assert !@client.exists?(@file)
    assert_equal(1, res)

    assert_raises(Qfs::Error) { @client.remove(@file) }
    assert_equal(0, @client.remove(@file, true))
  end

  def test_exists
    @client.open(@file, 'w') do |f|
      f.write('')
    end
    assert @client.exists?(@file)

    @client.remove(@file)
    assert !@client.exists?(@file)
  end

  def test_mkdir_rmdir
    assert @client.mkdir(@file)
    assert @client.exists?(@file)

    assert_raises(Qfs::Error) { @client.mkdir(@file) }
    assert @client.rmdir(@file)
    assert !@client.exists?(@file)

    assert_raises(Qfs::Error) { @client.rmdir(@file) }
    assert_equal(0, @client.remove(@file, true))
  end

  def test_mkdirp_rmdirs
    # Stock local development servers have odd permission
    # settings that seem to be causing "qfs_mkdirs" to fail
    # on creating multiple levels of folder.
    #file = File.join(@file, 'test', 'a', 'long' 'path')
    file = File.join(@file)
    assert @client.mkdir_p(file, 777)
    assert @client.exists?(file)

    assert @client.rmdirs(file)
    assert !@client.exists(file)
  end

  def test_directory
    @client.mkdir(@file)
    assert @client.directory?(@file)
    @client.rmdir(@file)

    @client.open(@file, 'w') { |f| f.write('') }
    assert !@client.directory?(@file)
    @client.remove(@file)

    assert !@client.directory?(@file)
  end

  def test_client_stat
    data = random_data(rand(1000))
    @client.open(@file, 'w') do |f|
      f.write(data)
    end

    res = @client.stat(@file)

    assert_equal(data.length, res.size)
    assert_equal(File.basename(@file), res.filename)

    assert_raises(Qfs::Error) { @client.stat('not a real file') }
  end

  def test_file_stat
    data = random_data(rand(1000))
    @client.open(@file, 'w') do |f|
      f.write(data)
    end

    @client.open(@file, 'r') do |f|
      res = f.stat
      assert_equal(data.length, res.size)
      assert_equal(File.basename(@file), res.filename)
    end
  end

  def test_read_all
    data = random_data(rand(1000))
    @client.open(@file, 'w') { |f| f.write(data) }
    @client.open(@file, 'r') do |f|
      len = rand(data.length)
      assert_equal(data[0..(len-1)], f.read(len))
    end
    @client.open(@file, 'r') do |f|
      assert_equal(data, f.read)
    end
  end

  def test_read_client
    data = random_data(rand(1000))
    len = rand(data.length)
    @client.open(@file, 'w') { |f| f.write(data) }
    assert_equal(data[0..(len-1)], @client.read(@file, len))
    assert_equal(data, @client.read(@file))
  end

  def test_chmod
    @client.open(@file, 'w') { |f| f.write('test') }

    run_chmod = proc do |mode|
      @client.chmod(@file, mode)
      Qfs::Client.with_client('localhost', 10000) do |c|
        assert_equal(mode, c.stat(@file).mode)
      end
    end

    run_chmod.call(0654)
    run_chmod.call(0643)
    run_chmod.call(0777)
  end

  def test_chmod_file
    @client.write(@file, '')

    run_chmod = proc do |mode|
      @client.open(@file, 'r') { |f| f.chmod(mode) }
      Qfs::Client.with_client('localhost', 10000) do |c|
        assert_equal(mode, c.stat(@file).mode)
      end
    end

    run_chmod.call(0654)
    run_chmod.call(0643)
    run_chmod.call(0777)
  end

  def test_chmod_recursive
    @client.mkdir(@file, 0777)
    testfile = File.join(@file, 'testfile')
    @client.write(testfile, '')

    run_chmod = proc do |mode|
      @client.chmod(@file, mode, recursive: true)
      assert_equal(mode, @client.stat(@file).mode)
      assert_equal(mode, @client.stat(testfile).mode)
    end

    run_chmod.call(0777)
    run_chmod.call(0766)
    run_chmod.call(0755)

    @client.remove(testfile)
  end

  def test_readdir
    @client.mkdir(@file, 0777)
    files = [0..5].map do
      name = random_data(10)
      @client.write(File.join(@file, name), 'test')
      name
    end

    @client.readdir(@file) { |f| assert_includes(files, f.filename) }

    attrs = @client.readdir(@file)
    attrs.each { |f| assert_includes(files, f.filename) }
  end

  def test_client_read_write
    [0..5].each do
      data = random_data
      @client.write(@file, data)
      assert_equal(data, @client.read(@file))
    end
  end

  def test_rm_rf
    @client.mkdir(@file, 0777)
    data = random_data
    data.length.times do |i|
      args = [@file].concat(data.chars[0..i])
      path = File.send(:join, args)
      @client.mkdir(path, 0777)
      @client.write(File.join(path, 'file'), data)
    end

    @client.rm_rf(@file)
    assert !@client.exists?(@file)
  end

  def test_attr_to_s
    assert_attr = proc do |mode, str|
      @client.write(@file, '')
      @client.chmod(@file, mode)
      assert_equal(str, stat(@file).to_s)
    end

    assert_attr.call(0777, "-rwxrwxrwx #{File.basename(@file)}")
    assert_attr.call(0644, "-rw-r--r-- #{File.basename(@file)}")
    assert_attr.call(0473, "-r--rwx-wx #{File.basename(@file)}")
  end

  def test_client_move
    newpath = get_test_path('new_test_file')
    @client.write(@file, '')

    assert !@client.exists(newpath)
    @client.move(@file, newpath)

    assert !@client.exists(@file)
    assert @client.exists(newpath)

    @client.remove(newpath)
  end

  def test_client_cd
    @client.mkdir(@file)
    @client.cd(@file)

    assert_equal(@file, @client.cwd)

    @client.cd('../')
    assert_equal(BASE_TEST_PATH, @client.cwd)
  end
end
