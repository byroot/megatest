# frozen_string_literal: true

# :stopdoc:

module Megatest
  @registry = nil

  class << self
    def registry
      raise Error, "Can't define tests without a registry set" unless @registry

      @registry
    end

    def with_registry(registry = Registry.new)
      @registry = registry
      begin
        yield
      ensure
        @registry = nil
      end
      registry
    end
  end

  module State
    using Compat::Name unless Symbol.method_defined?(:name)
    using Compat::StartWith unless Symbol.method_defined?(:start_with?)

    class Suite
      attr_reader :setup_callback, :teardown_callback, :around_callback

      def initialize(registry)
        @registry = registry
        @tags = nil
        @setup_callback = nil
        @teardown_callback = nil
        @around_callback = nil
        @current_context = nil
        @current_tags = nil
      end

      def with_context(context, tags)
        previous_context = @current_context
        @current_context = [@current_context, context].compact.join(" ")

        previous_tags = @current_tags
        if tags
          @current_tags = @current_tags ? @current_tags.merge(tags) : tags
        end

        begin
          yield
        ensure
          @current_context = previous_context
          @current_tags = previous_tags
        end
      end

      def add_tags(tags)
        return if tags.empty?

        @tags ||= {}
        @tags.merge!(tags)
      end

      def tag?(name)
        @tags&.key?(name)
      end

      def own_tags
        @tags
      end

      def build_test_case(name, callable, tags, source_location)
        name = [*@current_context, name].join(" ")
        tags = if tags
          @current_tags ? @current_tags.merge(tags) : tags
        else
          @current_tags
        end
        if callable.is_a?(UnboundMethod)
          MethodTest.new(self, @klass, name, callable, tags, source_location)
        else
          BlockTest.new(self, @klass, name, callable, tags, source_location)
        end
      end

      def on_setup(block)
        raise Error, "The setup block is already defined" if @setup_callback
        raise Error, "setup blocks can't be defined in context blocks" if @current_context

        @setup_callback = block
      end

      def on_around(block)
        raise Error, "The around block is already defined" if @around_callback
        raise Error, "around blocks can't be defined in context blocks" if @current_context

        @around_callback = block
      end

      def on_teardown(block)
        raise Error, "The teardown block is already defined" if @teardown_callback
        raise Error, "teardown blocks can't be defined in context blocks" if @current_context

        @teardown_callback = block
      end
    end

    # A test suite is a group of tests. It's a class that inherits Megatest::Test
    # A test case is the smaller runable unit, it's a block defined with `test`
    # or a method with a name starting with `test_`.
    class TestSuite < Suite
      attr_reader :klass, :source_file, :source_line

      def initialize(registry, test_suite, location)
        super(registry)
        @klass = test_suite
        @source_file, @source_line = location
        @ancestors = nil
        @test_cases = if test_suite.is_a?(Class) && test_suite.superclass < ::Megatest::Test
          registry.suite(test_suite.superclass).test_cases.to_h do |t|
            test = t.inherited_by(self)
            [test, test]
          end
        else
          {}
        end
        @test_cases.each_key do |test|
          @registry.register_test_case(test)
        end
      end

      def tags
        tags = {}
        tags.merge!(*ancestors.reverse.map(&:own_tags).compact)
        tags.merge!(@tags) if @tags
        tags
      end

      def tag(name)
        if @tags&.key?(name)
          @tags[name]
        else
          ancestors.each do |ancestor|
            return ancestor.tag(name) if ancestor.tag?(name)
          end
          nil
        end
      end

      def shared?
        false
      end

      def ancestors
        @ancestors ||= @registry.ancestors(@klass)
      end

      def test_cases
        @test_cases.keys
      end

      def register_test_case(name, callable, tags)
        source_location = callable.source_location
        if !shared? && source_location[0] != @source_file
          # When a test class is reopened from a different file, or when a test is defined
          # using some sort of class method macro, the resulting `source_file` doesn't match
          # the test suite, hence can't be used to point to the test as it would
          # have a `source_file` that can't be used to run a single test file.
          #
          # So we need some work to try to figure out the actual test definition location,
          # and if we really can't, then we fallback to the suite location.
          source_location = fixed_source_location || [@source_file, @source_line]
        end

        test = build_test_case(name, callable, tags, source_location)
        add_test(test)
      end

      if Thread.respond_to?(:each_caller_location)
        def fixed_source_location
          Thread.each_caller_location do |location|
            if location.path == @source_file
              return [location.path, location.lineno]
            end
          end
          nil
        end
      else
        def fixed_source_location
          caller_locations.each do |location|
            if location.path == @source_file
              return [location.path, location.lineno]
            end
          end
          nil
        end
      end

      def add_test(test)
        if duplicate = @test_cases[test]
          # It was late defined in an parent class we can just ignore it.
          return test if test.inherited?

          if duplicate.inherited?
            @test_cases.delete(duplicate)
            @registry.remove_test_case(duplicate)
          else
            # If the pre-existing test wasn't inherited, it means we're defining the
            # same test twice, that's a mistake.
            raise AlreadyDefinedError,
                  "`#{test.id}` already defined at #{Megatest.relative_path(test.source_file)}:#{test.source_line}"
          end
        end

        @test_cases[test] = test
        @registry.register_test_case(test)
        test
      end

      def inherit_test_case(test_case)
        add_test(test_case.inherited_by(self))
      end

      def include_test_case(test_case, include_location)
        add_test(test_case.included_by(self, include_location))
      end
    end

    class SharedSuite < Suite
      def initialize(registry, test_suite)
        super(registry)
        @mod = test_suite
        @test_cases = {}
        test_suite.instance_methods.each do |name|
          if name.start_with?("test_")
            register_test_case(name, test_suite.instance_method(name), nil)
          end
        end
      end

      def shared?
        true
      end

      def included_by(klass_or_module, include_location)
        if klass_or_module.is_a?(Class)
          suite = @registry.suite(klass_or_module)
          @test_cases.each_key do |test_case|
            suite.include_test_case(test_case, include_location)
          end
        end
      end

      def register_test_case(name, callable, tags)
        test = build_test_case(name, callable, tags, callable.source_location)

        if @test_cases[test]
          raise AlreadyDefinedError,
                "`#{test.id}` already defined at #{Megatest.relative_path(test.source_file)}:#{test.source_line}"
        end

        @test_cases[test] = test
      end
    end

    # :startdoc:

    class Test
      attr_reader :klass, :name, :source_file, :source_line

      # :stopdoc:
      attr_accessor :index

      def initialize(test_suite, klass, name, callable, tags, location)
        @test_suite = test_suite
        @klass = klass
        @name = name
        @callable = callable
        @source_file, @source_line = location
        @id = nil
        @index = nil
        @inherited = false
        @tags = tags
      end

      # :startdoc:

      ##
      # Returns a unique identifier string for that test, in the form of `klass#name`
      def id
        if klass.name
          @id ||= "#{klass.name}##{name}"
        else
          "#{klass}##{name}"
        end
      end

      ##
      # Lookup a tag for that test. Returns +nil+ if the tag isn't set.
      def tag(name)
        if @tags&.key?(name)
          @tags[name]
        else
          @test_suite.tag(name)
        end
      end

      # :stopdoc:

      def inspect
        if klass.name
          "#<#{self.class}: #{id} @ #{location_id}>"
        else
          "#<#{self.class}: #{klass.inspect}##{name} @ #{location_id}>"
        end
      end

      def tags
        @test_suite.tags.merge(@tags || {})
      end

      def location_id
        if @index
          "#{@source_file}:#{@source_line}~#{@index}"
        else
          "#{@source_file}:#{@source_line}"
        end
      end

      def inherited?
        @inherited
      end

      def inherited_by(test_suite)
        copy = dup
        copy.test_suite = test_suite
        copy.source_file = test_suite.source_file
        copy.source_line = test_suite.source_line
        copy.inherited = true
        copy
      end

      def included_by(test_suite, include_location)
        copy = dup
        copy.test_suite = test_suite
        copy.source_file, copy.source_line = include_location
        copy.inherited = true
        copy
      end

      def ==(other)
        other.is_a?(Test) &&
          @klass == other.klass &&
          @name == other.name
      end
      alias_method :eql?, :==

      def hash
        [Test, @klass, @name].hash
      end

      def <=>(other)
        cmp = @klass.name <=> other.klass.name
        cmp = @name <=> other.name if cmp&.zero?
        cmp || 0
      end

      def each_setup_callback
        @test_suite.ancestors.reverse_each do |test_suite|
          yield test_suite.setup_callback if test_suite.setup_callback
        end
      end

      using Compat::FilterMap unless Enumerable.method_defined?(:filter_map)

      def around_callbacks
        @test_suite.ancestors.filter_map(&:around_callback)
      end

      def each_teardown_callback
        @test_suite.ancestors.each do |test_suite|
          yield test_suite.teardown_callback if test_suite.teardown_callback
        end
      end

      protected

      attr_writer :inherited, :source_file, :source_line

      def test_suite=(test_suite)
        @id = nil
        @test_suite = test_suite
        @klass = test_suite.klass
      end
    end

    # :stopdoc:

    class BlockTest < Test
      def execute(runtime, instance)
        runtime.record_failures(downlevel: 2) { instance.instance_exec(&@callable) }
      end
    end

    class MethodTest < Test
      if UnboundMethod.method_defined?(:bind_call)
        def execute(runtime, instance)
          runtime.record_failures(downlevel: 2) { @callable.bind_call(instance) }
        end
      else
        using Compat::BindCall

        def execute(runtime, instance)
          runtime.record_failures(downlevel: 3) { @callable.bind_call(instance) }
        end
      end
    end
  end

  class Registry
    def initialize
      @test_suites = {}
      @shared_suites = {}
      @test_cases_by_location = {}
    end

    def shared_suite(test_suite)
      @shared_suites[test_suite] ||= State::SharedSuite.new(self, test_suite)
    end

    def suite(klass)
      @shared_suites[klass] || @test_suites.fetch(klass)
    end

    def ancestors(klass)
      suites = []
      klass.ancestors.each do |mod|
        suite = @shared_suites[mod] || @test_suites[mod]
        suites << suite if suite

        break if mod == ::Megatest::Test
      end
      suites
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
          if test_suite.is_a?(Class)
            @subclasses ||= {}
            (@subclasses[test_suite.superclass] ||= []) << test_suite
          end
          State::TestSuite.new(self, test_suite, location)
        end
      end

      def each_subclass_of(klass, &block)
        @subclasses[klass]&.each(&block)
      end
    end

    def register_test_case(test_case)
      path_index = @test_cases_by_location[test_case.source_file] ||= {}
      line_tests = path_index[test_case.source_line] ||= []

      unless line_tests.empty?
        test_case.index = line_tests.size
        if line_tests.size == 1
          line_tests.first.index = 0
        end
      end

      line_tests << test_case

      each_subclass_of(test_case.klass) do |subclass|
        suite(subclass).inherit_test_case(test_case)
      end
    end

    def remove_test_case(test_case)
      path_index = @test_cases_by_location[test_case.source_file]
      line_tests = path_index[test_case.source_line]
      remove_index = line_tests.index(test_case)
      line_tests.delete_at(remove_index)
      case line_tests.size
      when 0
        # noop
      when 1
        line_tests[0].index = nil
      else
        remove_index.upto(line_tests.size - 1) do |index|
          line_tests[index].index -= 1
        end
      end
      test_cases
    end

    def test_suites
      @test_suites.values
    end

    def test_cases
      @test_suites.flat_map do |_klass, suite|
        suite.test_cases
      end
    end

    def test_cases_by_path(path = nil)
      if path
        if index = @test_cases_by_location[path]
          index.values.flatten
        else
          []
        end
      else
        @test_cases_by_location.transform_values do |line_index|
          line_index.flat_map do |_line, test_cases|
            test_cases
          end
        end
      end
    end
  end

  class Failure
    attr_reader :name, :message, :backtrace, :cause

    def initialize(exception)
      @name = exception.class.name
      @message = exception.message
      @backtrace = exception.backtrace
      @cause = exception.cause ? Failure.new(exception.cause) : nil
    end
  end

  class TestCaseResult
    class << self
      def load(payload)
        Marshal.load(payload)
      end
    end

    attr_accessor :assertions_count
    attr_reader :failures, :duration, :test_id, :test_location

    def initialize(test_case)
      @test_id = test_case.id
      @test_location = test_case.location_id
      @assertions_count = 0
      @retried = false
      @failures = []
      @duration = nil
    end

    def dump
      Marshal.dump(self)
    end

    def record_time
      start_time = Megatest.now
      begin
        yield
      ensure
        @duration = Megatest.now - start_time
      end
      self
    end

    def failure
      @failures.first
    end

    def ok?
      success? || retried? || skipped?
    end

    def bad?
      !@retried && !@failures.empty?
    end

    def status
      if skipped?
        :skipped
      elsif retried?
        :retried
      elsif error?
        :error
      elsif failed?
        :failure
      else
        :success
      end
    end

    def ensure_assertions
      if @assertions_count.zero? && success?
        @failures << Failure.new(NoAssertion.new)
      end
      self
    end

    def did_not_run(reason)
      @failures << Failure.new(DidNotRun.new(reason))
      self
    end

    def lost
      @failures << Failure.new(LostTest.new(@test_id))
      @duration = 0.0
      self
    end

    def success?
      @failures.empty?
    end

    def retried?
      @retried
    end

    def failed?
      !@failures.empty?
    end

    def failure?
      !@retried && !skipped? && !@failures.empty? && @failures.first&.name != UnexpectedError.name
    end

    def error?
      !@retried && @failures.first&.name == UnexpectedError.name
    end

    def lost?
      @failures.first&.name == LostTest.name
    end

    def skipped?
      @failures.first&.name == Skip.name
    end

    def retry
      copy = dup
      copy.retried = true
      copy
    end

    protected

    attr_writer :retried
  end
end
