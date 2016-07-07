require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rake/testtask'

spec = Gem::Specification.load('qfs.gemspec')

Rake::ExtensionTask.new do |ext|
  ext.name = 'qfs_ext'
  ext.gem_spec = spec
  ext.ext_dir = 'ext/qfs'
end

desc 'Run the test suite against a local instance of QFS'
Rake::TestTask.new test: :compile do |t|
  t.pattern = 'test/*_test.rb'
  t.libs << 'test'
end

task default: :test
