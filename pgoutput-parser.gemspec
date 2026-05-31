# frozen_string_literal: true

require_relative "lib/pgoutput/version"

Gem::Specification.new do |spec|
  spec.name = "pgoutput-parser"
  spec.version = Pgoutput::VERSION
  spec.authors = ["Ken C. Demanawa"]
  spec.email = []

  spec.summary = "Ractor-safe PostgreSQL pgoutput logical replication protocol parser."
  spec.description = "A pure Ruby parser for PostgreSQL pgoutput logical replication CopyData payloads."
  spec.homepage = "https://github.com/kanutocd/pgoutput-parser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "pry", "~> 0.16.0"
  spec.add_development_dependency "minitest", "~> 5.27"
  spec.add_development_dependency "rake", "~> 13.4"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "steep", "~> 1.10"
  spec.add_development_dependency "yard", "~> 0.9.44"
end
