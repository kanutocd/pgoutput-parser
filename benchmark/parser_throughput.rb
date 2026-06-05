# frozen_string_literal: true

require "benchmark"
require "etc"

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

  def logical_message
    content = "changed".b
    "M".b + u8(1) + u64(999) + cstr("audit") + i32(content.bytesize) + content
  end

  def origin = "O".b + u64(777) + cstr("upstream")

  def insert = "I".b + u32(42) + "N".b + tuple_values(id: 7, name: "Alice")

  def type = "Y".b + u32(2950) + cstr("public") + cstr("uuid")

  def update = "U".b + u32(42) + "K".b + key_tuple(id: 7) + "N".b + tuple_values(id: 7, name: "Bob")

  def delete = "D".b + u32(42) + "K".b + key_tuple(id: 7)

  def truncate = "T".b + u32(2) + u8(3) + u32(42) + u32(43)

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

SCENARIOS = %w[
  binary
  tracker_dml
  tracker_mixed
  ractor_binary
  ractor_tracker
].freeze
CACHE_KINDS = %w[hash ratomic].freeze

def env_int(name, default, minimum:)
  value = Integer(ENV.fetch(name, default.to_s))
  raise ArgumentError, "#{name} must be >= #{minimum}" if value < minimum

  value
end

def env_list(name, default, allowed:)
  requested = ENV.fetch(name, default).split(",").map(&:strip)
  return allowed if requested.include?("all")

  unknown = requested - allowed
  raise ArgumentError, "unknown #{name} values: #{unknown.join(", ")}" unless unknown.empty?

  requested
end

def selected_scenarios
  env_list("PGOUTPUT_BENCH_SCENARIOS", "all", allowed: SCENARIOS)
end

ITERATIONS = env_int("PGOUTPUT_BENCH_ITERATIONS", 100_000, minimum: 1)
WARMUP = env_int("PGOUTPUT_BENCH_WARMUP", 1_000, minimum: 0)
RACTORS = env_int("PGOUTPUT_BENCH_RACTORS", [Etc.nprocessors, 2].min, minimum: 1)
SELECTED_SCENARIOS = selected_scenarios.freeze
RELATION_CACHE_KINDS = env_list("PGOUTPUT_BENCH_RELATION_CACHE", "hash", allowed: CACHE_KINDS).freeze

require "ratomic" if RELATION_CACHE_KINDS.include?("ratomic")

def report(label, total, elapsed)
  rate = total / elapsed

  printf(
    "%<label>-28s %<total>10d messages in %<elapsed>7.3fs %<rate>12.0f msg/s\n",
    label: label,
    total: total,
    elapsed: elapsed,
    rate: rate
  )
end

def run_scenario?(name)
  SELECTED_SCENARIOS.include?(name)
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

def relation_cache(kind)
  case kind
  when "hash" then {}
  when "ratomic" then Ratomic::Map.new
  else
    raise ArgumentError, "unknown relation cache kind: #{kind}"
  end
end

def ractor_parse_payloads(payloads, iterations, worker_count)
  workers = Array.new(worker_count) do
    Ractor.new(payloads, iterations) do |worker_payloads, worker_iterations|
      checksum = 0

      worker_iterations.times do
        worker_payloads.each do |payload|
          checksum += Pgoutput::BinaryParser.new(payload).parse.class.name.bytesize
        end
      end

      checksum
    end
  end

  workers.sum { |worker| ractor_value(worker) }
end

def track_payloads(relation_payload, dml_payloads, iterations, cache_kind)
  checksum = 0
  tracker = Pgoutput::RelationTracker.new(relation_cache: relation_cache(cache_kind))
  tracker.process(relation_payload)

  iterations.times do
    dml_payloads.each do |payload|
      checksum += tracker.process(payload).class.name.bytesize
    end
  end

  checksum
end

def ractor_track_payloads(relation_payload, payloads, iterations, worker_count, cache_kind) # rubocop:disable Metrics/AbcSize
  workers = Array.new(worker_count) do
    Ractor.new(relation_payload, payloads, iterations, cache_kind) do |worker_relation,
                                                                        worker_payloads,
                                                                        worker_iterations,
                                                                        worker_cache_kind|
      checksum = 0
      tracker = Pgoutput::RelationTracker.new(relation_cache: relation_cache(worker_cache_kind))
      tracker.process(worker_relation)

      worker_iterations.times do
        worker_payloads.each do |payload|
          checksum += tracker.process(payload).class.name.bytesize
        end
      end

      checksum
    end
  end

  workers.sum { |worker| ractor_value(worker) }
