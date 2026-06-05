# frozen_string_literal: true

module Builders
  module_function

  def u8(value) = [value].pack("C")
  def u16(value) = [value].pack("n")
  def u32(value) = [value].pack("N")
  def i32(value) = [value & 0xffff_ffff].pack("N")
  def u64(value) = [value].pack("Q>")
  def cstr(value) = "#{value}\0".b

  def begin_msg(lsn: 123, timestamp: 456, xid: 789)
    "B".b + u64(lsn) + u64(timestamp) + u32(xid)
  end

  def logical_message_msg(flags: 1, lsn: 999, prefix: "audit", content: "changed")
    content = content.b
    "M".b + u8(flags) + u64(lsn) + cstr(prefix) + i32(content.bytesize) + content
  end

  def origin_msg(lsn: 777, name: "upstream")
    "O".b + u64(lsn) + cstr(name)
  end

  def relation_msg
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

  def type_msg
    "Y".b + u32(2950) + cstr("public") + cstr("uuid")
  end

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

  def binary_tuple
    u16(3) +
      binary_value([7].pack("N")) +
      text_value("Alice") +
      null_value
  end

  def insert_msg
    "I".b + u32(42) + "N".b + tuple_values(id: 7, name: "Alice")
  end

  def insert_binary_msg
    "I".b + u32(42) + "N".b + binary_tuple
  end

  def update_msg_with_old_key
    "U".b + u32(42) + "K".b + key_tuple(id: 7) + "N".b + tuple_values(id: 7, name: "Bob")
  end

  def update_msg_with_old_tuple
    "U".b + u32(42) + "O".b + tuple_values(id: 7, name: "Alice") + "N".b + tuple_values(id: 7, name: "Bob")
  end

  def update_msg_new_only
    "U".b + u32(42) + "N".b + tuple_values(id: 7, name: "Bob")
  end

  def delete_msg_with_key
    "D".b + u32(42) + "K".b + key_tuple(id: 7)
  end

  def delete_msg_with_old_tuple
    "D".b + u32(42) + "O".b + tuple_values(id: 7, name: "Alice")
  end

  def truncate_msg
    "T".b + u32(2) + u8(3) + u32(42) + u32(43)
  end

  def commit_msg
    "C".b + u8(0) + u64(10) + u64(11) + u64(12)
  end

  def text_value(value)
    value = value.b
    "t".b + i32(value.bytesize) + value
  end

  def binary_value(value)
    value = value.b
    "b".b + i32(value.bytesize) + value
  end

  def null_value = "n".b

  def unchanged_toast_value = "u".b
end
