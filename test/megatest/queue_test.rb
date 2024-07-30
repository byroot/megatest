# frozen_string_literal: true

require "megatest/queue_shared_tests"

module Megatest
  class QueueTest < MegaTestCase
    def setup
      load_fixture("simple/simple_test.rb")
      @test_cases = @registry.test_cases
      assert_equal 4, @test_cases.size
      @test_cases.sort!
      @queue = build_queue
      @queue.populate(@test_cases)
    end

    include QueueSharedTests

    test "sharding" do
      queues = 3.times.map do |index|
        config = @config.dup
        config.workers_count = 3
        config.worker_id = index
        build_queue(config)
      end

      queues.each do |queue|
        assert_predicate queue, :sharded?
        queue.populate(@test_cases)
      end
      assert_equal @test_cases.size, queues.sum(&:size)

      queued_tests = []
      queues.each do |queue|
        while test_case = queue.pop_test
          queued_tests << test_case
        end
      end

      assert_equal @test_cases, queued_tests.sort
    end

    private

    def build_queue(config = @config)
      Queue.build(config)
    end

    attr_reader :config
  end
end
