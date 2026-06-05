# frozen_string_literal: true

module Pgoutput
  # Offset-based binary parser for one PostgreSQL pgoutput logical replication
  # message payload.
  #
  # A parser instance is intentionally short-lived and mutable while reading a
  # single payload. Its returned message object is deeply frozen/shareable and may
  # cross Ractor boundaries safely.
  #
  # @api public
  # rubocop:disable Metrics/ClassLength
  class BinaryParser
    # @param payload [String] one pgoutput message payload from a CopyData frame.
    # @return [void]
    def initialize(payload)
      @payload = payload.b
      @offset = 0
    end

    # Parse one supported pgoutput message.
    #
    # Supported MVP tags are `B`, `M`, `O`, `R`, `Y`, `I`, `U`, `D`, `T`, and `C`.
    #
    # @return [Pgoutput::Messages::Begin, Pgoutput::Messages::Relation,
    #   Pgoutput::Messages::Insert, Pgoutput::Messages::Update,
    #   Pgoutput::Messages::Delete, Pgoutput::Messages::Commit]
    # @raise [UnsupportedMessageError] if the message tag is unsupported.
    # @raise [TruncatedMessageError] if the payload is incomplete.
    # rubocop:disable Metrics/CyclomaticComplexity
    def parse
      case read_byte_chr
      when "B" then parse_begin
      when "M" then parse_message
      when "O" then parse_origin
      when "R" then parse_relation
      when "Y" then parse_type
      when "I" then parse_insert
      when "U" then parse_update
      when "D" then parse_delete
      when "T" then parse_truncate
      when "C" then parse_commit
      else
        raise UnsupportedMessageError, "unsupported pgoutput message tag"
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def parse_begin
      share(Messages::Begin.new(read_uint64, read_uint64, read_uint32))
    end

    def parse_message
      flags = read_uint8
      lsn = read_uint64
      prefix = read_cstring
      content = read_bytes(read_int32).freeze

      share(Messages::Message.new(flags, lsn, prefix, content))
    end

    def parse_origin
      share(Messages::Origin.new(read_uint64, read_cstring))
    end

    def parse_relation
      relation_id = read_uint32
      schema = read_cstring
      table = read_cstring
      replica_identity = read_uint8
      column_count = read_uint16

      columns = Array.new(column_count) do
        Messages::Column.new(read_uint8, read_cstring, read_uint32, read_int32)
      end.freeze

      share(Messages::Relation.new(relation_id, schema, table, replica_identity, columns))
    end

    def parse_type
      share(Messages::Type.new(read_uint32, read_cstring, read_cstring))
    end

    def parse_insert
      relation_id = read_uint32
      tuple_tag = read_byte_chr
      raise UnsupportedMessageError, "expected insert tuple tag N, got #{tuple_tag.inspect}" unless tuple_tag == "N"

      share(Messages::Insert.new(relation_id, parse_tuple_data))
    end

    def parse_update
      relation_id = read_uint32
      old_key_tuple = nil
      old_tuple = nil

      first_tag = read_byte_chr
      case first_tag
      when "K"
        old_key_tuple = parse_tuple_data
        new_tag = read_byte_chr
      when "O"
        old_tuple = parse_tuple_data
        new_tag = read_byte_chr
      when "N"
        new_tag = first_tag
      else
        raise UnsupportedMessageError, "expected update tuple tag K, O, or N, got #{first_tag.inspect}"
      end

      raise UnsupportedMessageError, "expected update new tuple tag N, got #{new_tag.inspect}" unless new_tag == "N"

      share(Messages::Update.new(relation_id, old_key_tuple, old_tuple, parse_tuple_data))
    end

    def parse_delete
      relation_id = read_uint32
      tuple_tag = read_byte_chr

      case tuple_tag
      when "K"
        share(Messages::Delete.new(relation_id, parse_tuple_data, nil))
      when "O"
        share(Messages::Delete.new(relation_id, nil, parse_tuple_data))
      else
        raise UnsupportedMessageError, "expected delete tuple tag K or O, got #{tuple_tag.inspect}"
      end
    end

    def parse_truncate
      relation_count = read_uint32
      options = read_uint8
      relation_ids = Array.new(relation_count) { read_uint32 }.freeze

      share(Messages::Truncate.new(relation_ids, options))
    end

    def parse_commit
      share(Messages::Commit.new(read_uint8, read_uint64, read_uint64, read_uint64))
    end

    def parse_tuple_data
      column_count = read_uint16

      Array.new(column_count) do
        tag = read_byte_chr

        case tag
        when "n"
          Messages::TupleValue.new(:null, nil, nil)
        when "u"
          Messages::TupleValue.new(:unchanged_toast, nil, nil)
        when "t", "b"
          raw = read_bytes(read_int32).freeze
          Messages::TupleValue.new(tag == "t" ? :text : :binary, raw, nil)
        else
          raise UnsupportedMessageError, "unsupported tuple data tag: #{tag.inspect}"
        end
      end.freeze
    end

    def read_uint8 = Integer(read_bytes(1).unpack1("C"))

    def read_uint16 = Integer(read_bytes(2).unpack1("n"))

    def read_uint32 = Integer(read_bytes(4).unpack1("N"))

    def read_int32
      value = read_uint32
      value >= 0x8000_0000 ? value - 0x1_0000_0000 : value
    end

    def read_uint64 = Integer(read_bytes(8).unpack1("Q>"))

    def read_byte_chr = read_bytes(1)

    def read_cstring
      zero = @payload.index("\0", @offset)
      raise TruncatedMessageError, "unterminated cstring at offset #{@offset}" unless zero

      value = String(@payload.byteslice(@offset, zero - @offset)).freeze
      @offset = zero + 1
      value
    end

    def read_bytes(length)
      raise TruncatedMessageError, "negative byte length #{length}" if length.negative?
      if @offset + length > @payload.bytesize
        raise TruncatedMessageError, "need #{length} bytes at offset #{@offset}, payload has #{@payload.bytesize} bytes"
      end

      value = String(@payload.byteslice(@offset, length))
      @offset += length
      value
    end

    def share(message)
      Ractor.make_shareable(message)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
