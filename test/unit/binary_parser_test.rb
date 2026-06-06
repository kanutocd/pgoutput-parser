# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/builders"

# rubocop:disable Metrics/ClassLength
class BinaryParserTest < Minitest::Test
  include Builders

  def test_parses_begin
    message = Pgoutput::BinaryParser.new(begin_msg).parse

    assert_instance_of Pgoutput::Messages::Begin, message
    assert_equal 123, message.final_lsn
    assert_equal 456, message.commit_timestamp
    assert_equal 789, message.xid
    assert Ractor.shareable?(message)
  end

  def test_parses_logical_message
    message = Pgoutput::BinaryParser.new(logical_message_msg).parse

    assert_instance_of Pgoutput::Messages::Message, message
    assert_equal 1, message.flags
    assert_equal 999, message.lsn
    assert_equal "audit", message.prefix
    assert_equal "changed", message.content
    assert Ractor.shareable?(message)
  end

  def test_parses_origin
    message = Pgoutput::BinaryParser.new(origin_msg).parse

    assert_instance_of Pgoutput::Messages::Origin, message
    assert_equal 777, message.origin_lsn
    assert_equal "upstream", message.name
    assert Ractor.shareable?(message)
  end

  def test_parses_relation
    message = Pgoutput::BinaryParser.new(relation_msg).parse

    assert_instance_of Pgoutput::Messages::Relation, message
    assert_equal 42, message.relation_id
    assert_equal "public", message.schema
    assert_equal "users", message.table
    assert_equal 100, message.replica_identity
    assert_equal %w[id name active], message.columns.map(&:name)
    assert_equal [23, 25, 16], message.columns.map(&:oid)
    assert Ractor.shareable?(message)
  end

  def test_parses_type
    message = Pgoutput::BinaryParser.new(type_msg).parse

    assert_instance_of Pgoutput::Messages::Type, message
    assert_equal 2950, message.oid
    assert_equal "public", message.schema
    assert_equal "uuid", message.name
    assert Ractor.shareable?(message)
  end

  def test_parses_insert
    message = Pgoutput::BinaryParser.new(insert_msg).parse

    assert_instance_of Pgoutput::Messages::Insert, message
    assert_equal 42, message.relation_id
    assert_equal %i[text text text], message.tuple.map(&:format)
    assert_equal %w[7 Alice t], message.tuple.map(&:raw)
    assert_nil message.tuple.first.oid
    assert Ractor.shareable?(message)
  end

  def test_parses_binary_tuple_values
    message = Pgoutput::BinaryParser.new(insert_binary_msg).parse

    assert_equal :binary, message.tuple.first.format
    assert_equal [7].pack("N"), message.tuple.first.raw
    assert_equal :null, message.tuple.last.format
  end

  def test_parses_update_with_old_key
    message = Pgoutput::BinaryParser.new(update_msg_with_old_key).parse

    assert_instance_of Pgoutput::Messages::Update, message
    assert_equal "7", message.old_key_tuple.first.raw
    assert_nil message.old_tuple
    assert_equal "Bob", message.new_tuple[1].raw
    assert Ractor.shareable?(message)
  end

  def test_parses_update_with_old_tuple
    message = Pgoutput::BinaryParser.new(update_msg_with_old_tuple).parse

    assert_nil message.old_key_tuple
    assert_equal "Alice", message.old_tuple[1].raw
    assert_equal "Bob", message.new_tuple[1].raw
  end

  def test_parses_update_new_only
    message = Pgoutput::BinaryParser.new(update_msg_new_only).parse

    assert_nil message.old_key_tuple
    assert_nil message.old_tuple
    assert_equal "Bob", message.new_tuple[1].raw
  end

  def test_parses_delete_with_key
    message = Pgoutput::BinaryParser.new(delete_msg_with_key).parse

    assert_instance_of Pgoutput::Messages::Delete, message
    assert_equal "7", message.old_key_tuple.first.raw
    assert_nil message.old_tuple
    assert Ractor.shareable?(message)
  end

  def test_parses_delete_with_old_tuple
    message = Pgoutput::BinaryParser.new(delete_msg_with_old_tuple).parse

    assert_nil message.old_key_tuple
    assert_equal "Alice", message.old_tuple[1].raw
  end

  def test_parses_truncate
    message = Pgoutput::BinaryParser.new(truncate_msg).parse

    assert_instance_of Pgoutput::Messages::Truncate, message
    assert_equal [42, 43], message.relation_ids
    assert_equal 3, message.options
    assert Ractor.shareable?(message)
  end

  def test_parses_commit
    message = Pgoutput::BinaryParser.new(commit_msg).parse

    assert_instance_of Pgoutput::Messages::Commit, message
    assert_equal 0, message.flags
    assert_equal 10, message.commit_lsn
    assert_equal 11, message.transaction_end_lsn
    assert_equal 12, message.commit_timestamp
    assert Ractor.shareable?(message)
  end

  def test_rejects_unknown_message_tag
    assert_raises(Pgoutput::UnsupportedMessageError) do
      Pgoutput::BinaryParser.new("Z".b).parse
    end
  end

  def test_rejects_truncated_message
    assert_raises(Pgoutput::TruncatedMessageError) do
      Pgoutput::BinaryParser.new("B\x00".b).parse
    end
  end

  def test_rejects_unterminated_cstring
    payload = "R".b + u32(42) + "public".b

    error = assert_raises(Pgoutput::TruncatedMessageError) do
      Pgoutput::BinaryParser.new(payload).parse
    end

    assert_match(/unterminated cstring/, error.message)
  end

  def test_rejects_negative_byte_length
    payload = "M".b + u8(1) + u64(999) + cstr("audit") + i32(-1)

    error = assert_raises(Pgoutput::TruncatedMessageError) do
      Pgoutput::BinaryParser.new(payload).parse
    end

    assert_match(/negative byte length -1/, error.message)
  end

  def test_rejects_invalid_update_shape
    payload = "U".b + u32(42) + "K".b + key_tuple(id: 7) + "D".b

    assert_raises(Pgoutput::UnsupportedMessageError) do
      Pgoutput::BinaryParser.new(payload).parse
    end
  end

  def test_rejects_invalid_delete_tuple_tag
    payload = "D".b + u32(42) + "N".b + tuple_values(id: 7, name: "Bob")

    assert_raises(Pgoutput::UnsupportedMessageError) do
      Pgoutput::BinaryParser.new(payload).parse
    end
  end
end
# rubocop:enable Metrics/ClassLength
