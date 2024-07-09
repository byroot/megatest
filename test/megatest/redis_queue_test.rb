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
