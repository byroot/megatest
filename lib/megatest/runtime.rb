# frozen_string_literal: true

module Megatest
  class Runtime
    def initialize(config, result)
      @config = config
      @result = result
    end

    def assert
      @result.assertions_count += 1
      yield
    end

    EMPTY_BACKTRACE = [].freeze

    def fail(message)
      message ||= "Failed"
      message = message.call if message.respond_to?(:call)
      raise(Assertion, String(message))
    end

    def pp(object)
      @config.pretty_print(object)
    end

    def diff(expected, actual)
      @config.diff(expected, actual)
    end

    def record_failures(&block)
      expect_no_failures(&block)
    rescue Assertion => assertion
      @result.failures << Failure.new(assertion)
    end

    def expect_no_failures
      yield
    rescue Assertion, *Megatest::IGNORED_ERRORS
      raise # Exceptions we shouldn't rescue
    rescue Exception => original_error
      raise UnexpectedError, original_error
    end
  end
end
