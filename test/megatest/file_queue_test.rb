# frozen_string_literal: true

require "megatest/queue_shared_tests"

module Megatest
  class FileQueueTest < MegaTestCase
    def setup
      @config.queue_url = "fixtures/test_order.log"
      load_fixture("simple/simple_test.rb")
      @test_cases = @registry.test_cases
      assert_equal 4, @test_cases.size
      @test_cases.sort!
      @queue = build_queue
      @queue.populate(@test_cases)
    end

    include QueueSharedTests

    def test_pop_test
      tests = []
      while test_case = @queue.pop_test
        tests << test_case.id
      end

      assert_equal File.readlines(@config.queue_url, chomp: true), tests
    end

    private

    def build_queue(config = @config)
      FileQueue.build(config)
    end

    attr_reader :config
  end
end
