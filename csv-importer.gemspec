# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "csv_importer/version"

Gem::Specification.new do |spec|
  spec.name = "csv-importer"
  spec.version = CSVImporter::VERSION
  spec.authors = ["Philippe Creux", "Marcus Deans"]
  spec.email = ["pcreux@gmail.com"]

  spec.summary = "CSV Import for Humans"
  spec.homepage = "https://github.com/rnwbllabs/csv-importer"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|sorbet)/}) ||
      f.match(%r{\.gem$}) ||
      f.match(%r{^pkg/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "csv", "~> 3.0"
  spec.add_dependency "sorbet-runtime", "~> 0.5"

  spec.add_development_dependency "activemodel", "~> 8.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12.0"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "sorbet", "~> 0.5"
  spec.add_development_dependency "spoom", "~> 1.2"
  spec.add_development_dependency "standard", "~> 1.31"
  spec.add_development_dependency "standard-sorbet", "~> 0.0.2"
  spec.add_development_dependency "tapioca", "~> 0.11"

  spec.required_ruby_version = ">= 3.0"
end
