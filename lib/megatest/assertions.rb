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
      @__mega.assertions_count += 1
      return if result

      flunk(message || "Expected #{result.inspect} to be truthy")
    end

    def assert_nil(actual, message: nil)
      @__mega.assertions_count += 1
      unless nil.equal?(actual)
        flunk(message || "Expected #{actual.inspect} to be nil")
      end
    end

    def refute_nil(actual, message: nil)
      @__mega.assertions_count += 1
      if nil.equal?(actual)
        flunk(message || "Expected #{actual.inspect} to not be nil")
      end
    end

    def assert_equal(expected, actual, message: nil, allow_nil: false)
      @__mega.assertions_count += 1
      if nil == expected
        if allow_nil
          @__mega.assertions_count -= 1
          assert_nil(actual, message: message)
        else
          flunk("Use assert_nil if expecting nil, or pass `allow_nil: true`")
        end
      elsif expected != actual
        flunk(message || "Expected: #{expected.inspect}\n  Actual: #{actual.inspect}")
      else
        true
      end
    end

    def assert_instance_of(klass, actual, message: nil)
      @__mega.assertions_count += 1
      unless actual.instance_of?(klass)
        flunk(message || "Expected #{actual.inspect} to be an instance of #{klass}, not #{actual.class}")
      end
    end

    def assert_predicate(actual, predicate, message: nil)
      @__mega.assertions_count += 1
      unless @__mega.expect_no_failures { actual.__send__(predicate) }
        flunk(message || "Expected #{actual.inspect} to be #{predicate}")
      end
    end

    def refute_predicate(actual, predicate, message: nil)
      @__mega.assertions_count += 1
      if @__mega.expect_no_failures { actual.__send__(predicate) }
        flunk(message || "Expected #{actual.inspect} to not be #{predicate}")
      end
    end

    def assert_raises(*expected_exceptions, message: nil)
      @__mega.assertions_count += 1

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

    def flunk(postional_message = nil, message: postional_message)
      message ||= "Failed"
      message = message.call if message.respond_to?(:call)
      ::Kernel.raise(::Megatest::Assertion, String(message))
    end
  end
end
