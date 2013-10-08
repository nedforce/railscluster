# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'railscluster/version'

Gem::Specification.new do |gem|
  gem.name          = "railscluster"
  gem.version       = Railscluster::VERSION
  gem.authors       = ["Arthur Holstvoogd"]
  gem.email         = ["a.holstvoogd@nedforce.nl"]
  gem.description   = %q{Gem to ease deploying to RailsCluster}
  gem.summary       = %q{Gem to ease deploying to RailsCluster}
  gem.homepage      = "http://www.railscluster.nl"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency 'capistrano', '~> 2.15'
  gem.add_dependency 'bundler'
  gem.add_dependency 'thin'
  gem.add_dependency 'airbrake'
  # gem.add_dependency 'rake', '10.1.0'
end
