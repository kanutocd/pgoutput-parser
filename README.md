# pgoutput-parser

A high-performance, Ractor-safe PostgreSQL `pgoutput` logical replication protocol parser written in pure Ruby.

`pgoutput-parser` parses PostgreSQL logical replication `CopyData` payloads into immutable protocol message objects. It focuses on the `pgoutput` wire format: transaction boundaries, relation metadata, DML message structure, tuple payload markers, and raw tuple bytes.

It intentionally does **not** convert PostgreSQL values into application-specific Ruby objects. That belongs to a higher-level decoder layer, such as a future `pgoutput-decoder` gem.

---

## Requirements

- Ruby 4+
- PostgreSQL 10+

---

## Features

- Pure Ruby implementation
- Ruby 4+
- Ractor-safe parsed messages
- Immutable protocol message objects
- PostgreSQL logical replication protocol support
- Relation metadata tracking
- Binary-safe tuple parsing
- RBS type signatures included
- YARD documentation included
- No runtime dependencies

The generated documentation also includes a project glossary:
[docs/glossary.md](docs/glossary.md).

---

## Why Another pgoutput Library?

This gem focuses exclusively on protocol parsing.

It intentionally separates:

- Protocol parsing (`pgoutput-parser`)
- Type decoding (`pgoutput-decoder`)
- Replication transport/client management

This keeps the parser small, predictable, dependency-free, and faithful to PostgreSQL's wire format.

---

## Supported MVP Scope

Supports the core non-streaming pgoutput logical replication messages:

- Begin (`B`)
- Message (`M`)
- Origin (`O`)
- Relation (`R`)
- Type (`Y`)
- Insert (`I`)
- Update (`U`)
- Delete (`D`)
- Truncate (`T`)
- Commit (`C`)

The currently supported message formats are stable across PostgreSQL 10 through PostgreSQL 18.

TupleData supports all base column markers:

| Tuple Value Tag | Meaning                    |
| --------------- | -------------------------- |
| `n`             | NULL                       |
| `u`             | Unchanged TOAST value      |
| `t`             | Text-formatted raw value   |
| `b`             | Binary-formatted raw value |

### Planned Support

Future releases may add support for:

- Stream Start (`S`)
- Stream Stop (`E`)
- Stream Commit (`c`)
- Stream Abort (`A`)
- Two-Phase Commit messages

---

## What This Gem Does

```text
PostgreSQL CopyData payload
           │
           ▼
    pgoutput-parser
           │
           ▼
Immutable protocol messages
```

The parser understands:

- Message tags and binary field sizes
- Transaction begin metadata
- Transaction commit metadata
- Relation metadata
- Column flags
- Column names
- PostgreSQL type OIDs
- PostgreSQL type modifiers
- Insert tuples
- Update old-key tuples
- Update old full tuples
- Update new tuples
- Delete old-key tuples
- Delete old full tuples
- Tuple value markers (`n`, `u`, `t`, `b`)

---

## What This Gem Does Not Do

The parser does not perform application-level type decoding.

It does not convert:

- UUID
- JSONB
- Timestamp
- Numeric
- Array
- Range
- PostGIS
- Custom PostgreSQL types

Example:

```ruby
value.raw
# => "2026-05-31 12:34:56+00"
```

The raw value is preserved exactly as received.

A higher-level decoder may later interpret it.

---

## Non-goals

This project intentionally does not:

- Manage replication slots
- Open replication connections
- Maintain WAL positions
- Reconnect to PostgreSQL
- Decode PostgreSQL types
- Integrate with ActiveRecord
- Publish events
- Build CDC pipelines

Its sole responsibility is parsing pgoutput protocol messages.

---

## Installation

Add this line to your Gemfile:

```ruby
gem "pgoutput-parser"
```

Then run:

```bash
bundle install
```

Require the library:

```ruby
require "pgoutput"
```

---

## Quick Start

