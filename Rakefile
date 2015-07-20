require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rake/testtask'

spec = Gem::Specification.load('qfs.gemspec')
Rake::ExtensionTask.new 'qfs', spec
Rake::TestTask.new test: :compile do |t|
    t.pattern = 'test/*_test.rb'
end
task default: :test
