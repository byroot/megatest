# frozen_string_literal: true

module Megatest
  class Runner
    def initialize(config)
      @config = config
    end

    def execute(test_case)
      result = TestCaseResult.new(test_case)
      runtime = Runtime.new(@config, result)
      instance = test_case.klass.new(runtime)
      result.record_time do
        return result if runtime.record_failures { instance.before_setup }

        test_case.each_setup_callback do |callback|
          return result if runtime.record_failures(downlevel: 2) { instance.instance_exec(&callback) }
        end
        return result if runtime.record_failures { instance.setup }
        return result if runtime.record_failures { instance.after_setup }

        return result if test_case.execute(runtime, instance)

        result.complete

        runtime.record_failures do
          instance.before_teardown
        end
        test_case.each_teardown_callback do |callback|
          runtime.record_failures(downlevel: 2) do
            instance.instance_exec(&callback)
          end
        end
        runtime.record_failures do
          instance.teardown
        end
        runtime.record_failures do
          instance.after_teardown
        end
      end
    end
  end
end
