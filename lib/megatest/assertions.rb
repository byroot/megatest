# frozen_string_literal: true

module Megatest
  class Assertion < Exception
  end

  class NoAssertion < Assertion
    def initialize(message = "No assertions performed")
      super
    end
  end

  DidNotRun = Class.new(Assertion)

  class LostTest < Assertion
    def initialize(test_id)
      super("#{test_id} never completed. Might be caused by a crash or early exit?")
    end
  end

  Skip = Class.new(Assertion)

  class UnexpectedError < Assertion
    attr_reader :cause

    def initialize(cause)
      super("Unexpected exception")
      @cause = cause
    end

    def backtrace
      cause.backtrace
    end

    def backtrace_locations
      cause.backtrace_locations
    end
  end

  module Assertions
    def pass
      @__m.assert {}
    end

    def assert(result, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        return if result

        if message
          @__m.fail(message)
        else
          @__m.fail(message, "Expected", @__m.pp(result), "to be truthy")
        end
      end
    end

    def refute(result, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        return unless result

        if message
          @__m.fail(message)
        else
          @__m.fail(message, "Expected", @__m.pp(result), "to be falsy")
        end
      end
    end
    alias_method :assert_not, :refute

    def assert_nil(actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless nil.equal?(actual)
          @__m.fail(message, "Expected", @__m.pp(actual), "to be nil")
        end
      end
    end

    def refute_nil(actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if nil.equal?(actual)
          @__m.fail(message, "Expected", @__m.pp(actual), "to not be nil")
        end
      end
    end
    alias_method :assert_not_nil, :refute_nil

    def assert_equal(expected, actual, msg = nil, message: nil, allow_nil: false)
      message = @__m.msg(msg, message)
      @__m.assert do
        if !allow_nil && nil == expected
          @__m.fail(nil, "Use assert_nil if expecting nil, or pass `allow_nil: true`")
        end

        if expected != actual
          @__m.fail(
            message,
            @__m.diff(expected, actual) ||
            "Expected: #{@__m.pp(expected)}\n" \
            "  Actual: #{@__m.pp(actual)}",
          )
        end
      end
    end

    def refute_equal(expected, actual, msg = nil, message: nil, allow_nil: false)
      message = @__m.msg(msg, message)
      @__m.assert do
        if !allow_nil && nil == expected && !@__m.minitest_compatibility?
          @__m.fail(nil, "Use refute_nil if expecting to not be nil, or pass `allow_nil: true`")
        end

        if expected == actual
          @__m.fail(message, "Expected", @__m.pp(expected), "to not equal", @__m.pp(actual))
        end
      end
    end
    alias_method :assert_not_equal, :refute_equal

    def assert_includes(collection, object, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless collection.include?(object)
          @__m.fail message, "Expected", @__m.pp(collection), "to include", @__m.pp(object)
        end
      end
    end

    def refute_includes(collection, object, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if collection.include?(object)
          @__m.fail message, "Expected", @__m.pp(collection), "to not include", @__m.pp(object)
        end
      end
    end
    alias_method :assert_not_includes, :refute_includes

    def assert_empty(object, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless object.empty?
          @__m.fail message, "Expected", @__m.pp(object), "to be empty"
        end
      end
    end

    def refute_empty(object, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if object.empty?
          @__m.fail message, "Expected", @__m.pp(object), "to not be empty"
        end
      end
    end
    alias_method :assert_not_empty, :refute_empty

    def assert_instance_of(klass, actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless actual.instance_of?(klass)
          @__m.fail(message, "Expected", @__m.pp(actual), "to be an instance of", @__m.pp(klass), "not", @__m.pp(actual.class))
        end
      end
    end

    def refute_instance_of(klass, actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if actual.instance_of?(klass)
          @__m.fail(message, "Expected", @__m.pp(actual), "to not be an instance of", @__m.pp(klass))
        end
      end
    end
    alias_method :assert_not_instance_of, :refute_instance_of

    def assert_kind_of(klass, actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless actual.kind_of?(klass)
          @__m.fail(message, "Expected", @__m.pp(actual), "to be a kind of", @__m.pp(klass), "not", @__m.pp(actual.class))
        end
      end
    end

    def refute_kind_of(klass, actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if actual.kind_of?(klass)
          @__m.fail(message, "Expected", @__m.pp(actual), "to not be a kind of", @__m.pp(klass))
        end
      end
    end
    alias_method :assert_not_kind_of, :refute_kind_of

    def assert_predicate(actual, predicate, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless @__m.expect_no_failures { actual.__send__(predicate) }
          @__m.fail(message, "Expected", @__m.pp(actual), "to be #{predicate}")
        end
      end
    end

    def refute_predicate(actual, predicate, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if @__m.expect_no_failures { actual.__send__(predicate) }
          @__m.fail(message, "Expected", @__m.pp(actual), "to not be #{predicate}")
        end
      end
    end
    alias_method :assert_not_predicate, :refute_predicate

    def assert_match(original_matcher, obj, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        matcher = if ::String === original_matcher
          ::Regexp.new(::Regexp.escape(original_matcher))
        else
          original_matcher
        end

        unless match = matcher.match(obj)
          @__m.fail(message, "Expected", @__m.pp(original_matcher), "to match", @__m.pp(obj))
        end

        match
      end
    end

    def refute_match(original_matcher, obj, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        matcher = if ::String === original_matcher
          ::Regexp.new(::Regexp.escape(original_matcher))
        else
          original_matcher
        end

        if matcher.match?(obj)
          @__m.fail(message, "Expected", @__m.pp(original_matcher), "to not match", @__m.pp(obj))
        end
      end
    end
    alias_method :assert_no_match, :refute_match

    def assert_respond_to(object, method, msg = nil, message: nil, include_all: false)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless object.respond_to?(method, include_all)
          @__m.fail(message, "Expected", @__m.pp(object), "to respond to :#{method}")
        end
      end
    end

    def refute_respond_to(object, method, msg = nil, message: nil, include_all: false)
      message = @__m.msg(msg, message)
      @__m.assert do
        if object.respond_to?(method, include_all)
          @__m.fail(message, "Expected", @__m.pp(object), "to not respond to :#{method}")
        end
      end
    end
    alias_method :assert_not_respond_to, :refute_respond_to

    def assert_same(expected, actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless expected.equal?(actual)
          @__m.fail message, begin
            actual_pp = @__m.pp(actual)
            expected_pp = @__m.pp(expected)
            if actual_pp == expected_pp
              actual_pp += " (id: #{actual.object_id})"
              expected_pp += " (id: #{expected.object_id})"
            end

            "Expected          #{actual_pp}\n" \
            "To be the same as #{expected_pp}"
          end
        end
      end
    end

    def refute_same(expected, actual, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if expected.equal?(actual)
          @__m.fail message, begin
            actual_pp = @__m.pp(actual)
            expected_pp = @__m.pp(expected)
            if actual_pp == expected_pp
              actual_pp += " (id: #{actual.object_id})"
              expected_pp += " (id: #{expected.object_id})"
            end

            "Expected              #{actual_pp}\n" \
            "To not be the same as #{expected_pp}"
          end
        end
      end
    end
    alias_method :assert_not_same, :refute_same

    def assert_raises(expected = StandardError, *expected_exceptions, match: nil, message: nil)
      msg = expected_exceptions.pop if expected_exceptions.last.is_a?(String)
      message = @__m.msg(msg, message)

      matcher = if match
        if ::String === match
          ::Regexp.new(::Regexp.escape(match))
        else
          match
        end
      end

      @__m.assert do
        @__m.fail("assert_raises requires a block to capture errors.") unless block_given?

        begin
          before_yield = __LINE__
          yield
        rescue expected, *expected_exceptions => exception
          if matcher && !matcher.match?(exception.message)
            @__m.fail(message, "Expected", @__m.pp(match), "to match", @__m.pp(exception.message))
          end

          return exception
        rescue ::Megatest::Assertion, *::Megatest::IGNORED_ERRORS
          raise # Pass through
        rescue ::Exception => unexepected_exception
          error = @__m.strip_backtrace(unexepected_exception, __FILE__, before_yield + 1, 0)

          expected_pp = if expected_exceptions.empty?
            @__m.pp(expected)
          else
            expected_exceptions.map { |e| @__m.pp(e) }.join(", ") << " or #{@__m.pp(expected)}"
          end

          @__m.fail(message, "#{expected_pp} exception expected, not:\n#{@__m.pp(error)}")
        else
          expected_pp = if expected_exceptions.empty?
            @__m.pp(expected)
          else
            expected_exceptions.map { |e| @__m.pp(e) }.join(", ") << " or #{@__m.pp(expected)}"
          end

          @__m.fail(message, "Expected", expected_pp, "but nothing was raised.")
        end
      end
    end
    alias :assert_raise :assert_raises

    def assert_nothing_raised
      @__m.assert do
        yield
      rescue ::Megatest::Assertion, *::Megatest::IGNORED_ERRORS
        raise # Pass through
      rescue Exception => unexepected_exception
        raise ::Megatest::UnexpectedError, unexepected_exception
      end
    end

    def assert_throws(thrown_object, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        caught = true
        value = catch(thrown_object) do
          @__m.expect_no_failures do
            yield
          rescue UncaughtThrowError => error
            @__m.fail(message, "Expected", @__m.pp(thrown_object), "to have been thrown, not:", @__m.pp(error.tag))
          end
          caught = false
        end

        unless caught
          @__m.fail(message, "Expected", @__m.pp(thrown_object), "to have been thrown, but it wasn't")
        end

        value
      end
    end

    def assert_operator(left, operator, right, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        unless left.__send__(operator, right)
          @__m.fail(message, "Expected", @__m.pp(left), "to be #{operator}", @__m.pp(right))
        end
      end
    end

    def refute_operator(left, operator, right, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        if left.__send__(operator, right)
          @__m.fail(message, "Expected", @__m.pp(left), "to not be #{operator}", @__m.pp(right))
        end
      end
    end
    alias_method :assert_not_operator, :refute_operator

    def assert_difference(expression, difference = @__m.unset, message: nil, &block)
      expressions = if @__m.set?(difference)
        Array(expression).to_h { |e| [e, difference] }
      elsif Hash === expression
        expression
      else
        Array(expression).to_h { |e| [e, 1] }
      end

      exps = expressions.keys.map { |e| @__m.expression(e, block) }

      @__m.assert do
        before = exps.map(&:call)

        retval = @__m.safe_yield(&block)

        expressions.zip(exps, before) do |(code, diff), exp, before_value|
          actual = exp.call
          expected = before_value + diff
          unless expected == actual
            error = "`#{@__m.pp_expression(code)}` didn't change by #{diff}, but by #{actual - before_value}."
            @__m.fail(message, error)
          end
        end

        retval
      end
    end

    def assert_in_delta(expected, actual, delta = 0.001, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        diff = (expected - actual).abs
        unless delta >= diff
          @__m.fail(message, "Expected", "|#{@__m.pp(expected)} - #{@__m.pp(actual)}| (#{diff})", "to be <= #{delta}")
        end
      end
    end

    def refute_in_delta(expected, actual, delta = 0.001, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        diff = (expected - actual).abs
        if delta >= diff
          @__m.fail(message, "Expected", "|#{@__m.pp(expected)} - #{@__m.pp(actual)}| (#{diff})", "to not be <= #{delta}")
        end
      end
    end
    alias_method :assert_not_in_delta, :refute_in_delta

    def assert_in_epsilon(expected, actual, epsilon = 0.001, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        diff = (expected - actual).abs
        delta = [expected.abs, actual.abs].min * epsilon
        unless delta >= diff
          @__m.fail(message, "Expected", "|#{@__m.pp(expected)} - #{@__m.pp(actual)}| (#{diff})", "to be <= #{delta}")
        end
      end
    end

    def refute_in_epsilon(expected, actual, epsilon = 0.001, msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        diff = (expected - actual).abs
        delta = [expected.abs, actual.abs].min * epsilon
        if delta >= diff
          @__m.fail(message, "Expected", "|#{@__m.pp(expected)} - #{@__m.pp(actual)}| (#{diff})", "to not be <= #{delta}")
        end
      end
    end
    alias_method :assert_not_epsilon, :refute_in_epsilon

    def skip(message = nil)
      message ||= "Skipped, no message given"
      ::Kernel.raise(::Megatest::Skip, message, nil)
    end

    def flunk(msg = nil, message: nil)
      message = @__m.msg(msg, message)
      @__m.assert do
        @__m.fail(message || "Failed")
      end
    end

    def assert_output(expected_stdout = nil, expected_stderr = nil, &block)
      @__m.assert do
        @__m.fail("assert_output requires a block to capture output.") unless block_given?

        actual_stdout, actual_stderr = @__m.expect_no_failures do
          capture_io(&block)
        end

        if expected_stderr
          if Regexp === expected_stderr
            assert_match(expected_stderr, actual_stderr, message: "In stderr")
          else
            assert_equal(expected_stderr, actual_stderr, message: "In stderr")
          end
        end

        if expected_stdout
          if Regexp === expected_stdout
            assert_match(expected_stdout, actual_stdout, message: "In stdout")
          else
            assert_equal(expected_stdout, actual_stdout, message: "In stdout")
          end
        end
      end
    end

    def assert_silent(&block)
      @__m.assert do
        assert_output("", "", &block)
      end
    end

    def capture_io
      require "stringio" unless defined?(::StringIO)
      captured_stdout, captured_stderr = ::StringIO.new, ::StringIO.new

      orig_stdout, orig_stderr = $stdout, $stderr
      $stdout, $stderr = captured_stdout, captured_stderr

      begin
        yield

        [captured_stdout.string, captured_stderr.string]
      ensure
        $stdout = orig_stdout
        $stderr = orig_stderr
      end
    end
  end
end
