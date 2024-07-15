# frozen_string_literal: true

module Megatest
  class Assertion < Exception
  end

  class NoAssertion < Assertion
    def initialize(message = "No assertions performed")
      super
    end
  end

  class LostTest < Assertion
    def initialize(test_id)
      super("#{test_id} never completed. Might be causing a crash or early exit?")
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

    def assert(result, message: nil)
      @__m.assert do
        return if result

        @__m.fail(message || "Expected #{@__m.pp(result)} to be truthy", nil)
      end
    end

    def refute(result, message: nil)
      @__m.assert do
        return unless result

        @__m.fail(message || "Expected #{@__m.pp(result)} to be falsy", nil)
      end
    end

    def assert_nil(actual, message: nil)
      @__m.assert do
        unless nil.equal?(actual)
          @__m.fail(message, "Expected #{@__m.pp(actual)} to be nil")
        end
      end
    end

    def refute_nil(actual, message: nil)
      @__m.assert do
        if nil.equal?(actual)
          @__m.fail(message, "Expected #{@__m.pp(actual)} to not be nil")
        end
      end
    end

    def assert_equal(expected, actual, message: nil, allow_nil: false)
      @__m.assert do
        if !allow_nil && nil == expected
          @__m.fail(nil, "Use assert_nil if expecting nil, or pass `allow_nil: true`")
        end

        if expected != actual
          @__m.fail(
            message,
            @__m.diff(expected, actual) ||
            "Expected: #{@__m.pp(expected)}\n  Actual: #{@__m.pp(actual)}",
          )
        end
      end
    end

    def assert_includes(collection, object, message: nil)
      @__m.assert do
        unless collection.include?(object)
          @__m.fail message, "Expected\n\n#{@__m.pp(collection)}\n\nto include\n\n#{@__m.pp(object)}"
        end
      end
    end

    def refute_includes(collection, object, message: nil)
      @__m.assert do
        if collection.include?(object)
          @__m.fail message, "Expected\n\n#{@__m.pp(collection)}\n\nto not include\n\n#{@__m.pp(object)}"
        end
      end
    end

    def assert_instance_of(klass, actual, message: nil)
      @__m.assert do
        unless actual.instance_of?(klass)
          @__m.fail(message, "Expected #{@__m.pp(actual)} to be an instance of #{@__m.pp(klass)}, not #{@__m.pp(actual.class)}")
        end
      end
    end

    def assert_predicate(actual, predicate, message: nil)
      @__m.assert do
        unless @__m.expect_no_failures { actual.__send__(predicate) }
          @__m.fail(message, "Expected #{@__m.pp(actual)} to be #{predicate}")
        end
      end
    end

    def refute_predicate(actual, predicate, message: nil)
      @__m.assert do
        if @__m.expect_no_failures { actual.__send__(predicate) }
          @__m.fail(message, "Expected #{@__m.pp(actual)} to not be #{predicate}")
        end
      end
    end

    def assert_match(original_matcher, obj, message: nil)
      @__m.assert do
        matcher = if ::String === original_matcher
          ::Regexp.new(::Regexp.escape(original_matcher))
        else
          original_matcher
        end

        unless match = matcher.match(obj)
          @__m.fail(message, "Expected #{@__m.pp(original_matcher)} to match #{@__m.pp(obj)}")
        end

        match
      end
    end

    def assert_respond_to(object, method, message: nil, include_all: false)
      @__m.assert do
        unless object.respond_to?(method, include_all)
          @__m.fail(message, "Expected #{@__m.pp(object)} to respond to :#{method}")
        end
      end
    end

    def refute_respond_to(object, method, message: nil, include_all: false)
      @__m.assert do
        if object.respond_to?(method, include_all)
          @__m.fail(message, "Expected #{@__m.pp(object)} to not respond to :#{method}")
        end
      end
    end

    def assert_same(expected, actual, message: nil)
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

    def refute_same(expected, actual, message: nil)
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

    def assert_raises(expected = StandardError, *expected_exceptions, message: nil)
      @__m.assert do
        @__m.fail("assert_raises requires a block to capture errors.") unless block_given?

        begin
          yield
        rescue expected, *expected_exceptions => exception
          return exception
        rescue ::Megatest::Assertion, *::Megatest::IGNORED_ERRORS
          raise # Pass through
        rescue ::Exception => unexepected_exception
          error = @__m.strip_backtrace(unexepected_exception, __FILE__, __LINE__ - 6, 0)

          expected_pp = if expected_exceptions.empty?
            @__m.pp(expected)
          else
            expected_exceptions.map { |e| @__m.pp(e) }.join(", ") << " or #{@__m.pp(expected)}"
          end

          @__m.fail(message, "#{expected_pp} exception expected, not:\n#{@__m.pp(error)}")
        end

        expected_pp = if expected_exceptions.empty?
          @__m.pp(expected)
        else
          expected_exceptions.map { |e| @__m.pp(e) }.join(", ") << " or #{@__m.pp(expected)}"
        end

        @__m.fail(message, "#{expected_pp} expected but nothing was raised.")
      end
    end

    def assert_operator(left, operator, right, message: nil)
      @__m.assert do
        unless left.__send__(operator, right)
          @__m.fail(message, "Expected #{@__m.pp(left)} to be #{operator} #{@__m.pp(right)}")
        end
      end
    end

    def assert_in_delta(expected, actual, delta = 0.001, message: nil)
      @__m.assert do
        diff = (expected - actual).abs
        unless delta >= diff
          @__m.fail(message, "Expected |#{@__m.pp(expected)} - #{@__m.pp(actual)}| (#{diff}) to be <= #{delta}")
        end
      end
    end

    def assert_in_epsilon(expected, actual, epsilon = 0.001, message: nil)
      @__m.assert do
        diff = (expected - actual).abs
        delta = [expected.abs, actual.abs].min * epsilon
        unless delta >= diff
          @__m.fail(message, "Expected |#{@__m.pp(expected)} - #{@__m.pp(actual)}| (#{diff}) to be <= #{delta}")
        end
      end
    end

    def skip(message)
      message ||= "Skipped, no message given"
      ::Kernel.raise(::Megatest::Skip, message, nil)
    end

    def flunk(postional_message = nil, message: postional_message)
      @__m.assert do
        @__m.fail(message || "Failed", nil)
      end
    end
  end
end
