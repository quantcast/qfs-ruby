require 'qfs/version'
require 'qfs.bundle'
require 'fcntl'

module Qfs

  # supported oflags
  O_CREAT = Fcntl::O_CREAT
  O_EXCL = Fcntl::O_EXCL
  O_RDWR = Fcntl::O_RDWR
  O_RDONLY = Fcntl::O_RDONLY
  O_WRONLY = Fcntl::O_WRONLY
  O_TRUNC = Fcntl::O_TRUNC
  O_APPEND = Fcntl::O_APPEND

  class Client
    def with_file path, oflag=nil, mode=nil, params=nil
      f = self.open path, oflag, mode, params
      begin
        yield f
      ensure
        f.close
      end
    end
    def self.with_client host, port
      c = Client.new host, port
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
