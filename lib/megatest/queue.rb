# frozen_string_literal: true

module Megatest
  class Queue
    attr_reader :size, :assertions_count, :runs_count, :failures_count, :errors_count, :skips_count, :total_time

    def initialize(test_cases)
      @size = test_cases.size
      @test_cases = test_cases.reverse
      @success = true
      @failures = []
      @runs_count = @assertions_count = @failures_count = @errors_count = @skips_count = 0
      @total_time = 0.0
    end

    def success?
      @success
    end

    def pop_test
      @test_cases.pop
    end

    def record_result(result)
      @runs_count += 1
      if result.failed?
        @success = false
        @failures << result
        if result.error?
          @errors_count += 1
        else
          @failures_count += 1
        end
      end
      @assertions_count += result.assertions_count
      @total_time += result.duration
      result
    end
  end
end
