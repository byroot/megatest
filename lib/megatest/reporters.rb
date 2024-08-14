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

      def render_failure(result)
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
        str << "\n"

        str << @out.yellow("#{@config.program_name} #{Megatest.relative_path(result.test_location)}")

        str
      end
    end

    class SimpleReporter < AbstractReporter
      def start(_executor, queue)
        @out.puts("Running #{queue.size} test cases with --seed #{@config.seed}")
        @out.puts
      end

      def after_test_case(_queue, _test_case, result)
        if result.skipped?
          @out.print(@out.yellow("S"))
        elsif result.retried?
          @out.print(@out.yellow("R"))
        elsif result.error?
          @out.print(@out.red("E"))
        elsif result.failed?
          @out.print(@out.red("F"))
        else
          @out.print(@out.green("."))
        end
      end

      def summary(executor, _queue, summary)
        @out.puts
        @out.puts

        failures = summary.failures.reject(&:skipped?)
        unless failures.empty?
          failures = failures.sort_by(&:test_id)
          failures.each_with_index do |result, index|
            @out.print "  #{index + 1}) "
            @out.puts render_failure(result)
            @out.puts
          end
        end

        if (wall_time = executor.wall_time.to_f) > 0.0
          @out.puts format(
            "Finished in %.2fs, %d cases/s, %d assertions/s, %.2fs tests runtime.",
            wall_time,
            (summary.runs_count / wall_time).to_i,
            (summary.assertions_count / wall_time).to_i,
            summary.total_time,
          )
        end

        @out.puts format(
          "Ran %d cases, %d assertions, %d failures, %d errors, %d retries, %d skips",
          summary.runs_count,
          summary.assertions_count,
          summary.failures_count,
          summary.errors_count,
          summary.retries_count,
          summary.skips_count,
        )
      end
    end

    class VerboseReporter < SimpleReporter
      def before_test_case(_queue, test_case)
        @out.print("#{test_case.id} = ")
      end

      def after_test_case(_queue, _test_case, result)
        super
        @out.puts
        if result.bad?
          @out.puts @out.colored(render_failure(result))
        end
      end
    end
  end
end
