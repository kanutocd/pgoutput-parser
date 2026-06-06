# Glossary

This glossary defines terms as they are used by `pgoutput-parser`. It focuses on
the protocol parsing layer and avoids application-level decoding concepts that
belong to higher CDC components.

## Binary Value

A tuple value sent by PostgreSQL with the `b` TupleData marker. The parser
preserves the bytes exactly as received and does not interpret the PostgreSQL
binary format.

## BinaryParser

The stateless entry point for parsing one pgoutput message payload. It decodes
the wire-format tag and fields into an immutable `Pgoutput::Messages` object.

## Column Flag

The per-column flag byte in a Relation (`R`) message. PostgreSQL uses flag `1`
to identify replica identity key columns.

## Commit LSN

The PostgreSQL log sequence number associated with a transaction commit. The
parser exposes it as protocol metadata and does not use it for ordering logic.

## CopyData Payload

The PostgreSQL replication protocol frame body that contains one pgoutput
message. This gem expects callers to provide that payload; it does not manage
the PostgreSQL connection or replication stream.

## DML Message

A data manipulation message emitted by pgoutput for row or table changes. In
this parser, DML messages are Insert (`I`), Update (`U`), Delete (`D`), and
Truncate (`T`).

## Immutable Message

A parsed protocol object that has been made shareable with `Ractor`. Parsed
messages can be passed across Ractors without sharing mutable parser state.

## LSN

Log sequence number. PostgreSQL uses LSN values to identify positions in the
write-ahead log. This parser keeps LSN values as integers and does not convert
them into PostgreSQL's textual `X/Y` notation.

## Message Tag

The first byte of a pgoutput payload. It identifies the message type, such as
`R` for Relation, `I` for Insert, or `C` for Commit.

## OID

Object identifier. In this gem, OIDs are most commonly relation IDs and
PostgreSQL type IDs exposed by Relation (`R`) and Type (`Y`) messages.

## pgoutput

PostgreSQL's built-in logical replication output plugin. It serializes
transaction metadata, relation metadata, and row changes into a binary protocol.

## Relation

PostgreSQL table metadata sent by a Relation (`R`) message. It includes the
relation ID, schema name, table name, replica identity setting, and columns.

## RelationTracker

The stream-order parser wrapper that remembers Relation (`R`) messages and uses
them to annotate later DML tuple values with PostgreSQL type OIDs.

## Replica Identity

PostgreSQL metadata that determines what old-row data is available for Update
and Delete messages. The parser exposes the replica identity byte from Relation
messages and preserves old-key or old-full tuples when PostgreSQL sends them.

## Ractor-Safe

Safe to pass between Ruby Ractors. Parsed messages are Ractor-safe; parser and
tracker instances remain mutable and should be scoped to one owner unless the
caller supplies an explicitly Ractor-safe relation cache.

## Ratomic

An optional Ruby library that provides Ractor-oriented concurrent data
structures. `pgoutput-parser` does not require Ratomic at runtime, but benchmark
and development code can use it to evaluate Ractor-safe relation cache behavior.

## Ratomic::Map

A Ractor-safe map implementation from Ratomic. `RelationTracker` can use
`Ratomic::Map` as its `relation_cache:` when callers need relation metadata in a
cache that can be shared across Ractor-oriented execution designs.

## Raw Tuple Value

The uninterpreted bytes for a tuple column value. Text values and binary values
are both kept as raw strings; NULL and unchanged TOAST markers have no raw
payload.

## Text Value

A tuple value sent by PostgreSQL with the `t` TupleData marker. The parser
preserves the text bytes and leaves type conversion to a decoder layer.

## TOAST

PostgreSQL's storage mechanism for large column values. In pgoutput TupleData,
the `u` marker means an unchanged TOAST value was not resent.

## Truncate

A pgoutput DML message that reports table truncation. It contains relation IDs
and option bits such as CASCADE and RESTART IDENTITY.

## Tuple Arity

The number of values in tuple data. `RelationTracker` validates DML tuple arity
against cached Relation column metadata before annotating type OIDs.

## TupleData

The pgoutput structure that carries row values for Insert, Update, and Delete
messages. Each value is marked as NULL, unchanged TOAST, text, or binary.

## Type Decoding

Conversion from PostgreSQL raw tuple bytes into application-level Ruby values.
This gem intentionally does not perform type decoding; that responsibility
belongs to a higher-level decoder component.

## Type Modifier

PostgreSQL column type metadata carried in Relation messages. For example,
typmods can encode precision or length constraints for some PostgreSQL types.

## WAL

Write-ahead log. PostgreSQL logical replication streams changes derived from WAL
through output plugins such as pgoutput.