```ruby
require "pgoutput"

stream = Pgoutput::RelationTracker.new

stream.process(relation_payload)

insert = stream.process(insert_payload)

insert.relation_id
# => 42

insert.tuple.first.raw
# => "7"

insert.tuple.first.oid
# => 23
```

---

## Binary Tuple Values

When PostgreSQL publishes tuple values using binary format (`b`), the parser preserves the raw bytes exactly as received.

```ruby
value.raw
# => "\x00\x00\x00\x07".b
```

The parser does not interpret binary values.

---

## Update Messages

PostgreSQL `Update` messages may contain:

- No old tuple
- An old key tuple (`K`)
- An old full tuple (`O`)

They always contain a new tuple (`N`).

```ruby
update = stream.process(update_payload)

update.old_key_tuple
# => [Pgoutput::Messages::TupleValue, ...] or nil

update.old_tuple
# => [Pgoutput::Messages::TupleValue, ...] or nil

update.new_tuple
# => [Pgoutput::Messages::TupleValue, ...]
```

### Update Tuple Example

```ruby
update = stream.process(update_payload)

update.old_key_tuple
update.old_tuple
update.new_tuple
```

---

## Delete Messages

PostgreSQL `Delete` messages contain either:

- An old key tuple (`K`)
- An old full tuple (`O`)

```ruby
delete = stream.process(delete_payload)

delete.old_key_tuple
# => [Pgoutput::Messages::TupleValue, ...] or nil

delete.old_tuple
# => [Pgoutput::Messages::TupleValue, ...] or nil
```

---

## Relation Metadata Tracking

`RelationTracker` keeps a local relation cache so tuple values can be associated with PostgreSQL column OIDs defined by preceding Relation (`R`) messages.

The tracker accepts an optional `relation_cache:` argument. The default is a
plain Hash, but callers can inject `Ratomic::Map` for a Ractor-safe cache in
experimental or parallel setups.

For a deeper guide, including stream-order behavior, tuple arity validation, and
`Ratomic::Map` usage, see [docs/relation_tracker.md](docs/relation_tracker.md).

No type conversion is performed.

Only protocol metadata is attached.

```ruby
stream.process(relation_payload)

message = stream.process(update_payload)

message.new_tuple.map(&:oid)
# => [23, 25, 16]
```

The relation tracker itself is stateful and maintains relation metadata encountered in the replication stream.

If a DML tuple's value count does not match the cached relation column count, `RelationTracker` raises
`Pgoutput::TupleArityError`. This keeps malformed payloads or mismatched stream state from being silently
annotated with incomplete column metadata.

---

## Ractor Safety

```ruby
message = stream.process(update_payload)

Ractor.shareable?(message)
# => true
```

Passing parsed messages to a Ractor:

```ruby
message = stream.process(update_payload)

result = Ractor.new(message) do |update|
  update.new_tuple.map(&:raw)
end.take
```

---

## Architecture

```text
PostgreSQL
      │
      ▼
CopyData payload
      │
      ▼
Pgoutput::BinaryParser
      │
      ▼
Parsed protocol message
      │
      ▼
Pgoutput::RelationTracker
      │
      ▼
Protocol message with relation metadata
      │
      ▼
Ractor-safe protocol message
```

---

## Public API

### Pgoutput::BinaryParser

Parses a single pgoutput payload without stream state.

```ruby
message = Pgoutput::BinaryParser.new(payload).parse
```

### Pgoutput::RelationTracker

Parses messages in stream order and remembers relation metadata.

```ruby
stream = Pgoutput::RelationTracker.new

stream.process(relation_payload)

message = stream.process(insert_payload)
```

### Optional Usage

`RelationTracker` is optional.

If relation metadata tracking is not required, payloads can be parsed directly:

```ruby
message =
  Pgoutput::BinaryParser
    .new(payload)
    .parse
```

---

## RelationTracker Lifecycle

A `RelationTracker` should be created per logical replication stream.

```ruby
stream = Pgoutput::RelationTracker.new
```

