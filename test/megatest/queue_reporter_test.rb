# frozen_string_literal: true

module Megatest
  class QueueReporterTest < MegaTestCase
    def setup
      load_fixture("simple/simple_test.rb")
      @test_cases = @registry.test_cases
      assert_equal 4, @test_cases.size
      @test_cases.sort!
      @config = Config.new({})
      @queue = Queue.new(@config)
      @queue.populate(@test_cases)
      @out = StringIO.new
      @reporter = QueueReporter.new(@config, @queue, @out)
    end

    def test_run_not_empty
      assert_equal false, @reporter.run([])
    end

    def test_run_empty_success
      @queue.size.times do
        test_case = @queue.pop_test
        @queue.record_result(build_success(test_case))
      end

      assert_equal true, @reporter.run([])
    end

    def test_run_empty_failure
      @queue.size.times do
        test_case = @queue.pop_test
        @queue.record_result(build_failure(test_case))
      end

      assert_equal false, @reporter.run([])
    end
  end
end
