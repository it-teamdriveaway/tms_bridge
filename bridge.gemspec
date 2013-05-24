# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bridge/version'

Gem::Specification.new do |spec|
  spec.name          = "tms_bridge"
  spec.version       = Bridge::VERSION
  spec.authors       = ["Erich Timkar"]
  spec.email         = ["erich@teamdriveaway.com"]
  spec.description   = %q{Provides parsing and authtentication for publishing into TMS client apps. }
  spec.summary       = ''
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.6"
  spec.add_dependency "actionpack", ">= 3.2.0"
  spec.add_dependency "uuidtools"
  spec.add_dependency "iron_cache"
end
