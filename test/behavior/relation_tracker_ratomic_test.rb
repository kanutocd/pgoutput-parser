# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/builders"
require "ratomic"

class RelationTrackerRatomicTest < Minitest::Test
  include Builders

  def test_relation_cache_can_be_backed_by_ratomic_map
    decoder = Pgoutput::RelationTracker.new(relation_cache: Ratomic::Map.new)

    relation = decoder.decode(relation_msg)
    insert = decoder.decode(insert_msg)

    assert_equal "users", relation.table
    assert_equal [23, 25, 16], insert.tuple.map(&:oid)
    assert Ractor.shareable?(relation)
    assert Ractor.shareable?(insert)
  end
end
