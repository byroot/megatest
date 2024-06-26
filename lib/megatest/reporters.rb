# frozen_string_literal: true

module Megatest
  class AbstractReporter
    undef_method :puts, :print

    def start(_executor)
    end

    def before_test_case(_executor, _test_case)
    end

    def after_test_case(_executor, _test_case, _result)
    end

    def summary(_executor)
    end

    private

    def now
      Process.clock_gettime(Process::CLOCK_REALTIME)
    end
  end

  class SuccessReporter < AbstractReporter
    def initialize
      super
      @passed = true
    end

    def passed?
      @passed
    end

    def after_test_case(_executor, _test_case, result)
      @passed = false if result.failed?
    end
  end

  class SimpleReporter < AbstractReporter
    def initialize(out)
      super()
      @out = out
      @start_time = now
      @assertions_count = 0
      @failures_count = 0
      @errors_count = 0
      @cases_count = 0
      @skips_count = 0
    end

    def start(executor)
      @out.puts("Running #{executor.test_cases.size} test cases with --seed #{Megatest.seed.seed}")
    end

    def before_test_case(executor, test_case)
    end

    def after_test_case(_executor, _test_case, result)
      @cases_count += 1
      @assertions_count += result.assertions

      if result.error?
        @errors_count += 1
        @out.print("E")
      elsif result.failed?
        @failures_count += 1
        @out.print("F")
      else
        @out.print(".")
      end
    end

    def summary(_executor)
      @out.puts
      @out.puts

      total_time = now - @start_time
      @out.puts format(
        "Finished in %.2fs, %d cases/s, %d assertions/s.",
        total_time,
        (@cases_count / total_time).to_i,
        (@assertions_count / total_time).to_i,
      )

      @out.puts format(
        "%d cases, %d assertions, %d failures, %d errors, %d skips",
        @cases_count,
        @assertions_count,
        @failures_count,
        @errors_count,
        @skips_count,
      )
    end
  end
end
