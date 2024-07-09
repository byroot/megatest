# frozen_string_literal: true

module Megatest
  module Reporters
    class Output
      def initialize(io)
        @io = io
        @tty = io.tty?
      end

      def print(*args)
        @io.print(*args)
      end

      def puts(*args)
        @io.puts(*args)
      end

      def red(text)
        colorize(text, 31)
      end

      def green(text)
        colorize(text, 32)
      end

      def yellow(text)
        colorize(text, 33)
      end

      def blue(text)
        colorize(text, 34)
      end

      def magenta(text)
        colorize(text, 35)
      end

      def cyan(text)
        colorize(text, 36)
      end

      private

      def colorize(text, color_code)
        if @tty
          "\e[#{color_code}m#{text}\e[0m"
        else
          text
        end
      end
    end

    class AbstractReporter
      undef_method :puts, :print

      def start(_executor, _queue)
      end

      def before_test_case(_queue, _test_case)
      end

      def after_test_case(_queue, _test_case, _result)
      end

      def summary(_executor, _queue, _summary)
      end
    end

    class SimpleReporter < AbstractReporter
      def initialize(out, config = {})
        super()
        @out = Output.new(out)
        @program_name = config[:program_name] || "megatest"
      end

      def start(_executor, queue)
        @out.puts("Running #{queue.size} test cases with --seed #{Megatest.seed.seed}")
        @out.puts
      end

      def after_test_case(_queue, _test_case, result)
        if result.retried?
          @out.print(@out.yellow("R"))
        elsif result.error?
          @out.print(@out.red("E"))
        elsif result.failed?
          @out.print(@out.red("F"))
        else
          @out.print(@out.green("."))
        end
      end

      LABELS = {
        retried: "Retried",
        error: "Error",
        failure: "Failure",
      }.freeze

      def render_failure(result)
        str = "#{LABELS.fetch(result.status)}: #{result.test_id}\n"
        str = if result.retried?
          @out.yellow(str)
        else
          @out.red(str)
        end
        str = +str

        if result.error?
          str << "#{result.failure.cause.name}: #{result.failure.cause.message}\n"
        elsif result.failed?
          str << result.failure.message.to_s
        end
        str << "\n" unless str.end_with?("\n")

        Backtrace.clean(result.failure.backtrace)&.each do |frame|
          str << "  #{@out.cyan(frame)}\n"
        end
        str << "\n"

        str << @out.yellow("#{@program_name} #{Megatest.relative_path(result.test_location)}")

        str
      end

      def summary(executor, _queue, summary)
        @out.puts
        @out.puts

        unless summary.failures.empty?
          failures = summary.failures.sort_by(&:test_id)
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
  end
end
