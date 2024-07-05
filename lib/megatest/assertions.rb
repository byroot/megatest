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

      message ||= "Expected #{result.inspect} to be truthy"
      flunk(message)
    end

    def flunk(postional_message = nil, message: postional_message)
      message ||= "Failed"
      message = message.call if message.respond_to?(:call)
      ::Kernel.raise(::Megatest::Assertion, String(message))
    end
  end
end
