# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scalebar/version'

Gem::Specification.new do |spec|
  spec.name          = "scalebar"
  spec.version       = Scalebar::VERSION
  spec.authors       = ["Yusuke Yachi"]
  spec.email         = ["yyachi@misasa.okayama-u.ac.jp"]
  spec.summary       = %q{Scalebar generator for image created by JEOL JSM-7001F}
  spec.description   = %q{Put scalebar on image created by JEOL JSM-7001F.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.1"  

  spec.add_dependency "optimist", "~> 3.0"
  spec.add_dependency "dimensions", "~> 1.3"  
end
