# frozen_string_literal: true

module Megatest
  class Runner
    def initialize(config)
      @config = config
    end

    def execute(test_case)
      if test_case.tag(:isolated)
        read, write = IO.pipe.each(&:binmode)
        pid = Process.fork do
          read.close
          result = run(test_case)
          Marshal.dump(result, write)
          write.close
        end
        write.close
        result = begin
          Marshal.load(read)
        rescue EOFError
          TestCaseResult.new(test_case).lost
        end
        Process.wait(pid)
        result
      else
        run(test_case)
      end
    end

    def run(test_case)
      result = TestCaseResult.new(test_case)
      runtime = Runtime.new(@config, test_case, result)
      instance = test_case.klass.new(runtime)
      result.record_time do
        return result if runtime.record_failures { instance.before_setup }

        test_case.each_setup_callback do |callback|
          return result if runtime.record_failures(downlevel: 2) { instance.instance_exec(&callback) }
        end
        return result if runtime.record_failures { instance.setup }
        return result if runtime.record_failures { instance.after_setup }

        return result if test_case.execute(runtime, instance)
      ensure
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
