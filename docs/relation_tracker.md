# RelationTracker Guide

`Pgoutput::RelationTracker` is the stream-order parser wrapper for callers that
want DML tuple values annotated with PostgreSQL type OIDs.

Use `Pgoutput::BinaryParser` when each payload can be decoded independently. Use
`RelationTracker` when Insert, Update, and Delete messages need the Relation
metadata that PostgreSQL sent earlier in the same logical replication stream.

## Why Relation Tracking Exists

pgoutput row-change messages reference a relation ID, but tuple values do not
repeat column names or PostgreSQL type OIDs. PostgreSQL sends that metadata in a
Relation (`R`) message.

The tracker caches Relation messages:

```text
R users(id int4, email text, active bool)
I relation_id=42 tuple=["7", "dev@example.test", "t"]
U relation_id=42 tuple=["7", "ops@example.test", "t"]
D relation_id=42 old_key=["7"]
```

After the Relation message has been seen, later DML tuple values can be
annotated:

```ruby
stream = Pgoutput::RelationTracker.new

stream.process(relation_payload)
insert = stream.process(insert_payload)

insert.tuple.map(&:oid)
# => [23, 25, 16]
```

The raw tuple bytes are unchanged. The tracker only attaches metadata.

## Stream-Order Contract

`RelationTracker` assumes payloads are processed in pgoutput stream order.

This order matters because DML messages depend on earlier Relation messages. If
an Insert, Update, or Delete references a relation ID that has not been cached,
the tracker raises `Pgoutput::UnknownRelationError`.

```ruby
stream = Pgoutput::RelationTracker.new

stream.process(insert_payload)
# raises Pgoutput::UnknownRelationError
```

The tracker does not reorder messages, buffer future DML, deduplicate events, or
validate row lifecycle semantics such as whether an Insert occurred before a
Delete for the same primary key. Those guarantees belong to higher CDC pipeline
layers.

## Tuple Arity Validation

The tracker validates tuple arity before annotating OIDs. If PostgreSQL sends a
tuple with a different number of values than the cached Relation column count,
the tracker raises `Pgoutput::TupleArityError`.

This avoids silently assigning the wrong type OIDs to tuple positions.

```ruby
stream = Pgoutput::RelationTracker.new

stream.process(relation_payload)
stream.process(malformed_insert_payload)
# raises Pgoutput::TupleArityError
```

## Default Relation Cache

By default, each tracker owns a plain Ruby `Hash`:

```ruby
stream = Pgoutput::RelationTracker.new
```

That is the right default for a single stream owner. The tracker instance itself
is mutable and should be scoped to the code path that processes that logical
replication stream.

Parsed message objects returned from `process` are Ractor-shareable. The mutable
tracker is not the shareable value; the parsed messages are.

## Swappable Relation Cache

`RelationTracker` accepts a `relation_cache:` object:

```ruby
stream = Pgoutput::RelationTracker.new(relation_cache: {})
```

The cache object must support:

- `#[]=` for storing Relation messages by relation ID
- `#fetch` for reading Relation messages and raising through the provided block
  when a relation ID is unknown

This keeps `RelationTracker` independent from a specific cache implementation.

## Ratomic::Map Cache

For experimental or parallel Ruby 4 setups, callers can inject
`Ratomic::Map`:

```ruby
require "ratomic"
require "pgoutput"

relation_cache = Ratomic::Map.new
stream = Pgoutput::RelationTracker.new(relation_cache: relation_cache)

stream.process(relation_payload)
insert = stream.process(insert_payload)

insert.tuple.map(&:oid)
# => [23, 25, 16]
```

`Ratomic::Map` is useful when relation metadata must live in a Ractor-safe cache.
This gem keeps Ratomic as an optional development/benchmark dependency rather
than a runtime dependency; applications that want this cache backend should add
Ratomic directly.

Prefer the default Hash unless a pipeline design specifically needs a shared
Ractor-safe relation metadata cache.

## Ractor Pattern

A common pattern is to keep one tracker per stream-processing lane and pass only
parsed immutable messages across Ractors:

```ruby
stream = Pgoutput::RelationTracker.new

stream.process(relation_payload)
message = stream.process(update_payload)

worker = Ractor.new(message) do |event|
  event.new_tuple.map(&:raw)
end

worker.take
```

If relation metadata itself must be shared across lanes, use an explicit
Ractor-safe cache such as `Ratomic::Map` and benchmark the result for the target
workload.

## Boundary

`RelationTracker` is still a parser-layer utility. It does not perform:

- PostgreSQL value decoding
- application-level type conversion
- event ordering across sink workers
- checkpointing
- retry coordination
- row lifecycle validation

Its job is narrow: remember Relation metadata, annotate DML tuple values with
type OIDs, validate tuple arity, and return immutable protocol messages.
