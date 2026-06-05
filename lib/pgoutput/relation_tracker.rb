# frozen_string_literal: true

module Pgoutput
  # Stateful relation tracker for pgoutput message sequences.
  #
  # The relation tracker remembers Relation (`R`) messages so DML tuple values can
  # be annotated with PostgreSQL type OIDs. It does not decode or convert values.
  # It only adds protocol metadata to tuple values while keeping returned objects
  # deeply shareable.
  #
  # The instance contains mutable relation-cache state and should not be shared
  # across Ractors. Returned message objects are Ractor-safe.
  #
  # @api public
  class RelationTracker
    # @return [void]
    def initialize
      @relations = {}
    end

    # Process one pgoutput payload in stream order.
    #
    # @param payload [String] one pgoutput logical replication message payload.
    # @return [Pgoutput::Messages::Begin, Pgoutput::Messages::Relation,
    #   Pgoutput::Messages::Insert, Pgoutput::Messages::Update,
    #   Pgoutput::Messages::Delete, Pgoutput::Messages::Commit]
    # @raise [UnknownRelationError] if DML references an unseen relation id.
    # @raise [TupleArityError] if DML tuple data does not match relation metadata.
    def process(payload)
      message = BinaryParser.new(payload).parse

      case message
      when Messages::Relation
        @relations[message.relation_id] = message
        message
      when Messages::Insert
        annotate_insert(message)
      when Messages::Update
        annotate_update(message)
      when Messages::Delete
        annotate_delete(message)
      else
        message
      end
    end

    # Backwards-compatible alias for callers migrating from RelationTracker.
    #
    # @param payload [String] one pgoutput logical replication message payload.
    # @return [Pgoutput::Messages::Begin, Pgoutput::Messages::Relation,
    #   Pgoutput::Messages::Insert, Pgoutput::Messages::Update,
    #   Pgoutput::Messages::Delete, Pgoutput::Messages::Commit]
    def decode(payload)
      process(payload)
    end

    private

    def annotate_insert(message)
      relation = relation_for(message.relation_id)

      Ractor.make_shareable(
        Messages::Insert.new(
          message.relation_id,
          annotate_tuple(message.tuple, relation)
        )
      )
    end

    def annotate_update(message)
      relation = relation_for(message.relation_id)

      Ractor.make_shareable(
        Messages::Update.new(
          message.relation_id,
          annotate_tuple(message.old_key_tuple, relation),
          annotate_tuple(message.old_tuple, relation),
          annotate_tuple(message.new_tuple, relation)
        )
      )
    end

    def annotate_delete(message)
      relation = relation_for(message.relation_id)

      Ractor.make_shareable(
        Messages::Delete.new(
          message.relation_id,
          annotate_tuple(message.old_key_tuple, relation),
          annotate_tuple(message.old_tuple, relation)
        )
      )
    end

    def annotate_tuple(tuple, relation)
      return nil if tuple.nil?

      validate_tuple_arity!(tuple, relation)

      tuple.each_with_index.map do |value, index|
        Messages::TupleValue.new(value.format, value.raw, relation.columns.fetch(index).oid)
      end.freeze
    end

    def validate_tuple_arity!(tuple, relation)
      return if tuple.length == relation.columns.length

      raise TupleArityError,
            "tuple has #{tuple.length} values but relation #{relation.relation_id} " \
            "has #{relation.columns.length} columns"
    end

    def relation_for(relation_id)
      @relations.fetch(relation_id) do
        raise UnknownRelationError, "unknown relation id #{relation_id}; parse Relation message first"
      end
    end
  end
end
