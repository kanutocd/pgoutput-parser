# pgoutput-parser

A high-performance, Ractor-safe PostgreSQL `pgoutput` logical replication protocol parser written in pure Ruby.

`pgoutput-parser` parses PostgreSQL logical replication `CopyData` payloads into immutable protocol message objects.

It focuses exclusively on PostgreSQL's `pgoutput` wire format:

* Transaction boundaries
* Relation metadata
* DML message structure
* Tuple payload markers
* Raw tuple values

It intentionally does **not** decode PostgreSQL values into application-level Ruby objects.

That responsibility belongs to higher layers such as:

```text
pgoutput-decoder
```

---

# Architecture

```text
PostgreSQL WAL
       |
       v
CopyData payload
       |
       v
pgoutput-parser
       |
       v
Immutable protocol messages
```

The parser is the protocol layer of the CDC ecosystem.

```text
PostgreSQL
      |
      v
pgoutput-parser
      |
      v
pgoutput-decoder
      |
      v
cdc-core
```

---

# Quick Start

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

# Core Concepts

## BinaryParser

Parses a single `pgoutput` payload.

```ruby
message = Pgoutput::BinaryParser
  .new(payload)
  .parse
```

Use this when stream state is not required.

---

## RelationTracker

Tracks PostgreSQL relation metadata across a replication stream.

```ruby
stream = Pgoutput::RelationTracker.new

stream.process(relation_payload)

message = stream.process(insert_payload)
```

This allows tuple values to be associated with PostgreSQL column OIDs.

If tuple data does not match the cached relation column count, `RelationTracker`
raises `Pgoutput::TupleArityError`.

---

# Supported Messages

Current MVP support:

* Begin (`B`)
* Relation (`R`)
* Insert (`I`)
* Update (`U`)
* Delete (`D`)
* Commit (`C`)

Supported across PostgreSQL 10–18.

---

# Tuple Values

Tuple values are preserved exactly as PostgreSQL sends them.

```ruby
value.raw
# => "2026-05-31 12:34:56+00"
```

No application-level decoding occurs.

---

# Binary Values

Binary tuple values are preserved exactly as received.

```ruby
value.raw
# => "\x00\x00\x00\x07".b
```

The parser does not interpret binary payloads.

---

# Ractor Safety

All parsed protocol messages are immutable and shareable.

```ruby
message = stream.process(update_payload)

Ractor.shareable?(message)
# => true
```

Passing messages across Ractors:

```ruby
message = stream.process(update_payload)

result = Ractor.new(message) do |update|
  update.new_tuple.map(&:raw)
end.take
```

---

# Non-Goals

`pgoutput-parser` intentionally does not:

* Open replication connections
* Manage replication slots
* Track WAL positions
* Reconnect to PostgreSQL
* Decode PostgreSQL values
* Build CDC pipelines
* Integrate with ActiveRecord

Its sole responsibility is protocol parsing.

---

# Public API

See the generated API documentation for:

* `Pgoutput::BinaryParser`
* `Pgoutput::RelationTracker`
* `Pgoutput::Messages::*`

---

# Development

Generate documentation:

```bash
bundle exec yard doc
```

Run tests:

```bash
bundle exec rake test
```

Run coverage:

```bash
COVERAGE=true bundle exec rake test
```

Run Steep:

```bash
bundle exec steep check
```

---

# License

MIT
