# frozen_string_literal: true

module Megatest
  class AbstractQueue
    class << self
      alias_method :build, :new
      private :new
    end

    attr_reader :test_cases_index, :size

    def initialize(config)
      @config = config
      @size = nil
      @test_cases_index = nil
      @populated = false
    end

    def retrying?
      false
    end

    def summary
      raise NotImplementedError
    end

    def distributed?
      raise NotImplementedError
    end

    def empty?
      raise NotImplementedError
    end

    def remaining_size
      raise NotImplementedError
    end

    def success?
      raise NotImplementedError
    end

    def populated?
      @populated
    end

    def record_lost_test(test)
      record_result(TestCaseResult.new(test).lost)
    end

    def pop_test
      raise NotImplementedError
    end

    def record_result(result)
      raise NotImplementedError
    end

    def populate(test_cases)
      @test_cases_index = test_cases.to_h { |t| [t.id, t] }
      @size = test_cases.size
      @populated = true
    end

    def cleanup
    end
  end

  class Queue < AbstractQueue
    class Summary
      attr_reader :results

      def initialize(results = [])
        @results = results
      end

      # When running distributed queues, it's possible
      # that a test is considered lost and end up with both
      # a successful and a failed result.
      # In such case we turn the failed result into a retry
      # after the fact.
      def deduplicate!
        success = {}
        @results.each do |result|
          if result.success?
            success[result.test_id] = true
          end
        end

        @results.map! do |result|
          if result.bad? && success[result.test_id]
            result.retry
          else
            result
          end
        end
      end

      def assertions_count
        results.sum(0, &:assertions_count)
      end

      def runs_count
        results.size
      end

      def total_time
        results.sum(0.0, &:duration)
      end

      def retries_count
        results.count(&:retried?)
      end

      def failures_count
        results.count(&:failure?)
      end

      def errors_count
        results.count(&:error?)
      end

      def skips_count
        results.count(&:skipped?)
      end

      def failures
        results.reject(&:success?)
      end

      def success?
        !results.empty? && @results.all?(&:ok?)
      end

      def record_result(result)
        @results << result
        result
      end
    end

    attr_reader :summary
    alias_method :global_summary, :summary

    def initialize(config)
      super(config)

      @queue = nil
      @summary = Summary.new
      @success = true
      @retries = Hash.new(0)
      @leases = {}
    end

    def distributed?
      false
    end

    def monitor
      nil
    end

    def empty?
      @queue.empty? && @leases.empty?
    end

    def populate(test_cases)
      super
      @queue = test_cases.reverse
    end

    def remaining_size
      @queue.size + @leases.size
    end

    def success?
      @success && @queue.empty?
    end

    def pop_test
      if test = @queue.pop
        @leases[test.id] = true
      end
      test
    end

    def record_result(result)
      @leases.delete(result.test_id)
      if result.failed?
        if attempt_to_retry(result)
          result = result.retry
        else
          @success = false
        end
      end
      @summary.record_result(result)
      result
    end

    private

    def attempt_to_retry(result)
      return false unless @config.retries?
      return false unless @summary.retries_count < @config.total_max_retries(@size)
      return false unless @retries[result.test_id] < @config.max_retries

      @retries[result.test_id] += 1

      index = @config.random.rand(0..@queue.size)
      @queue.insert(index, test_cases_index.fetch(result.test_id))
      true
    end
  end
end
