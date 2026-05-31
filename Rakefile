# frozen_string_literal: true

require "rubocop/rake_task"
require "yard"

# Define the RuboCop task (creates `rake rubocop`)
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ["--parallel"] # Optional: speeds up execution
end

# Define the YARD task (creates `rake yard`)
YARD::Rake::YardocTask.new(:yard) do |task|
  task.files   = ["lib/**/*.rb"] # Optional: specify files to document
  task.options = ["--protected"] # Optional: include protected methods
end

# Set the default task to run both rubocop and yard
task default: %i[test rubocop yard]

task release: :default
