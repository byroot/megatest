# frozen_string_literal: true

require "test_helper"

module Megatest
  class QueueTest < MegaTestCase
    def setup
      load_fixture("simple/simple_test.rb")
      @test_cases = @registry.test_cases
      @test_cases.sort!
      @queue = Queue.new(@test_cases)
    end

    def test_pop_test
      assert_equal "TestedApp::TruthTest#the lie", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the truth", @queue.pop_test&.id
      assert_equal "TestedApp::TruthTest#the unexpected", @queue.pop_test&.id
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
  end
end
