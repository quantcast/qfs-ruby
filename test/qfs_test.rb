require 'minitest/autorun'
require 'qfs'

class TestQfs < Minitest::Test
  def initialize(name = nil)
    @test_name = name
    super(name) unless name.nil?
  end

  def setup
    @client = Qfs::Client.new 'qfs0.sea1.qc', 10000
    @file = get_test_path(@test_name)
  end

  def get_test_path(p)
    File.join('/user/ngoldman/test', p)
  end

  def random_data(len = 20)
    (0...len).map { (65 + rand(26)).chr }.join
  end

  def test_open
    data = random_data
    @client.open(@file, 'w+') do |f|
      f.write(data)
    end
    @client.open(@file, 'r') do |f|
      assert_equal(data, f.read(data.length))
    end
  end

  def test_tell
  end

  def test_remove
    @client.open(@file, 'w') do |f|
      f.write('');
    end
    res = @client.remove(@file)
    assert !@client.exists?(@file)
    assert_equal(1, res)

    assert_raises(Qfs::Error) { @client.remove(@file) }
  end

  def test_exists
    @client.open(@file, 'w') do |f|
      f.write('')
    end
    assert @client.exists?(@file)

    @client.remove(@file)
    assert !@client.exists?(@file)
  end

  def teardown
    @client.remove(@file) if @client.exists?(@file)
    @client.release
  end
end
