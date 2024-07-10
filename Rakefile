# frozen_string_literal: true

require "bundler/gem_tasks"

task :test do
  sh "exe/megatest", "--backtrace", "test"
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]
