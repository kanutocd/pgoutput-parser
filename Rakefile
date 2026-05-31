# frozen_string_literal: true

require "rake/testtask"
require "yard"

Rake::TestTask.new(:test) do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
  task.warning = true
end

YARD::Rake::YardocTask.new(:yard)

task default: :test
