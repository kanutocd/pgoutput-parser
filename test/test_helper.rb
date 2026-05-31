# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    add_filter "/test/"
  end
end

require "minitest/autorun"
require_relative "../lib/pgoutput"
