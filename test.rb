require 'qfs'

Qfs::Client.with_client 'qfs0.sea1.qc', 10000 do |c|
    c.with_file '/user/eculp/hi.txt' do |f|
        s = f.read(2)
        puts s
    end
    c.readdir '/*' do |e|
        puts e
    end
    #c.intervals '/qfs/results/prod/pipe_v3/mobile/mash/mashEvent' do |i|
        #puts i
    #end
end
