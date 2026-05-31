# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/builders"

class RelationTrackerTest < Minitest::Test
  include Builders

  def test_end_to_end_begin_relation_insert_update_delete_commit
    decoder = Pgoutput::RelationTracker.new

    begin_message = decoder.decode(begin_msg)
    relation = decoder.decode(relation_msg)
    insert = decoder.decode(insert_msg)
    update = decoder.decode(update_msg_with_old_key)
    delete = decoder.decode(delete_msg_with_key)
    commit = decoder.decode(commit_msg)

    assert_equal 789, begin_message.xid
    assert_equal "users", relation.table
    assert_equal [23, 25, 16], insert.tuple.map(&:oid)
    assert_equal [23, 25, 16], update.old_key_tuple.map(&:oid)
    assert_equal [23, 25, 16], update.new_tuple.map(&:oid)
    assert_equal [23, 25, 16], delete.old_key_tuple.map(&:oid)
    assert_equal 12, commit.commit_timestamp

    [begin_message, relation, insert, update, delete, commit].each do |message|
      assert Ractor.shareable?(message)
    end
  end

  def test_update_with_full_old_tuple_is_annotated
    decoder = Pgoutput::RelationTracker.new
    decoder.decode(relation_msg)

    update = decoder.decode(update_msg_with_old_tuple)

    assert_equal [23, 25, 16], update.old_tuple.map(&:oid)
    assert_nil update.old_key_tuple
    assert_equal "Alice", update.old_tuple[1].raw
    assert_equal "Bob", update.new_tuple[1].raw
  end

  def test_update_new_only_is_annotated
    decoder = Pgoutput::RelationTracker.new
    decoder.decode(relation_msg)

    update = decoder.decode(update_msg_new_only)

    assert_nil update.old_key_tuple
    assert_nil update.old_tuple
    assert_equal [23, 25, 16], update.new_tuple.map(&:oid)
  end

  def test_delete_with_full_old_tuple_is_annotated
    decoder = Pgoutput::RelationTracker.new
    decoder.decode(relation_msg)

    delete = decoder.decode(delete_msg_with_old_tuple)

    assert_nil delete.old_key_tuple
    assert_equal [23, 25, 16], delete.old_tuple.map(&:oid)
    assert_equal "Alice", delete.old_tuple[1].raw
  end

  def test_insert_before_relation_raises
    decoder = Pgoutput::RelationTracker.new

    assert_raises(Pgoutput::UnknownRelationError) do
      decoder.decode(insert_msg)
    end
  end

  def test_update_before_relation_raises
    decoder = Pgoutput::RelationTracker.new

    assert_raises(Pgoutput::UnknownRelationError) do
      decoder.decode(update_msg_new_only)
    end
  end

  def test_delete_before_relation_raises
    decoder = Pgoutput::RelationTracker.new

    assert_raises(Pgoutput::UnknownRelationError) do
      decoder.decode(delete_msg_with_key)
    end
  end

  def test_ractor_handoff_safety
    decoder = Pgoutput::RelationTracker.new
    decoder.decode(relation_msg)
    update = decoder.decode(update_msg_with_old_key)

    result = Ractor.new(update) do |message|
      [message.old_key_tuple.first.raw, message.new_tuple[1].raw]
    end.take

    assert_equal %w[7 Bob], result
  end
end
