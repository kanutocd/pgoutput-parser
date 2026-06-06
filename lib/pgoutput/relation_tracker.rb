# frozen_string_literal: true

module Pgoutput
  # Stateful relation tracker for pgoutput message sequences.
  #
  # The relation tracker remembers Relation (`R`) messages so DML tuple values can
  # be annotated with PostgreSQL type OIDs. It does not decode or convert values.
  # It only adds protocol metadata to tuple values while keeping returned objects
  # deeply shareable.
  #
  # pgoutput DML messages carry a relation id and tuple values, but they do not
  # repeat column names or type OIDs. PostgreSQL sends that metadata separately
  # in Relation (`R`) messages. Call {#process} with payloads in stream order so
  # Relation messages are cached before the Insert, Update, or Delete messages
  # that reference them.
  #
  # The relation cache is injectable. The default cache is a plain Hash, which is
  # appropriate when one stream owner processes payloads sequentially. Callers
  # with an explicit Ractor-oriented design can supply a compatible cache object,
  # such as `Ratomic::Map`, through the `relation_cache:` keyword.
  #
  # A custom relation cache must implement `#[]=` and `#fetch`. The tracker
  # stores cached Relation messages by relation id and uses `#fetch` with a block
  # so unknown relation ids still raise {UnknownRelationError}.
  #
  # `RelationTracker` does not reorder messages, buffer DML until metadata
  # arrives, enforce per-record lifecycle ordering, or coordinate sink retries.
  # Those guarantees belong to higher CDC pipeline layers. This class only
  # preserves parser-layer stream semantics and validates tuple arity against
  # cached Relation metadata.
  #
  # Returned message objects are Ractor-safe.
  #
  # @example Default Hash-backed relation cache
  #   stream = Pgoutput::RelationTracker.new
  #   stream.process(relation_payload)
  #   insert = stream.process(insert_payload)
  #   insert.tuple.map(&:oid)
  #
  # @example Ractor-safe relation cache with Ratomic::Map
  #   require "ratomic"
  #
  #   relation_cache = Ratomic::Map.new
  #   stream = Pgoutput::RelationTracker.new(relation_cache: relation_cache)
  #   stream.process(relation_payload)
  #   update = stream.process(update_payload)
  #   update.new_tuple.map(&:oid)
  #
  # @api public Public stream-order decoder that annotates DML with relation OIDs.
  class RelationTracker
    # Create a tracker with an optional relation cache.
    #
    # @param relation_cache [Hash, #fetch, #[]=] cache for relation metadata,
    #   keyed by pgoutput relation id. The default Hash is suitable for one
    #   stream owner; callers may inject `Ratomic::Map` or another compatible
    #   cache for explicit Ractor-safe relation metadata sharing.
    # @return [void] initializes an empty tracker using the supplied cache object.
    def initialize(relation_cache: {})
      @relations = relation_cache
    end

    # Process one pgoutput payload in stream order.
    #
    # @param payload [String] one pgoutput logical replication message payload.
    # @return [Pgoutput::Messages::Begin, Pgoutput::Messages::Message,
    #   Pgoutput::Messages::Origin, Pgoutput::Messages::Relation,
    #   Pgoutput::Messages::Type, Pgoutput::Messages::Truncate,
    #   Pgoutput::Messages::Insert, Pgoutput::Messages::Update,
    #   Pgoutput::Messages::Delete, Pgoutput::Messages::Commit] parsed immutable
    #   message object, with DML tuple OIDs annotated when relation metadata exists.
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

    # Backwards-compatible alias for callers migrating to `process`.
    #
    # @param payload [String] one pgoutput logical replication message payload.
    # @return [Pgoutput::Messages::Begin, Pgoutput::Messages::Message,
    #   Pgoutput::Messages::Origin, Pgoutput::Messages::Relation,
    #   Pgoutput::Messages::Type, Pgoutput::Messages::Truncate,
    #   Pgoutput::Messages::Insert, Pgoutput::Messages::Update,
    #   Pgoutput::Messages::Delete, Pgoutput::Messages::Commit] parsed immutable
    #   message object, with DML tuple OIDs annotated when relation metadata exists.
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
          annotate_optional_tuple(message.old_key_tuple, relation),
          annotate_optional_tuple(message.old_tuple, relation),
          annotate_tuple(message.new_tuple, relation)
        )
      )
    end

    def annotate_delete(message)
      relation = relation_for(message.relation_id)

      Ractor.make_shareable(
        Messages::Delete.new(
          message.relation_id,
          annotate_optional_tuple(message.old_key_tuple, relation),
          annotate_optional_tuple(message.old_tuple, relation)
        )
      )
    end

    def annotate_optional_tuple(tuple, relation)
      return nil if tuple.nil?

      annotate_tuple(tuple, relation)
    end

    def annotate_tuple(tuple, relation)
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
