# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'qmore/version'


Gem::Specification.new do |s|
  s.name        = "qmore"
  s.version     = Qmore::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matt Conway"]
  s.email       = ["matt@conwaysplace.com"]
  s.homepage    = ""
  s.summary     = %q{A qless plugin that gives more control over how queues are processed}
  s.description = %q{Qmore allows one to specify the queues a worker processes by the use of wildcards, negations, or dynamic look up from redis.  It also allows one to specify the relative priority between queues (rather than within a single queue).  It plugs into the Qless webapp to make it easy to manage the queues.}

  s.rubyforge_project = "qmore"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("qless", '~> 0.9')
  s.add_dependency("multi_json", '~> 1.7')

  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
  s.add_development_dependency('rack-test')
  # Needed for correct ordering when passing hash params to rack-test
  s.add_development_dependency('orderedhash')

end

