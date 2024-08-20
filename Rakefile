# frozen_string_literal: true

require "bundler/gem_tasks"

require File.expand_path("../lib/megatest/test_task", __FILE__)
Megatest::TestTask.create do |t|
  t.full_backtrace = true
  t.command = "bin/megatest"
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]
