# frozen_string_literal: true

require "benchmark"

require_relative "../lib/pgoutput"

# Builds representative pgoutput payloads without depending on test fixtures.
module Payloads
  module_function

  def u8(value) = [value].pack("C")
  def u16(value) = [value].pack("n")
  def u32(value) = [value].pack("N")
  def i32(value) = [value & 0xffff_ffff].pack("N")
  def u64(value) = [value].pack("Q>")
  def cstr(value) = "#{value}\0".b

  def relation # rubocop:disable Metrics/AbcSize
    "R".b +
      u32(42) +
      cstr("public") +
      cstr("users") +
      u8(100) +
      u16(3) +
      u8(1) + cstr("id") + u32(23) + i32(-1) +
      u8(0) + cstr("name") + u32(25) + i32(-1) +
      u8(0) + cstr("active") + u32(16) + i32(-1)
  end

  def begin_message = "B".b + u64(123) + u64(456) + u32(789)

  def insert = "I".b + u32(42) + "N".b + tuple_values(id: 7, name: "Alice")

  def update = "U".b + u32(42) + "K".b + key_tuple(id: 7) + "N".b + tuple_values(id: 7, name: "Bob")

  def delete = "D".b + u32(42) + "K".b + key_tuple(id: 7)

  def commit = "C".b + u8(0) + u64(10) + u64(11) + u64(12)

  def tuple_values(id:, name:, active: "t")
    u16(3) +
      text_value(id.to_s) +
      text_value(name) +
      text_value(active)
  end

  def key_tuple(id:)
    u16(3) +
      text_value(id.to_s) +
      null_value +
      unchanged_toast_value
  end

  def text_value(value)
    value = value.b
    "t".b + i32(value.bytesize) + value
  end

  def null_value = "n".b

  def unchanged_toast_value = "u".b
end

ITERATIONS = Integer(ENV.fetch("PGOUTPUT_BENCH_ITERATIONS", "100000"))
WARMUP = Integer(ENV.fetch("PGOUTPUT_BENCH_WARMUP", "1000"))

def report(label, message_count, elapsed)
  total = message_count * ITERATIONS
  rate = total / elapsed

  printf(
    "%<label>-28s %<total>10d messages in %<elapsed>7.3fs %<rate>12.0f msg/s\n",
    label: label,
    total: total,
    elapsed: elapsed,
    rate: rate
  )
end

def parse_payloads(payloads, iterations)
  checksum = 0

  iterations.times do
    payloads.each do |payload|
      checksum += Pgoutput::BinaryParser.new(payload).parse.class.name.bytesize
    end
  end

  checksum
end

def track_payloads(relation_payload, dml_payloads, iterations)
  checksum = 0
  tracker = Pgoutput::RelationTracker.new
  tracker.process(relation_payload)

  iterations.times do
    dml_payloads.each do |payload|
      checksum += tracker.process(payload).class.name.bytesize
    end
  end

  checksum
end

relation_payload = Payloads.relation
binary_payloads = [
  Payloads.begin_message,
  relation_payload,
  Payloads.insert,
  Payloads.update,
  Payloads.delete,
  Payloads.commit
].freeze
dml_payloads = [Payloads.insert, Payloads.update, Payloads.delete].freeze

parse_payloads(binary_payloads, WARMUP)
track_payloads(relation_payload, dml_payloads, WARMUP)

puts "pgoutput-parser throughput"
puts "iterations=#{ITERATIONS} warmup=#{WARMUP} ruby=#{RUBY_VERSION}"

binary_elapsed = Benchmark.realtime { parse_payloads(binary_payloads, ITERATIONS) }
tracker_elapsed = Benchmark.realtime { track_payloads(relation_payload, dml_payloads, ITERATIONS) }

report("BinaryParser", binary_payloads.length, binary_elapsed)
report("RelationTracker cached DML", dml_payloads.length, tracker_elapsed)
