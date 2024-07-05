# frozen_string_literal: true

module Megatest
  class QueueConfig
    attr_accessor :url, :retry_tolerance, :max_retries
    attr_writer :build_id, :worker_id

    def initialize
      @retry_tolerance = 0.0
      @max_retries = 0
      @url = nil
      @build_id = nil
      @worker_id = nil
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

    def build_id
      @build_id or raise InvalidArgument, "Distributed queues require a build-id"
    end

    def worker_id
      @worker_id or raise InvalidArgument, "Distributed queues require a worker-id"
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
      @test_cases_index = nil
    end

    def test_cases_index
      @test_cases_index ||= @test_cases.to_h { |t| [t.id, t] }
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
      @test_cases.insert(index, test_cases_index.fetch(result.test_id))
      true
    end
  end
end
