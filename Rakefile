# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"
require "yard"

Minitest::TestTask.create(:test) do |task|
  task.libs << "test"
  task.warning = true
  task.test_globs = ["test/**/*_test.rb"]
end

RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ["--parallel"]
end

YARD::Rake::YardocTask.new(:yard) do |task|
  task.files = ["lib/**/*.rb"]
  task.options = ["--protected", "--markup", "markdown", "--readme", "docs/index.md"]
end

desc "Run parser throughput benchmark"
task :benchmark do
  ruby "benchmark/parser_throughput.rb"
end

task default: %i[test rubocop yard]
