# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Reporters
    class AbstractReporter
      undef_method :puts, :print

      def initialize(config, out)
        @config = config
        @out = Output.new(out, colors: config.colors)
      end

      def start(_executor, _queue)
      end

      def before_test_case(_queue, _test_case)
      end

      def after_test_case(_queue, _test_case, _result)
      end

      def summary(_executor, _queue, _summary)
      end

      private

      LABELS = {
        retried: "Retried",
        error: "Error",
        failure: "Failure",
        skipped: "Skipped",
      }.freeze

      def render_failure(result, command: true)
        str = "#{LABELS.fetch(result.status)}: #{result.test_id}\n"
        str = if result.retried? || result.skipped?
          @out.yellow(str)
        else
          @out.red(str)
        end
        str = +str
        str << "\n"

        if result.error?
          str << @out.indent("#{result.failure.cause.name}: #{@out.colored(result.failure.cause.message)}\n")
        elsif result.failed?
          str << @out.indent(@out.colored(result.failure.message.to_s))
        end
        str << "\n" unless str.end_with?("\n")
        str << "\n"

        @config.backtrace.clean(result.failure.backtrace)&.each do |frame|
          str << "  #{@out.cyan(frame)}\n"
        end

        if command
          str << "\n"
          str << @out.yellow(run_command(result))
        end

        str
      end

      def run_command(result)
        "#{@config.program_name} #{Megatest.relative_path(result.test_location)}"
      end
    end
  end
end
