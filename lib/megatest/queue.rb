# frozen_string_literal: true

module Megatest
  class QueueConfig
    attr_accessor :retry_tolerance, :max_retries

    def initialize
      @retry_tolerance = 0.0
      @max_retries = 0
    end

    def retries?
      @max_retries.positive?
    end

    def total_max_retries(size)
      if @retry_tolerance.positive?
        (size * @retry_tolerance).ceil
      else
        @max_retries * size
      end
    end
  end

  class Queue
    attr_reader :size, :assertions_count, :runs_count, :failures_count, :errors_count, :retries_count, :skips_count,
                :total_time

    def initialize(config)
      @config = config
      @size = 0
      @test_cases = nil
      @success = true
      @failures = []
      @runs_count = @assertions_count = @failures_count = @errors_count = @retries_count = @skips_count = 0
      @total_time = 0.0
      @retries = Hash.new(0)
    end

    def populate(test_cases)
      @size = test_cases.size
      @test_cases = test_cases.reverse
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
        if attempt_to_retry(result)
          result = result.retry
          @failures << result
          @retries_count += 1
        else
          @success = false
          @failures << result
          if result.error?
            @errors_count += 1
          else
            @failures_count += 1
          end
        end
      end
      @assertions_count += result.assertions_count
      @total_time += result.duration
      result
    end

    private

    def attempt_to_retry(result)
      return false unless @config.retries?
      return false unless @retries_count < @config.total_max_retries(@size)
      return false unless @retries[result.test_id] < @config.max_retries

      @retries[result.test_id] += 1

      index = Megatest.seed.rand(0..@test_cases.size)
      @test_cases.insert(index, Megatest.registry[result.test_id])
      true
    end
  end
end
