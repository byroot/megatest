# frozen_string_literal: true

require "megatest/queue_shared_tests"

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

    include QueueSharedTests

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

    def test_global_summary
      assert_equal 0, @queue.global_summary.runs_count
      assert_equal 0, @queue.global_summary.failures_count
      assert_equal 0, @queue.global_summary.errors_count

      @queue.record_result(build_error(@test_cases[0]))
      summary = @queue.global_summary
      assert_equal 1, summary.runs_count
      assert_equal 0, summary.failures_count
      assert_equal 1, summary.errors_count

      other_worker = build_queue(worker: 1)
      other_worker.populate(@test_cases)

      @queue.record_result(build_failure(@test_cases[1]))
      summary = @queue.global_summary
      assert_equal 2, summary.runs_count
      assert_equal 1, summary.failures_count
      assert_equal 1, summary.errors_count

      @queue.record_result(build_success(@test_cases[2]))
      summary = @queue.global_summary
      assert_equal 3, summary.runs_count
      assert_equal 1, summary.failures_count
      assert_equal 1, summary.errors_count
      assert_equal 4, summary.assertions_count

      assert_equal 3, summary.results.size
      assert_equal 2, summary.failures.size

      # Append a success report for a test that already failed
      @queue.record_result(build_success(@test_cases[1]))
      summary = @queue.global_summary
      summary.deduplicate!
      assert_equal 4, summary.runs_count
      assert_equal 0, summary.failures_count
      assert_equal 1, summary.errors_count

      # Append a failure report for a test that already succeeded
      @queue.record_result(build_failure(@test_cases[2]))
      summary = @queue.global_summary
      summary.deduplicate!
      assert_equal 5, summary.runs_count
      assert_equal 0, summary.failures_count
      assert_equal 1, summary.errors_count
    end

    def test_heartbeat
      poped_tests = 2.times.map { @queue.pop_test }

      running_key = @queue.send(:key, "running")
      first_deadline, second_deadline = @redis.call("zmscore", running_key, poped_tests.map(&:id))
      assert_instance_of Float, first_deadline
      assert_instance_of Float, second_deadline

      stub_time(10) do
        @queue.heartbeat
      end

      first, second = @redis.call("zmscore", running_key, poped_tests.map(&:id))
      assert first > first_deadline
      assert second > second_deadline
    end

    def test_reserve_lost_test
      assert_predicate @queue, :leader?

      other_worker = build_queue(worker: 1)
      other_worker.populate(@test_cases)
      refute_predicate other_worker, :leader?

      refute_nil test = @queue.pop_test
      stub_time(@config.heartbeat_frequency * 3) do
        assert_equal test, other_worker.pop_test
      end
    end

    def test_retry_queue
      failed_tests = []
      failed_tests << (test = @queue.pop_test)
      @queue.record_result(build_failure(test))

      failed_tests << (test = @queue.pop_test)
      @queue.record_result(build_error(test))

      while test = @queue.pop_test
        @queue.record_result(build_success(test))
      end

      assert_predicate @queue, :empty?
      refute_predicate @queue, :success?
      @queue.cleanup

      retry_queue = RedisQueue.build(@config)
      assert_instance_of RedisQueue::RetryQueue, retry_queue
      retry_queue.populate(@test_cases)

      retried_tests = []
      while test = retry_queue.pop_test
        retried_tests << test
        retry_queue.record_result(build_success(test))
      end

      assert_equal failed_tests, retried_tests

      assert_predicate retry_queue, :empty?
      assert_predicate retry_queue, :success?

      @queue = build_queue
      assert_predicate @queue, :success?
    end

    private

    def build_queue(worker: nil, build: nil)
      queue_config = config.dup
      queue_config.worker_id = worker if worker
      queue_config.build_id = build if build
      RedisQueue.build(queue_config)
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
