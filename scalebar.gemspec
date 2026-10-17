# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scalebar/version'

Gem::Specification.new do |spec|
  spec.name          = "scalebar"
  spec.version       = Scalebar::VERSION
  spec.authors       = ["Yusuke Yachi"]
  spec.email         = ["yyachi@misasa.okayama-u.ac.jp"]
  spec.summary       = "Generate LaTeX scale bars and grids for microscope images"
  spec.description   = "Generate LaTeX image overlays using JEOL JSM-7001F metadata or an explicit field width or magnification."
  spec.homepage      = "https://github.com/misasa/scalebar"
  spec.license       = "GPL-3.0-or-later"
  spec.required_ruby_version = ">= 2.6.10"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.17", "< 5"
  spec.add_development_dependency "rake", ">= 12.3.3", "< 14"
  spec.add_development_dependency "rspec", "~> 3.13"

  spec.add_dependency "optimist", "~> 3.0"
  spec.add_dependency "dimensions", "~> 1.3"  
end
