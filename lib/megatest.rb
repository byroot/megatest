# frozen_string_literal: true

require_relative "megatest/version"

module Megatest
  Error = Class.new(StandardError)
  AlreadyDefinedError = Class.new(Error)

  ROOT = -File.expand_path("../", __FILE__)
  PWD = File.join(Dir.pwd, "/")
  @seed = Random.new(ENV.fetch("SEED", Random.rand(0xFFFF)).to_i)

  class << self
    attr_accessor :seed

    def now
      Process.clock_gettime(Process::CLOCK_REALTIME)
    end

    def relative_path(absolute_path)
      absolute_path&.delete_prefix(PWD)
    end

    def load_config(paths)
      scaned = {}
      paths.each do |path|
        path = File.dirname(path) unless File.directory?(path)

        while path.start_with?(PWD)
          break if scaned[path]

          scaned[path] = true

          config_path = File.join(path, "test_config.rb")
          if File.exist?(config_path)
            require(config_path)
            break
          end

          path = File.dirname(path)
        end
      end
      nil
    end

    def load_suites(argv)
      test_suites = argv.flat_map do |path|
        path = File.expand_path(path)
        stat = File.stat(path)

        if stat.directory?
          Dir.glob(File.join(path, "**/*.rb"))
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

require "megatest/compat"
require "megatest/config"
require "megatest/state"
require "megatest/reporters"
require "megatest/backtrace"
require "megatest/queue"
require "megatest/executor"
require "megatest/dsl"
require "megatest/test"
