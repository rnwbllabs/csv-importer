# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "csv_importer/version"

Gem::Specification.new do |spec|
  spec.name = "csv-importer"
  spec.version = CSVImporter::VERSION
  spec.authors = ["Philippe Creux"]
  spec.email = ["pcreux@gmail.com"]

  spec.summary = "CSV Import for humans"
  spec.homepage = "https://github.com/rnwbllabs/csv-importer"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|sorbet)/}) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "csv"
  spec.add_dependency "sorbet-runtime"

  spec.add_development_dependency "activemodel", "~> 8"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.12.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "sorbet"
  spec.add_development_dependency "spoom"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "standard-sorbet"
  spec.add_development_dependency "tapioca"
end
