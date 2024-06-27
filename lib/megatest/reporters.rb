# frozen_string_literal: true

module Megatest
  class AbstractReporter
    undef_method :puts, :print

    def start(_queue)
    end

    def before_test_case(_queue, _test_case)
    end

    def after_test_case(_queue, _test_case, _result)
    end

    def summary(_queue)
    end
  end

  class SimpleReporter < AbstractReporter
    def initialize(out)
      super()
      @out = out
      @failures = []
    end

    def start(queue)
      @out.puts("Running #{queue.size} test cases with --seed #{Megatest.seed.seed}")
    end

    def after_test_case(_queue, _test_case, result)
      if result.error?
        @out.print("E")
        @failures << result
      elsif result.failed?
        @out.print("F")
        @failures << result
      else
        @out.print(".")
      end
    end

    LABELS = {
      error: "Error",
      failure: "Failure",
    }.freeze

    def render_failure(result)
      str = "#{LABELS.fetch(result.status)}: #{result.test_id}"
      if (location = result.test_source_location)
        str << " [#{Megatest.relative_path(location.join(":"))}]"
      end
      str << "\n"

      if result.error?
        str << "#{result.failure.cause.class}: #{result.failure.cause.message}\n"
      end

      Backtrace.clean(result.failure.backtrace).each do |frame|
        str << "  #{frame}\n"
      end

      str
    end

    def summary(queue)
      @out.puts
      @out.puts

      unless @failures.empty?
        @failures.sort_by!(&:test_id)
        @failures.each do |result|
          @out.puts render_failure(result)
          @out.puts
        end
      end

      total_time = queue.total_time
      if total_time > 0.0
        @out.puts format(
          "Finished in %.2fs, %d cases/s, %d assertions/s.",
          queue.total_time,
          (queue.runs_count / queue.total_time).to_i,
          (queue.assertions_count / total_time).to_i,
        )
      end

      @out.puts format(
        "Ran %d cases, %d assertions, %d failures, %d errors, %d skips",
        queue.runs_count,
        queue.assertions_count,
        queue.failures_count,
        queue.errors_count,
        queue.skips_count,
      )
    end
  end
end
