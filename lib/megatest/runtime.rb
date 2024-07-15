# frozen_string_literal: true

module Megatest
  class Runtime
    def initialize(config, result)
      @config = config
      @result = result
    end

    support_locations = begin
      error = StandardError.new
      # Ruby 3.4: https://github.com/ruby/ruby/pull/10017
      error.set_backtrace(caller_locations(1, 1))
      true
    rescue TypeError
      false
    end

    if support_locations
      def assert(uplevel: 1)
        @result.assertions_count += 1
        begin
          yield
        rescue Assertion => failure
          if failure.backtrace.empty?
            failure.set_backtrace(caller_locations(uplevel + 2))
          end
          raise
        end
      end

      def strip_backtrace(error, yield_file, yield_line, downlevel)
        if backtrace = error.backtrace_locations
          rindex = backtrace.rindex { |l| l.lineno == yield_line && l.path == yield_file }
          backtrace = backtrace.slice(0..rindex)
          backtrace.pop(downlevel) unless downlevel.zero?
          error.set_backtrace(backtrace)
        elsif backtrace = error.backtrace
          yield_point = "#{yield_file}:#{yield_line}:"
          rindex = backtrace.rindex { |l| l.start_with?(yield_point) }
          backtrace = backtrace.slice(0..rindex)
          backtrace.pop(downlevel) unless downlevel.zero?
          error.set_backtrace(backtrace)
        end

        error
      end
    else
      def assert(uplevel: 1)
        @result.assertions_count += 1
        begin
          yield
        rescue Assertion => failure
          if failure.backtrace.empty?
            failure.set_backtrace(caller(uplevel + 2))
          end
          raise
        end
      end

      def strip_backtrace(error, yield_file, yield_line, downlevel)
        if backtrace = error.backtrace
          yield_point = "#{yield_file}:#{yield_line}:"
          rindex = backtrace.rindex { |l| l.start_with?(yield_point) }
          backtrace = backtrace.slice(0..rindex)
          backtrace.pop(downlevel) unless downlevel.zero?
          error.set_backtrace(backtrace)
        end

        error
      end
    end

    def expect_no_failures(downlevel: 0)
      yield
    rescue *Megatest::IGNORED_ERRORS
      raise # Exceptions we shouldn't rescue
    rescue Exception => unexpected_error
      error = strip_backtrace(unexpected_error, __FILE__, __LINE__ - 4, downlevel)

      if error.is_a?(Assertion)
        raise error
      else
        raise UnexpectedError, error, EMPTY_BACKTRACE
      end
    end

    EMPTY_BACKTRACE = [].freeze

    def fail(user_message, message)
      if user_message
        user_message = user_message.call if user_message.respond_to?(:call)
        user_message = String(user_message)
        if message && !user_message.end_with?("\n")
          user_message += "\n"
        end
        message = "#{user_message}#{message}"
      end
      raise(Assertion, message, EMPTY_BACKTRACE)
    end

    def pp(object)
      @config.pretty_print(object)
    end

    def diff(expected, actual)
      @config.diff(expected, actual)
    end

    def record_failures(downlevel: 0, &block)
      expect_no_failures(downlevel: downlevel + 1, &block)
      false
    rescue Assertion => assertion
      @result.failures << Failure.new(assertion)
      true
    end
  end
end
