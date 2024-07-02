# frozen_string_literal: true

module Megatest
  module State
    # A test suite is a group of tests. It's a class that inherits Megatest::Test
    # A test case is the smaller runable unit, it's a block defined with `test`
    # or a method with a name starting with `test_`.
    class TestSuite
      attr_reader :klass

      def initialize(registry, test_suite)
        @registry = registry
        @klass = test_suite
        @test_cases = {}
      end

      def abstract?
        !@klass.name || !@klass.name.end_with?("Test")
      end

      def test_cases
        @test_cases.keys
      end

      def register_test_case(name, block)
        test = BlockTest.new(@klass, name, block)
        raise "TODO: duplicate error" if @test_cases[test]

        @test_cases[test] = true
        @registry.clear_cache
      end
    end
  end

  class Registry
    unless Symbol.method_defined?(:name)
      using Module.new {
        refine Symbol do
          alias_method :name, :to_s
        end
      }
    end

    unless Symbol.method_defined?(:start_with?)
      using Module.new {
        refine Symbol do
          def start_with?(*args)
            to_s.start_with?(*args)
          end
        end
      }
    end

    def initialize
      @test_suites = {}
      clear_cache
    end

    def [](test_id)
      test_cases.find { |t| t.id == test_id } or raise KeyError, test_id # TODO: need O(1) lookup
    end

    def clear_cache
      @test_cases = @test_cases_by_path = nil
    end

    def suite(test_suite)
      @test_suites[test_suite] ||= begin
        clear_cache
        State::TestSuite.new(self, test_suite)
      end
    end

    def test_suites
      @test_suites.values
    end

    def test_cases
      @test_cases ||= @test_suites.flat_map do |klass, suite|
        next [] if suite.abstract?

        test_cases = suite.test_cases
        parent_class = klass
        while parent_class.superclass < ::Megatest::Test
          parent_class = parent_class.superclass
          test_cases += @test_suites[parent_class].test_cases.map { |t| t.inherited_by(klass) }
        end

        test_methods = klass.public_instance_methods.select { |m| m.start_with?("test_") }
        test_methods.map! { |m| MethodTest.new(klass, m.name, klass.instance_method(m)) }
        test_cases += test_methods
        test_cases
      end
    end

    def test_cases_by_path
      @test_cases_by_path ||= test_cases.each_with_object({}) do |test_case, hash|
        (hash[test_case.source_file] ||= []) << test_case
      end
    end
  end

  singleton_class.attr_accessor :registry
  self.registry = Registry.new

  class TestCaseResult
    attr_accessor :assertions_count
    attr_reader :failure, :duration, :test_id, :source_file, :source_line

    def initialize(test_case)
      @test_id = test_case.id
      @source_file = test_case.source_file
      @source_line = test_case.source_line
      @assertions_count = 0
      @failure = nil
      @duration = nil
    end

    def record
      start_time = Megatest.now
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
      @duration = Megatest.now - start_time
      self
    end

    def source_location
      if @source_file
        [@source_file, @source_line]
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
  end

  class AbstractTest
    attr_reader :id, :klass, :name, :source_file, :source_line

    def initialize(klass, name, callable)
      @id = "#{klass.name}##{name}"
      @klass = klass
      @name = name
      @callable = callable
      @source_file, @source_line = callable.source_location
    end

    def inherited_by(klass)
      copy = dup
      copy.klass = klass
      copy
    end

    def ==(other)
      other.is_a?(AbstractTest) &&
        @klass == other.klass &&
        @name == other.name
    end
    alias_method :eql?, :==

    def hash
      [AbstractTest, @klass, @name].hash
    end

    def <=>(other)
      cmp = @klass.name <=> other.klass.name
      cmp = @name <=> other.name if cmp.zero?
      cmp
    end

    protected

    def klass=(klass)
      @klass = klass
      @id = "#{klass.name}##{@name}"
    end
  end

  class BlockTest < AbstractTest
    def run
      result = TestCaseResult.new(self)
      instance = klass.new(result)
      result.record do
        instance.instance_exec(&@callable)
      end
    end
  end

  class MethodTest < AbstractTest
    unless UnboundMethod.method_defined?(:bind_call)
      using Module.new {
        refine UnboundMethod do
          def bind_call(receiver, *args, &block)
            bind(receiver).call(*args, &block)
          end
        end
      }
    end

    def run
      result = TestCaseResult.new(self)
      instance = klass.new(result)
      result.record do
        @callable.bind_call(instance)
      end
    end
  end
end
