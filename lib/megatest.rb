# frozen_string_literal: true

require_relative "megatest/version"

module Megatest
  @seed = Random.new(ENV.fetch("SEED", Random.rand(0xFFFF)).to_i)

  class << self
    attr_accessor :seed

    def load_suites(argv)
      test_suites = argv.flat_map do |path|
        path = File.expand_path(path)
        stat = File.stat(path)

        if stat.directory?
          Dir.glob(File.join(path, "**/*_test.rb"))
        else
          [path]
        end
      end

      # By default test suites are loaded in a random order
      # to better catch loading order dependencies.
      # The randomness uses the seed so that problems are
      # reproductible
      test_suites.sort!
      test_suites.shuffle!(random: seed)

      test_suites.each do |suite|
        require(suite)
      end
    end
  end
end

require "megatest/state"
require "megatest/reporters"
require "megatest/executor"
require "megatest/test"
