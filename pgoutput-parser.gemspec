# frozen_string_literal: true

require_relative "lib/pgoutput/version"

Gem::Specification.new do |spec|
  spec.name = "pgoutput-parser"
  spec.version = Pgoutput::VERSION
  spec.authors = ["Ken C. Demanawa"]
  spec.email = ["kenneth.c.demanawa@gmail.com"]

  spec.summary = "Ractor-safe PostgreSQL pgoutput logical replication protocol parser."
  spec.description = "A pure Ruby parser for PostgreSQL pgoutput logical replication CopyData payloads."
  spec.homepage = "https://github.com/kanutocd/pgoutput-parser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/kanutocd/pgoutput-parser/blob/main/CHANGELOG.md"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "docs/**/*.md",
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]
end
