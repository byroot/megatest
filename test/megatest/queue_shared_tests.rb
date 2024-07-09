# frozen_string_literal: true

module Megatest
  module QueueSharedTests
    def test_remmaining_size
      poped_cases = []
      assert_equal 4, @queue.remaining_size
      poped_cases << @queue.pop_test
      assert_equal 4, @queue.remaining_size
      poped_cases << @queue.pop_test
      assert_equal 4, @queue.remaining_size

      @queue.record_result(build_success(poped_cases.pop))
      assert_equal 3, @queue.remaining_size

      @queue.record_result(build_success(poped_cases.pop))
      assert_equal 2, @queue.remaining_size
    end

    def test_pop_test
      assert_equal "TestedApp::TruthTest#the lie", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the truth", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the unexpected", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the void", @queue.pop_test&.id
      assert_nil @queue.pop_test
    end

    def test_record_result
      assert_equal 0, @queue.summary.runs_count
      assert_equal 0, @queue.summary.failures_count
      assert_equal 0, @queue.summary.errors_count

      @queue.record_result(build_error(@test_cases.first))

      assert_equal 1, @queue.summary.runs_count
      assert_equal 0, @queue.summary.failures_count
      assert_equal 1, @queue.summary.errors_count
    end

    def test_retry_test
      config.max_retries = 2
      config.retry_tolerance = 1.0
      @queue = build_queue
      @queue.populate(@test_cases)

      recorded_result = @queue.record_result(build_error(@test_cases.first))
      assert_predicate recorded_result, :retried?
    end
  end
end
