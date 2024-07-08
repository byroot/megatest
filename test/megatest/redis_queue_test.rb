# frozen_string_literal: true

module Megatest
  class RedisQueueTest < MegaTestCase
    def setup
      super
      setup_redis

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

    def test_concurrent_pop_test
      assert_predicate @queue, :leader?

      other_worker = build_queue(worker: 1)
      other_worker.populate(@test_cases)
      refute_predicate other_worker, :leader?

      assert_equal "TestedApp::TruthTest#the lie", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the truth", other_worker.pop_test&.id
      assert_equal "TestedApp::TruthTest#the unexpected", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the void", @queue.pop_test&.id
      assert_nil @queue.pop_test
    end

    def test_record_result
      assert_equal 0, @queue.runs_count
      assert_equal 0, @queue.failures_count
      assert_equal 0, @queue.errors_count

      result = TestCaseResult.new(@test_cases.first)
      result.record do
        raise "oops"
      end
      @queue.record_result(result)

      assert_equal 1, @queue.runs_count
      assert_equal 0, @queue.failures_count
      assert_equal 1, @queue.errors_count
    end

    def test_retry_test
      config.max_retries = 2
      config.retry_tolerance = 1.0
      @queue = build_queue
      @queue.populate(@test_cases)

      result = TestCaseResult.new(@test_cases.first)
      result.record do
        raise "oops"
      end
      recorded_result = @queue.record_result(result)
      assert_predicate recorded_result, :retried?
    end

    private

    def build_queue(worker: nil, build: nil)
      queue_config = config.dup
      queue_config.worker_id = worker if worker
      queue_config.build_id = build if build
      RedisQueue.new(queue_config)
    end

    def config
      @config ||= begin
        config = Config.new({})
        config.queue_url = @redis_url
        config.worker_id = 1
        config.build_id = 1
        config
      end
    end
  end
end
