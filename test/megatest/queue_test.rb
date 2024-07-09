# frozen_string_literal: true

module Megatest
  class QueueTest < MegaTestCase
    def setup
      load_fixture("simple/simple_test.rb")
      @test_cases = @registry.test_cases
      @test_cases.sort!
      @queue = build_queue
      @queue.populate(@test_cases)
    end

    def test_pop_test
      assert_equal "TestedApp::TruthTest#the lie", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the truth", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the unexpected", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the void", @queue.pop_test&.id
      assert_nil @queue.pop_test
    end

    def test_record_result
      assert_equal 0, @queue.runs_count
      assert_equal 0, @queue.failures_count
      assert_equal 0, @queue.errors_count

      result = TestCaseResult.new(@test_cases.first)
      result.record_time do
        result.record_failures do
          raise "oops"
        end
      end
      @queue.record_result(result)

      assert_equal 1, @queue.runs_count
      assert_equal 0, @queue.failures_count
      assert_equal 1, @queue.errors_count
    end

    def test_retry_test
      config.max_retries = 2
      config.retry_tolerance = 1.0

      result = TestCaseResult.new(@test_cases.first)
      result.record_time do
        result.record_failures do
          raise "oops"
        end
      end
      recorded_result = @queue.record_result(result)
      assert_predicate recorded_result, :retried?
    end

    private

    def build_queue
      Queue.new(config)
    end

    def config
      @config ||= Config.new({})
    end
  end
end
