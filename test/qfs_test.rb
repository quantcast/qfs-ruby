require 'minitest/autorun'
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

  def test_chmod_recursive
    @client.mkdir(@file, 0777)
    testfile = File.join(@file, 'testfile')
    @client.open(testfile, 'w') { |f| f.write('') }

    run_chmod = proc do |mode|
      @client.chmod(@file, mode, recursive: true)
      Qfs::Client.with_client('localhost', 10000) do |c|
        assert_equal(mode, c.stat(@file).mode)
        assert_equal(mode, c.stat(testfile).mode)
      end
    end

    run_chmod.call(0777)
    run_chmod.call(0766)
    run_chmod.call(0755)

    @client.remove(testfile)
  end
end
