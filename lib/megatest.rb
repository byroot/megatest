# frozen_string_literal: true

require_relative "megatest/version"

module Megatest
  Error = Class.new(StandardError)
  AlreadyDefinedError = Class.new(Error)
  LoadError = Class.new(Error)

  ROOT = -File.expand_path("../", __FILE__)
  PWD = File.join(Dir.pwd, "/")
  IGNORED_ERRORS = [NoMemoryError, SignalException, SystemExit].freeze

  class << self
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

    def load_config(paths)
      load_files(paths, "test_config.rb")
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
      def glob(path)
        Dir.glob(File.join(path, "**/{test_*,*_test}.rb"))
      end
    else
      def glob(path)
        paths = Dir.glob(File.join(path, "**/{test_*,*_test}.rb"))
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
require "megatest/runner"
require "megatest/runtime"
require "megatest/state"
require "megatest/reporters"
require "megatest/queue"
require "megatest/queue_reporter"
require "megatest/executor"
require "megatest/dsl"
require "megatest/test"
