# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'massive/version'

Gem::Specification.new do |gem|
  gem.name          = "massive"
  gem.version       = Massive::VERSION
  gem.authors       = ["Vicente Mundim"]
  gem.email         = ["vicente.mundim@gmail.com"]
  gem.description   = %q{Parallelize processing of large files and/or data using Resque, Redis and MongoDB}
  gem.summary       = %q{Parallelize processing of large files and/or data using Resque, Redis and MongoDB}

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "resque"
  gem.add_dependency "mongoid", "~> 4.0.0"
  gem.add_dependency "file_processor", "0.2.0"
  gem.add_dependency "active_model_serializers", "~> 0.8.0"
end
