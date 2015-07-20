require 'minitest/autorun'
require 'qfs'

class TestQfs < Minitest::Test
    def setup
        @client = Qfs::Client.new 'localhost', 10000
    end

    def test_all
        total = 0
        @client.readdir '/' do |attr|
            total += 1
            assert_equal String, attr.filename.class
            assert_equal String, attr.filename.class
        end
        assert_operator 1, :<, total
        @client.with_file '/qfs-test', Qfs::O_CREAT|Qfs::O_RDWR do |f|
            f.write 'awef'
            assert_equal 'awef', f.read(4)
        end
    end

    def teardown
        @client.release
    end
end
