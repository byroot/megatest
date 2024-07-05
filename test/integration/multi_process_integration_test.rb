# frozen_string_literal: true

require "test_helper"

module Megatest
  class MultiProcessIntegrationTest < MegaTestCase
    class RecordReporter < Reporters::AbstractReporter
      attr_reader :results

      def initialize
        super
        @results = []
      end

      def after_test_case(_queue, _test_case, result)
        @results << result
      end
    end

    def test_crashing_test_case
      load_fixture("crash/crash_test.rb")

      config = Config.new({})
      config.jobs_count = 2
      queue = build_queue(config)

      reporter = RecordReporter.new

      executor = MultiProcess::Executor.new(config)
      executor.run(queue, [reporter])

      refute_predicate queue, :success?
      assert_equal 1, queue.failures_count

      assert_equal 11, reporter.results.size
      assert_equal 1, queue.failures_count
      assert_equal 0, queue.retries_count

      refute_nil crash_result = reporter.results.find { |r| r.test_id == "TestedApp::CrashTest#crash" }
      assert_instance_of LostTest, crash_result.failure
    end

    def test_crashing_test_case_with_retry
      load_fixture("crash/crash_test.rb")

      config = Config.new({})
      config.jobs_count = 4
      config.max_retries = 1
      queue = build_queue(config)

      reporter = RecordReporter.new

      executor = MultiProcess::Executor.new(config)
      executor.run(queue, [reporter])

      refute_predicate queue, :success?

      assert_equal 1, queue.failures_count

      assert_equal 12, reporter.results.size

      crash_results = reporter.results.select { |r| r.test_id == "TestedApp::CrashTest#crash" }
      assert_equal 2, crash_results.size
      crash_results.each do |crash_result|
        assert_instance_of LostTest, crash_result.failure
      end
      assert_equal [true, false], crash_results.map(&:retried?)
      assert_equal 1, queue.failures_count
      assert_equal 1, queue.retries_count
    end

    def test_crashing_all_jobs
      load_fixture("crash/crash_test.rb")

      config = Config.new({})
      config.jobs_count = 1
      config.max_retries = 1
      queue = build_queue(config)

      reporter = RecordReporter.new

      executor = MultiProcess::Executor.new(config)
      executor.run(queue, [reporter])

      assert_equal 1, queue.retries_count
      assert_equal 0, queue.failures_count
      assert_equal 0, queue.errors_count
      refute_predicate queue, :success?
      assert_predicate queue.remaining_size, :positive?
    end

    def test_redis_queue
      setup_redis

      load_fixture("crash/crash_test.rb")

      config = Config.new({})
      config.queue_url = @redis_url
      config.worker_id = 1
      config.build_id = 1
      config.jobs_count = 4
      config.max_retries = 1
      queue = build_queue(config)

      reporter = RecordReporter.new

      executor = MultiProcess::Executor.new(config)
      executor.run(queue, [reporter])

      refute_predicate queue, :success?

      assert_equal 1, queue.failures_count

      assert_equal 12, reporter.results.size

      crash_results = reporter.results.select { |r| r.test_id == "TestedApp::CrashTest#crash" }
      assert_equal 2, crash_results.size
      crash_results.each do |crash_result|
        assert_instance_of LostTest, crash_result.failure
      end
      assert_equal [true, false], crash_results.map(&:retried?)
      assert_equal 1, queue.failures_count
      assert_equal 1, queue.retries_count
    end

    private

    def build_queue(config, implementation = Queue)
      test_cases = @registry.test_cases
      test_cases.sort!
      queue = implementation.new(config)
      queue.populate(test_cases)
      queue
    end
  end
end
