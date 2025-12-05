# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Reporters
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

      def summary(executor, queue, summary)
        @out.puts
        @out.puts

        failures = summary.failures.reject(&:skipped?)
        unless failures.empty?
          failures = failures.sort_by(&:test_id)
          failures.each_with_index do |result, index|
            @out.print "  #{index + 1}) "
            @out.puts render_failure(result: result)
            @out.puts
          end
        end

        # In case of failure we'd rather not print slow tests
        # as it would blur the output.
        if queue.success? && !summary.results.empty?
          sorted_results = summary.results.sort_by(&:duration)
          size = sorted_results.size
          average = sorted_results.sum(&:duration) / size
          median = sorted_results[size / 2].duration
          p90 = sorted_results[(size * 0.9).to_i].duration
          p99 = sorted_results[(size * 0.99).to_i].duration

          @out.puts "Finished in #{s(executor.wall_time.to_f)}, average: #{ms(average)}, median: #{ms(median)}, p90: #{ms(p90)}, p99: #{ms(p99)}"
          cutoff = p90 * 10
          slowest_tests = sorted_results.last(5).select { |r| r.duration > cutoff }
          unless slowest_tests.empty?
            @out.puts "Slowest tests:"
            slowest_tests.reverse_each do |result|
              duration_string = ms(result.duration).rjust(10, " ")
              @out.puts " - #{duration_string} #{@out.yellow(result.test_id)} @ #{@out.cyan(Megatest.relative_path(result.test_location))}"
            end
            @out.puts ""
          end
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

      def s(duration)
        format("%.2fs", duration)
      end

      def ms(duration)
        format("%.1fms", duration * 1000.0)
      end
    end
  end
end
