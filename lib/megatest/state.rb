# frozen_string_literal: true

module Megatest
  module State
    # A test suite is a group of tests. It's a class that inherits Megatest::Test
    # A test case is the smaller runable unit, it's a block defined with `test`
    # or a method with a name starting with `test_`.
    class TestSuite
      attr_reader :klass, :test_cases

      def initialize(test_suite)
        @klass = test_suite
        @test_cases = []
      end

      def register_test_case(suite, name, block)
        @test_cases << BlockTest.new(suite, name, block)
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

  class TestCaseResult
    attr_accessor :assertions_count
    attr_reader :failure, :duration

    def initialize(test_case)
      @test_case = test_case
      @assertions_count = 0
      @failure = nil
      @duration = nil
    end

    def test_id
      @test_case.id
    end

    def record
      start_time = now
      begin
        begin
          yield
        rescue Assertion
          raise
        rescue Exception => original_error
          raise UnexpectedError, original_error
        end
      rescue Assertion => assertion
        @failure = assertion
      end
      @duration = now - start_time
      self
    end

    def test_source_location
      if @test_case.source_file
        [@test_case.source_file, @test_case.source_line]
      end
    end

    def status
      if error?
        :error
      elsif failed?
        :failure
      else
        :success
      end
    end

    def failed?
      !@failure.nil?
    end

    def error?
      UnexpectedError === @failure
    end

    private

    def now
      Process.clock_gettime(Process::CLOCK_REALTIME)
    end
  end

  class BlockTest
    attr_reader :id, :klass, :name, :block, :source_file, :source_line

    def initialize(klass, name, block)
      @id = "#{klass.name}##{name}"
      @klass = klass
      @name = name
      @block = block
      @source_file, @source_line = block.source_location
    end

    def <=>(other)
      cmp = @klass.name <=> other.klass.name
      cmp = @name <=> other.name if cmp.zero?
      cmp
    end

    def run
      result = TestCaseResult.new(self)
      instance = klass.new(result)
      result.record do
        instance.instance_exec(&@block)
      end
    end
  end
end
