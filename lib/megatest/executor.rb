# frozen_string_literal: true

module Megatest
  class Executor
    class ExternalMonitor
      def initialize(config)
        require "rbconfig"
        @config = config
        spawn
      end

      def reap
        if @pipe
          @pipe.close
          @pipe = nil
          _, status = Process.waitpid2(@pid)
          @pid = nil
          status
        end
      end

      def spawn
        child_read, @pipe = IO.pipe
        ready_pipe, child_write = IO.pipe
        @pid = Process.spawn(
          RbConfig.ruby,
          File.expand_path("../queue_monitor.rb", __FILE__),
          in: child_read,
          out: child_write,
        )
        child_read.close
        Marshal.dump(@config, @pipe)

        # Check the process is alive.
        if ready_pipe.wait_readable(10)
          ready_pipe.gets
          ready_pipe.close
          Process.kill(0, @pid)
        else
          Process.kill(0, @pid)
          Process.wait(@pid)
          raise Error, "ExternalMonitor failed to boot"
        end
      end
    end

    attr_reader :wall_time

    def initialize(config)
      @config = config
    end

    def run(queue, reporters)
      start_time = Megatest.now

      @config.run_global_setup_callbacks
      @config.run_job_setup_callbacks(nil)

      monitor = ExternalMonitor.new(@config) if queue.respond_to?(:heartbeat)

      reporters.each { |r| r.start(self, queue) }

      begin
        while true
          if test_case = queue.pop_test
            reporters.each { |r| r.before_test_case(queue, test_case) }
            result = queue.record_result(test_case.run)
            reporters.each { |r| r.after_test_case(queue, test_case, result) }
          elsif queue.empty?
            break
          else
            # There was no tests to pop, but not all tests are completed.
            # So we stick around to pop tests that could be lost.
            sleep(1)
          end
        end
      rescue Interrupt
        # Early exit
      end

      monitor&.reap

      @wall_time = Megatest.now - start_time
      reporters.each { |r| r.summary(self, queue, queue.summary) }
      queue.cleanup
    end
  end
end
