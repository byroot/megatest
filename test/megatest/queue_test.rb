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

    private

    def build_queue
      Queue.new(config)
    end

    def config
      @config ||= Config.new({})
    end
  end
end
