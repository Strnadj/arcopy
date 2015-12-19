# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'arcopy/version'

Gem::Specification.new do |spec|
  spec.name          = 'arcopy'
  spec.version       = Arcopy::Version::STRING
  spec.authors       = ['Strnadj', 'Michael Siebert']
  spec.email         = ['jan.strnadek@gmail.com', 'siebertm85@googlemail.com']

  spec.summary       = 'copy data from one dbms to another via active_record'
  spec.description   = 'Copy data from one dbms to another via active_record and activerecord import.'
  spec.homepage      = 'https://github.com/Strnadj/arcopy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord-import', '~> 0.10.0'
  spec.add_dependency 'ruby-progressbar', '~> 1.7', '>= 1.7.5'
  spec.add_dependency 'colorize', '~> 0.7.7'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 0'
  spec.add_development_dependency 'pry', '~> 0'
end
