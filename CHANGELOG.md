# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

* Placeholder for future development.

---

## [0.1.0] - 2026-05-31

### Added

#### Protocol Support

* Added support for PostgreSQL `pgoutput` logical replication protocol parsing.
* Added support for Begin (`B`) messages.
* Added support for Relation (`R`) messages.
* Added support for Insert (`I`) messages.
* Added support for Update (`U`) messages.
* Added support for Delete (`D`) messages.
* Added support for Commit (`C`) messages.
* Added support for TupleData value markers:

  * `n` (NULL)
  * `u` (Unchanged TOAST)
  * `t` (Text)
  * `b` (Binary)

#### Message Models

* Added immutable protocol message classes:

  * `Pgoutput::Messages::Begin`
  * `Pgoutput::Messages::Relation`
  * `Pgoutput::Messages::Column`
  * `Pgoutput::Messages::TupleValue`
  * `Pgoutput::Messages::Insert`
  * `Pgoutput::Messages::Update`
  * `Pgoutput::Messages::Delete`
  * `Pgoutput::Messages::Commit`

#### Parsing Infrastructure

* Added `Pgoutput::BinaryParser`.
* Added offset-based binary parsing implementation.
* Added support for parsing PostgreSQL null-terminated strings.
* Added support for parsing PostgreSQL integer wire types.
* Added protocol validation and truncation detection.
* Added parser error hierarchy.

#### Relation Tracking

* Added `Pgoutput::RelationTracker`.
* Added relation metadata cache.
* Added relation ID to column OID mapping.
* Added tuple annotation with PostgreSQL type OIDs.
* Added validation for unknown relation references.

#### Concurrency

* Added Ractor-safe message generation.
* Added deep-shareable protocol message objects.
* Added immutable arrays and strings throughout parsed outputs.

#### Type System

* Added RBS type signatures.
* Added Steep compatibility.

#### Documentation

* Added YARD documentation coverage for public API.
* Added project README.
* Added architecture documentation.
* Added protocol examples.
* Added Ractor usage examples.

#### Testing

* Added Minitest test suite.
* Added protocol message unit tests.
* Added end-to-end stream integration tests.
* Added Ractor compatibility tests.
* Added binary payload builders for test fixtures.

#### Tooling

* Added Bundler project setup.
* Added GitHub Actions CI workflow.
* Added SimpleCov coverage support.
* Added Rake tasks for development workflows.

### Notes

This release intentionally focuses on protocol parsing only.

The library does not:

* Manage replication connections
* Manage replication slots
* Track WAL positions
* Decode PostgreSQL values into Ruby objects

A future companion project (`pgoutput-decoder`) may provide PostgreSQL type decoding and higher-level row representations.

---

[Unreleased]: https://github.com/your-github-username/pgoutput-parser/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-github-username/pgoutput-parser/releases/tag/v0.1.0

