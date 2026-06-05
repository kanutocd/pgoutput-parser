# frozen_string_literal: true

module Pgoutput
  # Immutable message model classes for the PostgreSQL pgoutput protocol.
  #
  # Every value returned by the parser is deeply shareable via
  # `Ractor.make_shareable`. These classes are protocol-level structures only;
  # they preserve tuple bytes and metadata but do not convert PostgreSQL values
  # into application-specific Ruby types.
  #
  # @api public
  module Messages
    # Transaction begin message.
    #
    # @!attribute [r] final_lsn
    #   @return [Integer] final transaction LSN.
    # @!attribute [r] commit_timestamp
    #   @return [Integer] microseconds since PostgreSQL epoch.
    # @!attribute [r] xid
    #   @return [Integer] transaction id.
    Begin = Data.define(:final_lsn, :commit_timestamp, :xid)

    # Logical decoding message.
    #
    # @!attribute [r] flags
    #   @return [Integer] message flags; bit 0 marks transactional messages.
    # @!attribute [r] lsn
    #   @return [Integer] LSN of the logical decoding message.
    # @!attribute [r] prefix
    #   @return [String] message prefix.
    # @!attribute [r] content
    #   @return [String] immutable raw message content.
    Message = Data.define(:flags, :lsn, :prefix, :content)

    # Replication origin message.
    #
    # @!attribute [r] origin_lsn
    #   @return [Integer] commit LSN on the origin server.
    # @!attribute [r] name
    #   @return [String] origin name.
    Origin = Data.define(:origin_lsn, :name)

    # Relation column metadata.
    #
    # @!attribute [r] flags
    #   @return [Integer] column flags; key columns use flag 1.
    # @!attribute [r] name
    #   @return [String] column name.
    # @!attribute [r] oid
    #   @return [Integer] PostgreSQL type OID.
    # @!attribute [r] type_modifier
    #   @return [Integer] PostgreSQL type modifier.
    Column = Data.define(:flags, :name, :oid, :type_modifier)

    # Relation metadata message.
    #
    # @!attribute [r] relation_id
    #   @return [Integer] relation OID used by later DML messages.
    # @!attribute [r] schema
    #   @return [String] namespace name.
    # @!attribute [r] table
    #   @return [String] relation name.
    # @!attribute [r] replica_identity
    #   @return [Integer] relation replica identity setting.
    # @!attribute [r] columns
    #   @return [Array<Column>] immutable column metadata.
    Relation = Data.define(:relation_id, :schema, :table, :replica_identity, :columns)

    # PostgreSQL type metadata message.
    #
    # @!attribute [r] oid
    #   @return [Integer] PostgreSQL type OID.
    # @!attribute [r] schema
    #   @return [String] namespace name.
    # @!attribute [r] name
    #   @return [String] type name.
    Type = Data.define(:oid, :schema, :name)

    # One tuple column value.
    #
    # @!attribute [r] format
    #   @return [:null, :unchanged_toast, :text, :binary] protocol value format.
    # @!attribute [r] raw
    #   @return [String, nil] immutable raw payload, or nil for NULL/TOAST markers.
    # @!attribute [r] oid
    #   @return [Integer, nil] PostgreSQL type OID when relation metadata is known.
    TupleValue = Data.define(:format, :raw, :oid)

    # Insert DML message.
    #
    # @!attribute [r] relation_id
    #   @return [Integer] relation OID.
    # @!attribute [r] tuple
    #   @return [Array<TupleValue>] new tuple data.
    Insert = Data.define(:relation_id, :tuple)

    # Update DML message.
    #
    # The message may contain either an old key tuple, an old full tuple, or
    # neither; it always contains a new tuple.
    #
    # @!attribute [r] relation_id
    #   @return [Integer] relation OID.
    # @!attribute [r] old_key_tuple
    #   @return [Array<TupleValue>, nil] replica identity key tuple.
    # @!attribute [r] old_tuple
    #   @return [Array<TupleValue>, nil] full old tuple when replica identity is FULL.
    # @!attribute [r] new_tuple
    #   @return [Array<TupleValue>] new tuple data.
    Update = Data.define(:relation_id, :old_key_tuple, :old_tuple, :new_tuple)

    # Delete DML message.
    #
    # The message contains either an old key tuple or an old full tuple.
    #
    # @!attribute [r] relation_id
    #   @return [Integer] relation OID.
    # @!attribute [r] old_key_tuple
    #   @return [Array<TupleValue>, nil] replica identity key tuple.
    # @!attribute [r] old_tuple
    #   @return [Array<TupleValue>, nil] full old tuple when replica identity is FULL.
    Delete = Data.define(:relation_id, :old_key_tuple, :old_tuple)

    # Truncate DML message.
    #
    # @!attribute [r] relation_ids
    #   @return [Array<Integer>] relation OIDs affected by the truncate.
    # @!attribute [r] options
    #   @return [Integer] option bits; 1 is CASCADE, 2 is RESTART IDENTITY.
    Truncate = Data.define(:relation_ids, :options)

    # Transaction commit message.
    #
    # @!attribute [r] flags
    #   @return [Integer] commit flags; currently unused by PostgreSQL.
    # @!attribute [r] commit_lsn
    #   @return [Integer] commit LSN.
    # @!attribute [r] transaction_end_lsn
    #   @return [Integer] transaction end LSN.
    # @!attribute [r] commit_timestamp
    #   @return [Integer] microseconds since PostgreSQL epoch.
    Commit = Data.define(:flags, :commit_lsn, :transaction_end_lsn, :commit_timestamp)
  end
end
