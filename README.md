# ruby-qfs

Ruby bindings for [QFS](https://github.com/quantcast/qfs).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'qfs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install qfs

## Usage

The entrypoint to QFS with these bindings is the `Qfs::Client` object.  You can view the entire API in the documentation (TODO update this when open sourced) and see examples in "test/qfs_test.rb".

## Testing

You can run the tests on an existing instance of QFS.  By default, an local instance running on port 10000 is assumed, but you can specify a different location using environment variables.

```shell
rake test
```

By default, a stock QFS instance will likely have restricted permissions.  You may have to connect to QFS as root and manually chown/chmod the root to something that the user running the tests can access.

#### Environment Variables for Tests
* `QFS_TEST_PATH`: The directory in QFS to create and do all test-related operations in.
* `QFS_TEST_HOST`: The host running QFS.
* `QFS_TEST_PORT`: The port that QFS is running on.

You can also enable debugging output by setting the environment variable `RUBY_QFS_TRACE`.

```shell
export RUBY_QFS_TRACE=1
```
