# frozen_string_literal: true

module Pgoutput
  # Base error for all parser failures.
  #
  # @api public
  class Error < StandardError; end

  # Raised when a payload ends before the requested protocol field can be read.
  #
  # @api public
  class TruncatedMessageError < Error; end

  # Raised when the parser sees a message or tuple tag outside this MVP scope.
  #
  # @api public
  class UnsupportedMessageError < Error; end

  # Raised when row data references a relation id that has not been observed via
  # a preceding Relation (`R`) message in the current stream decoder.
  #
  # @api public
  class UnknownRelationError < Error; end

  # Raised when tuple data does not match the column count advertised by the
  # cached Relation (`R`) message.
  #
  # @api public
  class TupleArityError < Error; end
end
