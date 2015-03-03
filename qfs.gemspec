# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'qfs/version'

Gem::Specification.new do |spec|
  spec.name          = 'qfs'
  spec.version       = Qfs::VERSION
  spec.authors       = ['Eric Culp']
  spec.email         = ['eculp@quantcast.com']
  spec.summary       = %q{Bindings for QFS}
  spec.description   = %q{Client bindings for Quantcast File System, a distributed filesystem.}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split('\x0')
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'ffi', '~> 1.9'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
end
