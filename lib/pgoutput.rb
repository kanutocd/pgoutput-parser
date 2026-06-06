# frozen_string_literal: true

require_relative "pgoutput/version"
require_relative "pgoutput/errors"
require_relative "pgoutput/messages"
require_relative "pgoutput/binary_parser"
require_relative "pgoutput/relation_tracker"

# Top-level namespace for pgoutput-parser.
#
# pgoutput-parser parses PostgreSQL `pgoutput` logical replication protocol
# payloads into immutable Ruby protocol message objects. The namespace is kept
# short as `Pgoutput`, while the RubyGems package name is `pgoutput-parser`.
#
# @api public Public namespace for parser entry points, message models, and errors.
module Pgoutput
end