The tracker maintains relation metadata discovered during the stream and therefore should not be reused across unrelated replication sessions.

---

## Message Classes

```ruby
Pgoutput::Messages::Begin
Pgoutput::Messages::Message
Pgoutput::Messages::Origin
Pgoutput::Messages::Relation
Pgoutput::Messages::Type
Pgoutput::Messages::Column
Pgoutput::Messages::TupleValue
Pgoutput::Messages::Insert
Pgoutput::Messages::Update
Pgoutput::Messages::Delete
Pgoutput::Messages::Truncate
Pgoutput::Messages::Commit
```

---

## Type Signatures

RBS signatures are included:

```text
sig/pgoutput.rbs
```

Run Steep:

```bash
bundle exec steep check
```

---

## Testing

Run all tests:

```bash
bundle exec rake test
```

Run with coverage:

```bash
COVERAGE=true bundle exec rake test
```

---

## Benchmarking

Run the parser throughput benchmark:

```bash
ruby benchmark/parser_throughput.rb
```

The benchmark reports single-process parser throughput, relation-tracker throughput, and Ractor-parallel throughput. It is intended to show both the single-thread baseline and the Ruby 4 Ractor path this parser is designed to support. Relation-tracker scenarios can also compare the default Hash relation cache with an optional `Ratomic::Map` cache.

Tune the run with environment variables:

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `PGOUTPUT_BENCH_ITERATIONS` | `100000` | Iterations per selected scenario. |
| `PGOUTPUT_BENCH_WARMUP` | `1000` | Warmup iterations before timing. |
| `PGOUTPUT_BENCH_RACTORS` | `2` or CPU count, whichever is lower | Number of Ractor workers for Ractor scenarios. |
| `PGOUTPUT_BENCH_SCENARIOS` | `all` | Comma-separated scenarios: `binary`, `tracker_dml`, `tracker_mixed`, `ractor_binary`, `ractor_tracker`, or `all`. |
| `PGOUTPUT_BENCH_RELATION_CACHE` | `hash` | Comma-separated relation-cache backends for tracker scenarios: `hash`, `ratomic`, or `all`. |

Examples:

```bash
PGOUTPUT_BENCH_ITERATIONS=10000 ruby benchmark/parser_throughput.rb
PGOUTPUT_BENCH_SCENARIOS=binary,tracker_mixed ruby benchmark/parser_throughput.rb
PGOUTPUT_BENCH_RACTORS=4 PGOUTPUT_BENCH_SCENARIOS=ractor_binary,ractor_tracker ruby benchmark/parser_throughput.rb
PGOUTPUT_BENCH_RELATION_CACHE=all PGOUTPUT_BENCH_SCENARIOS=tracker_mixed,ractor_tracker ruby benchmark/parser_throughput.rb
```

Sample Ruby 4 output:

```text
pgoutput-parser throughput
iterations=1000 warmup=10 ractors=2 scenarios=tracker_mixed,ractor_tracker relation_cache=hash,ratomic ruby=4.0.5
RelationTracker hash               7000 messages in   0.163s        42891 msg/s
RelationTracker ratomic            7000 messages in   0.131s        53579 msg/s
Ractor RelationTracker hash       14000 messages in   0.197s        71097 msg/s
Ractor RelationTracker ratomic      14000 messages in   0.146s        96190 msg/s
```

Interpret the Ractor rows as aggregate throughput across workers. They are not a replacement for the single-process rows; they demonstrate the parser's shareable-message design under parallel execution.

---

## Development

Generate YARD documentation:

```bash
bundle exec yard doc
```

---

## Ecosystem Direction

This gem is the protocol layer.

```text
pgoutput-parser
      │
      ▼
Protocol messages
      │
      ▼
pgoutput-decoder
      │
      ▼
Application objects
```

`pgoutput-parser` should remain small, dependency-free, binary-safe, and faithful to PostgreSQL's wire format.

---

## License

MIT.
