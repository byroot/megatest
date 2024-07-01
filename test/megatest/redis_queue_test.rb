# frozen_string_literal: true

require "test_helper"

module Megatest
  class RedisQueueTest < MegaTestCase
    def setup
      super
      @redis_url = ENV.fetch("REDIS_URL", "redis://127.0.0.1/7")
      @redis = RedisClient.new(url: @redis_url)
      @redis.call("flushdb")

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

    private

    def build_queue(worker: 1, build: 1, url: @redis_url)
      RedisQueue.new(worker: worker, build: build, url: url)
    end
  end
end
