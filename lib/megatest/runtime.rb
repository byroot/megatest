# frozen_string_literal: true

# :stopdoc:

module Megatest
  class Runtime
    attr_reader :config, :test_case, :result, :on_teardown

    def initialize(config, test_case, result)
      @config = config
      @test_case = test_case
      @result = result
      @asserting = false
      @on_teardown = []
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
        if @asserting
          yield
        else
          @asserting = true
          @result.assertions_count += 1
          begin
            yield
          rescue Assertion => failure
            if failure.backtrace.empty?
              failure.set_backtrace(caller_locations(uplevel + 2))
            end
            raise
          ensure
            @asserting = false
          end
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
        if @asserting
          yield
        else
          @asserting = true
          @result.assertions_count += 1
          begin
            yield
          rescue Assertion => failure
            if failure.backtrace.empty?
              failure.set_backtrace(caller(uplevel + 2))
            end
            raise
          ensure
            @asserting = false
          end
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

    def msg(positional, keyword)
      if positional.nil?
        keyword
      elsif !keyword.nil?
        raise ArgumentError, "Can't pass both a positional and keyword assertion message"
      else
        positional # TODO: deprecation mecanism
      end
    end

    def expect_no_failures
      was_asserting = @asserting
      @asserting = false
      yield
    rescue Assertion, *Megatest::IGNORED_ERRORS
      raise # Exceptions we shouldn't rescue
    rescue Exception => unexpected_error
      raise UnexpectedError, unexpected_error, EMPTY_BACKTRACE
    ensure
      @asserting = was_asserting
    end

    EMPTY_BACKTRACE = [].freeze

    def fail(user_message, *message)
      message = build_message(message)
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

    def build_message(strings)
      return if strings.empty?

      if (strings.size + strings.sum(&:size)) < 80
        strings.join(" ")
      else
        strings.join("\n\n")
      end
    end

    def safe_yield
      yield
    rescue Assertion, *IGNORED_ERRORS
      raise
    rescue ::Exception => unexepected_exception
      raise UnexpectedError, unexepected_exception
    end

    UNSET = BasicObject.new

    def unset
      UNSET
    end

    def unset?(arg)
      UNSET.equal?(arg)
    end

    def set?(arg)
      !UNSET.equal?(arg)
    end

    class Expression
      attr_reader :string

      def initialize(string, block)
        @string = string
        @block = block
      end

      def call
        eval(@string, @block.binding)
      end
    end

    def expression(expression, block)
      if String === expression
        Expression.new(expression, block)
      else
        expression
      end
    end

    def minitest_compatibility?
      @config.minitest_compatibility
    end

    def pp(object)
      @config.render_object(object)
    end

    def pp_expression(callable)
      case callable
      when Expression
        callable.string
      when Proc
        # Logic borrowed from Active Support.
        if defined?(RubyVM::InstructionSequence)
          iseq = RubyVM::InstructionSequence.of(callable)
          return pp(callable) unless iseq

          source = if RubyVM::InstructionSequence.method_defined?(:script_lines) && iseq.script_lines
            iseq.script_lines.join("\n")
          elsif File.readable?(iseq.absolute_path)
            File.read(iseq.absolute_path)
          end
          return pp(callable) unless source

          location = iseq.to_a[4][:code_location]
          return pp(callable) unless location

          lines = source.lines[(location[0] - 1)..(location[2] - 1)]
          lines[-1] = lines[-1].byteslice(0...location[3])
          lines[0] = lines[0].byteslice(location[1]...-1)
          source = lines.join.strip

          # Ruby 4.1.0dev includes the `->`
          source.delete_prefix!("->")
          source.strip!

          # We ignore procs defined with do/end as they are likely multi-line anyway.
          if source.start_with?("{")
            source.delete_suffix!("}")
            source.delete_prefix!("{")
            source.strip!
            # It won't read nice if the callable contains multiple
            # lines, and it should be a rare occurrence anyway.
            # Same if it takes arguments.
            if !source.include?("\n") && !source.start_with?("|")
              return source
            end
          end
        end
      end

      pp(callable)
    end

    def diff(expected, actual)
      @config.diff(expected, actual)
    end

    def teardown
      until @on_teardown.empty?
        record_failures do
          @on_teardown.pop.call
        end
      end
    end

    def record_failures(downlevel: 1, &block)
      expect_no_failures(&block)
    rescue Assertion => assertion
      error = assertion
      while error
        error = strip_backtrace(error, __FILE__, __LINE__ - 4, downlevel + 2)
        error = error.cause
      end

      @result.failures << Failure.new(assertion)
      true
    else
      false
    end
  end
end
