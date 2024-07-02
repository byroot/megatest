# frozen_string_literal: true

module Megatest
  module State
    # A test suite is a group of tests. It's a class that inherits Megatest::Test
    # A test case is the smaller runable unit, it's a block defined with `test`
    # or a method with a name starting with `test_`.
    class TestSuite
      attr_reader :klass, :source_file, :source_line

      def initialize(registry, test_suite, location)
        @registry = registry
        @klass = test_suite
        @source_file, @source_line = location

        @test_cases = if test_suite.superclass < ::Megatest::Test
          registry.suite(test_suite.superclass).test_cases.to_h do |t|
            test = t.inherited_by(self)
            [test, test]
          end
        else
          {}
        end
      end

      def abstract?
        !@klass.name || !@klass.name.end_with?("Test")
      end

      def test_cases
        @test_cases.keys
      end

      unless Symbol.method_defined?(:name)
        using Module.new {
          refine Symbol do
            alias_method :name, :to_s
          end
        }
      end

      def register_test_case(name, callable)
        test = if callable.is_a?(UnboundMethod)
          MethodTest.new(@klass, name.name, callable)
        else
          BlockTest.new(@klass, name, callable)
        end
        add_test(test)
        @registry.register_test_case(test)
      end

      def add_test(test)
        if duplicate = @test_cases[test]
          return test if test.inherited?

          unless duplicate.inherited?
            raise AlreadyDefinedError,
                  "`#{test.id}` already defined at #{Megatest.relative_path(test.source_file)}:#{test.source_line}"
          end
        end

        @test_cases[test] = test
      end

      def inherit_test_case(test_case)
        test = test_case.inherited_by(self)
        add_test(test)
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
      @test_cases_by_path = {}
    end

    def [](test_id)
      test_cases.find { |t| t.id == test_id } or raise KeyError, test_id # TODO: need O(1) lookup
    end

    def suite(klass)
      @test_suites.fetch(klass)
    end

    if Class.method_defined?(:subclasses)
      def register_suite(test_suite, location)
        @test_suites[test_suite] ||= State::TestSuite.new(self, test_suite, location)
      end

      def each_subclass_of(klass, &block)
        klass.subclasses.each(&block)
      end
    else
      def register_suite(test_suite, location)
        @test_suites[test_suite] ||= begin
          @subclasses ||= {}
          (@subclasses[test_suite.superclass] ||= []) << test_suite
          State::TestSuite.new(self, test_suite, location)
        end
      end

      def each_subclass_of(klass, &block)
        @subclasses[klass]&.each(&block)
      end
    end

    def register_test_case(test_case)
      (@test_cases_by_path[test_case.source_file] ||= []) << test_case
      each_subclass_of(test_case.klass) do |subclass|
        child_test_case = suite(subclass).inherit_test_case(test_case)
        register_test_case(child_test_case)
      end
    end

    def test_suites
      @test_suites.values
    end

    def test_cases
      @test_suites.flat_map do |_klass, suite|
        if suite.abstract?
          []
        else
          suite.test_cases
        end
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
    attr_reader :klass, :name, :source_file, :source_line

    def initialize(klass, name, callable)
      @klass = klass
      @name = name
      @callable = callable
      @source_file, @source_line = callable.source_location
      @id = nil
      @inherited = false
    end

    def id
      if klass.name
        @id ||= "#{klass.name}##{name}"
      else
        "#{klass.inspect}##{name}"
      end
    end

    def inherited?
      @inherited
    end

    def inherited_by(test_suite)
      copy = dup
      copy.test_suite = test_suite
      copy.inherited = true
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

    attr_writer :inherited

    def test_suite=(test_suite)
      @id = nil
      @klass = test_suite.klass
      @source_file = test_suite.source_file
      @source_line = test_suite.source_line
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