end

def ractor_value(ractor)
  if ractor.respond_to?(:value)
    ractor.value
  else
    ractor.take
  end
end

relation_payload = Payloads.relation
binary_payloads = [
  Payloads.begin_message,
  Payloads.logical_message,
  Payloads.origin,
  relation_payload,
  Payloads.type,
  Payloads.insert,
  Payloads.update,
  Payloads.delete,
  Payloads.truncate,
  Payloads.commit
].freeze
dml_payloads = [Payloads.insert, Payloads.update, Payloads.delete].freeze
tracker_payloads = [
  Payloads.logical_message,
  Payloads.origin,
  Payloads.type,
  Payloads.insert,
  Payloads.update,
  Payloads.delete,
  Payloads.truncate
].freeze

binary_payloads.each(&:freeze)
dml_payloads.each(&:freeze)
tracker_payloads.each(&:freeze)
relation_payload.freeze

shared_binary_payloads = Ractor.make_shareable(binary_payloads)
shared_tracker_payloads = Ractor.make_shareable(tracker_payloads)
shared_relation_payload = Ractor.make_shareable(relation_payload)

parse_payloads(binary_payloads, WARMUP) if run_scenario?("binary")
if run_scenario?("tracker_dml")
  RELATION_CACHE_KINDS.each do |cache_kind|
    track_payloads(relation_payload, dml_payloads, WARMUP, cache_kind)
  end
end
if run_scenario?("tracker_mixed")
  RELATION_CACHE_KINDS.each do |cache_kind|
    track_payloads(relation_payload, tracker_payloads, WARMUP, cache_kind)
  end
end
ractor_parse_payloads(shared_binary_payloads, WARMUP, RACTORS) if run_scenario?("ractor_binary")
if run_scenario?("ractor_tracker")
  RELATION_CACHE_KINDS.each do |cache_kind|
    ractor_track_payloads(shared_relation_payload, shared_tracker_payloads, WARMUP, RACTORS, cache_kind)
  end
end

puts "pgoutput-parser throughput"
puts "iterations=#{ITERATIONS} warmup=#{WARMUP} ractors=#{RACTORS} " \
     "scenarios=#{SELECTED_SCENARIOS.join(",")} relation_cache=#{RELATION_CACHE_KINDS.join(",")} ruby=#{RUBY_VERSION}"

if run_scenario?("binary")
  binary_elapsed = Benchmark.realtime { parse_payloads(binary_payloads, ITERATIONS) }
  report("BinaryParser", binary_payloads.length * ITERATIONS, binary_elapsed)
end

if run_scenario?("tracker_dml")
  RELATION_CACHE_KINDS.each do |cache_kind|
    tracker_elapsed = Benchmark.realtime { track_payloads(relation_payload, dml_payloads, ITERATIONS, cache_kind) }
    report("RelationTracker DML #{cache_kind}", dml_payloads.length * ITERATIONS, tracker_elapsed)
  end
end

if run_scenario?("tracker_mixed")
  RELATION_CACHE_KINDS.each do |cache_kind|
    tracker_all_elapsed = Benchmark.realtime do
      track_payloads(relation_payload, tracker_payloads, ITERATIONS, cache_kind)
    end
    report("RelationTracker #{cache_kind}", tracker_payloads.length * ITERATIONS, tracker_all_elapsed)
  end
end

if run_scenario?("ractor_binary")
  ractor_binary_elapsed = Benchmark.realtime { ractor_parse_payloads(shared_binary_payloads, ITERATIONS, RACTORS) }
  report("Ractor BinaryParser", binary_payloads.length * ITERATIONS * RACTORS, ractor_binary_elapsed)
end

if run_scenario?("ractor_tracker")
  RELATION_CACHE_KINDS.each do |cache_kind|
    ractor_tracker_elapsed = Benchmark.realtime do
      ractor_track_payloads(shared_relation_payload, shared_tracker_payloads, ITERATIONS, RACTORS, cache_kind)
    end
    total = tracker_payloads.length * ITERATIONS * RACTORS
    report("Ractor RelationTracker #{cache_kind}", total, ractor_tracker_elapsed)
  end
end
