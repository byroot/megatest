# frozen_string_literal: true

module Megatest
  module State
    # A test suite is a group of tests. It's a class that inherits Megatest::Test
    class TestSuite
      attr_reader :klass, :test_cases

      def initialize(test_suite)
        @klass = test_suite
        @test_cases = []
      end

      def register_test_case(suite, name, block, source_path, source_line)
        @test_cases << BlockTest.new(suite, name, block, source_path, source_line)
      end
    end

    # A test case is the smaller runable unit, it's a block defined with `test`
    # or a method with a name starting with `test_`.
    class TestCase
      attr_accessor :assertions

      def initialize
        @assertions = 0
      end
    end
  end

  class Registry
    attr_reader :test_suites

    def initialize
      @test_suites = []
    end

    def add_test_suite(test_suite)
      state = State::TestSuite.new(test_suite)
      test_suite.instance_variable_set(:@__mega, state)
      @test_suites << state
    end

    def test_cases
      @test_suites.flat_map(&:test_cases)
    end
  end

  singleton_class.attr_accessor :registry
  self.registry = Registry.new

  class BlockTest
    attr_reader :klass, :name, :block, :source_file, :source_line

    def initialize(klass, name, block, source_file, source_line)
      @klass = klass
      @name = name
      @block = block
      @source_file = source_file
      @source_line = source_line
    end
  end
end
