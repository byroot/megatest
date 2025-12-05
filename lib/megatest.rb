# frozen_string_literal: true

require_relative "megatest/version"

module Megatest
  Error = Class.new(StandardError)
  AlreadyDefinedError = Class.new(Error)
  LoadError = Class.new(Error)

  # :stopdoc:

  ROOT = -File.expand_path("../", __FILE__)
  PWD = File.join(Dir.pwd, "/")
  IGNORED_ERRORS = [NoMemoryError, SignalException, SystemExit].freeze
  DEFAULT_TEST_GLOB = "**/{test_*,*_test}.rb"

  class << self
    def fork?
      Process.respond_to?(:fork) && !ENV["NO_FORK"]
    end

    def now
      Process.clock_gettime(Process::CLOCK_REALTIME)
    end

    def relative_path(absolute_path)
      absolute_path&.delete_prefix(PWD)
    end

    def append_load_path(config)
      config.load_paths.each do |path|
        abs_path = File.absolute_path(path)
        $LOAD_PATH.unshift(abs_path) unless $LOAD_PATH.include?(abs_path)
      end
    end

    def init(config)
      if config.deprecations && ::Warning.respond_to?(:[]=)
        ::Warning[:deprecated] = true
      end

      # We initialize the seed in case there is some Random use
      # at code loading time.
      Random.srand(config.seed)
    end

    def load_tests(config, paths = nil)
      registry = with_registry do
        append_load_path(config)
        load_test_helper(config.selectors.main_paths)

        paths ||= config.selectors.paths(random: config.random)
        paths.each do |path|
          Kernel.require(path)
        rescue LoadError
          raise InvalidArgument, "Failed to load #{relative_path(path)}"
        end
      end

      config.selectors.select(registry, random: config.random)
    end

    def load_config(config)
      load_files(config.selectors.main_paths, "test_config.rb")
    end

    def load_test_helper(paths)
      load_files(paths, "test_helper.rb")
    end

    def load_files(paths, name)
      scaned = {}
      paths.each do |path|
        path = File.dirname(path) unless File.directory?(path)

        while path.start_with?(PWD)
          break if scaned[path]

          scaned[path] = true

          config_path = File.join(path, name)
          if File.exist?(config_path)
            require(config_path)
            break
          end

          path = File.dirname(path)
        end
      end
      nil
    end

    if Dir.method(:glob).parameters.include?(%i(key sort)) # Ruby 2.7+
      def glob(pattern)
        Dir.glob(pattern)
      end
    else
      def glob(pattern)
        paths = Dir.glob(pattern)
        paths.sort!
        paths
      end
    end
  end
end

require "megatest/compat"
require "megatest/patience_diff"
require "megatest/differ"
require "megatest/pretty_print"
require "megatest/output"
require "megatest/backtrace"
require "megatest/config"
require "megatest/selector"
require "megatest/runner"
require "megatest/runtime"
require "megatest/state"
require "megatest/reporters/abstract_reporter"
require "megatest/reporters/simple_reporter"
require "megatest/reporters/verbose_reporter"
require "megatest/reporters/order_reporter"
require "megatest/reporters/j_unit_reporter"
require "megatest/queue"
require "megatest/queue_reporter"
require "megatest/executor"
require "megatest/subprocess"
require "megatest/dsl"
require "megatest/test"
