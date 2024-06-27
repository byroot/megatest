# frozen_string_literal: true

module Megatest
  class Executor
    def initialize(queue, reporters)
      @queue = queue
      @reporters = reporters
    end

    def run
      @reporters.each { |r| r.start(@queue) }

      while (test_case = @queue.pop_test)
        @reporters.each { |r| r.before_test_case(@queue, test_case) }
        result = @queue.record_result(test_case.run)
        @reporters.each { |r| r.after_test_case(@queue, test_case, result) }
      end

      @reporters.each { |r| r.summary(@queue) }
    end
  end
end
