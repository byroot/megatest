# frozen_string_literal: true

module Megatest
  class Executor
    attr_reader :wall_time

    def initialize(config)
      @config = config
    end

    def run(queue, reporters)
      start_time = Megatest.now

      @config.run_global_setup_callbacks
      @config.run_job_setup_callbacks(nil)

      reporters.each { |r| r.start(self, queue) }

      while (test_case = queue.pop_test)
        reporters.each { |r| r.before_test_case(queue, test_case) }
        result = queue.record_result(test_case.run)
        reporters.each { |r| r.after_test_case(queue, test_case, result) }
      end

      @wall_time = Megatest.now - start_time
      reporters.each { |r| r.summary(self, queue) }
    end
  end
end
