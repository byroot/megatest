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
    def assert(result, message: nil)
      @__mega_result.assertions_count += 1
      return if result

      flunk(message || "Expected #{result.inspect} to be truthy")
    end

    def assert_nil(actual, message: nil)
      @__mega_result.assertions_count += 1
      unless nil.equal?(actual)
        flunk(message || "Expected #{actual.inspect} to be nil")
      end
    end

    def refute_nil(actual, message: nil)
      @__mega_result.assertions_count += 1
      if nil.equal?(actual)
        flunk(message || "Expected #{actual.inspect} to not be nil")
      end
    end

    def assert_equal(expected, actual, message: nil, allow_nil: false)
      @__mega_result.assertions_count += 1
      if nil == expected
        if allow_nil
          @__mega_result.assertions_count -= 1
          assert_nil(actual, message: message)
        else
          flunk("Use assert_nil if expecting nil, or pass `allow_nil: true`")
        end
      elsif expected != actual
        flunk(
          message ||
          @__mega_config.diff(expected, actual) ||
          "Expected: #{@__mega_config.pretty_print(expected)}\n  Actual: #{@__mega_config.pp(actual)}",
        )
      else
        true
      end
    end

    def assert_instance_of(klass, actual, message: nil)
      @__mega_result.assertions_count += 1
      unless actual.instance_of?(klass)
        flunk(message || "Expected #{actual.inspect} to be an instance of #{klass}, not #{actual.class.name || actual.class}")
      end
    end

    def assert_predicate(actual, predicate, message: nil)
      @__mega_result.assertions_count += 1
      unless @__mega_result.expect_no_failures { actual.__send__(predicate) }
        flunk(message || "Expected #{@__mega_config.pp(actual)} to be #{predicate}")
      end
    end

    def refute_predicate(actual, predicate, message: nil)
      @__mega_result.assertions_count += 1
      if @__mega_result.expect_no_failures { actual.__send__(predicate) }
        flunk(message || "Expected #{@__mega_config.pp(actual)} to not be #{predicate}")
      end
    end

    def assert_match(original_matcher, obj, message: nil)
      @__mega_result.assertions_count += 1
      matcher = if ::String === original_matcher
        ::Regexp.new(::Regexp.escape(original_matcher))
      else
        original_matcher
      end

      unless match = matcher.match(obj)
        flunk(message || "Expected #{@__mega_config.pp(original_matcher)} to match #{@__mega_config.pp(obj)}")
      end
      match
    end

    def assert_respond_to(object, method, message: nil, include_all: false)
      @__mega_result.assertions_count += 1
      unless object.respond_to?(method, include_all)
        flunk(message || "Expected #{@__mega_config.pp(object)} to respond to :#{method}")
      end
    end

    def refute_respond_to(object, method, message: nil, include_all: false)
      @__mega_result.assertions_count += 1
      if object.respond_to?(method, include_all)
        flunk(message || "Expected #{@__mega_config.pp(object)} to not respond to :#{method}")
      end
    end

    def assert_same(expected, actual, message: nil)
      @__mega_result.assertions_count += 1
      unless expected.equal?(actual)
        message ||= begin
          actual_pp = @__mega_config.pp(actual)
          expected_pp = @__mega_config.pp(expected)
          if actual_pp == expected_pp
            actual_pp += " (id: #{actual.object_id})"
            expected_pp += " (id: #{expected.object_id})"
          end

          "Expected          #{actual_pp}\n" \
          "To be the same as #{expected_pp}"
        end

        flunk(message)
      end
    end

    def refute_same(expected, actual, message: nil)
      @__mega_result.assertions_count += 1
      if expected.equal?(actual)
        message ||= begin
          actual_pp = @__mega_config.pp(actual)
          expected_pp = @__mega_config.pp(expected)
          if actual_pp == expected_pp
            actual_pp += " (id: #{actual.object_id})"
            expected_pp += " (id: #{expected.object_id})"
          end

          "Expected              #{actual_pp}\n" \
          "To not be the same as #{expected_pp}"
        end

        flunk(message)
      end
    end

    def assert_raises(*expected_exceptions, message: nil)
      @__mega_result.assertions_count += 1

      flunk "assert_raises requires a block to capture errors." unless block_given?
      expected_exceptions << StandardError if expected_exceptions.empty?

      begin
        yield
      rescue *expected_exceptions => exception
        return exception
      rescue ::Megatest::Assertion, *::Megatest::IGNORED_ERRORS
        raise # Pass through
      rescue ::Exception => exception
        # TODO: render exception
        flunk("#{expected_exceptions.inspect} exception expected, not #{exception.inspect}")
      end

      flunk message || "#{expected_exceptions.inspect} expected but nothing was raised."
    end

    def skip(message)
      message ||= "Skipped, no message given"
      ::Kernel.raise(::Megatest::Skip, message, nil)
    end

    def flunk(postional_message = nil, message: postional_message)
      message ||= "Failed"
      message = message.call if message.respond_to?(:call)
      ::Kernel.raise(::Megatest::Assertion, String(message))
    end
  end
end
