# frozen_string_literal: true

require "tmpdir"
require "socket"

# :stopdoc:

module Megatest
  # Fairly experimental multi-process queue implementation.
  # It's absolutely not resilient yet, if something goes a bit wrong
  # in may fail in unexpected ways (e.g. hang or whatever).
  # At this stage it's only here to uncover what in the design
  # need to be refactored to make multi-processing and test
  # distribution work well (See the TODOs).
  module MultiProcess
    class << self
      def socketpair
        UNIXSocket.socketpair(:SOCK_STREAM).map { |s| MessageSocket.new(s) }
      end
    end

    class MessageSocket
      def initialize(socket)
        @socket = socket
      end

      def <<(message)
        begin
          @socket.write(Marshal.dump(message))
        rescue Errno::EPIPE, Errno::ENOTCONN
          return nil # Other side was closed
        end
        self
      end

      def read
        Marshal.load(@socket)
      rescue EOFError
        nil # Other side was closed
      end

      def closed?
        @socket.closed?
      end

      def close
        @socket.close
      end

      def to_io
        @socket
      end
    end

    class ClientQueue
      def initialize(socket, test_cases_index)
        @socket = socket
        @test_cases_index = test_cases_index
      end

      def pop_test
        @socket << [:pop]
        if test_id = @socket.read
          @test_cases_index.fetch(test_id)
        end
      end

      def record_result(result)
        @socket << [:record, result]
        @socket.read
      end

      def close
        @socket.close
      end

      def to_io
        @socket.to_io
      end
    end

    class Job
      def initialize(config, index)
        @config = config
        @index = index
        @pid = nil
        @child_socket, @parent_socket = MultiProcess.socketpair
        @assigned_test = nil
        @idle = false
      end

      def run(executor, parent_queue)
        @pid = Process.fork do
          @config.job_index = @index
          @parent_socket.close
          executor.after_fork_in_child(self)

          queue = ClientQueue.new(@child_socket, parent_queue)
          @config.run_job_setup_callbacks(@index)

          runner = Runner.new(@config)

          begin
            while (test_case = queue.pop_test)
              result = runner.execute(test_case)
              result = queue.record_result(result)
              @config.circuit_breaker.record_result(result)
              break if @config.circuit_breaker.break?
            end
          rescue Interrupt
          end
          queue.close

          # We don't want to run at_exit hooks the app may have
          # installed.
          @config.run_job_teardown_callbacks(@index)
          Process.exit!(0)
        end
        @child_socket.close
      end

      def to_io
        @parent_socket.to_io
      end

      def term
        Process.kill(:TERM, @pid)
      rescue Errno::ESRCH
        # Already dead
      end

      def close
        @parent_socket.close
        @child_socket.close
      end

      def closed?
        @parent_socket.closed?
      end

      def idle?
        @idle
      end

      def process(queue, reporters)
        if @idle
          if @assigned_test = queue.pop_test
            @idle = false
            @parent_socket << @assigned_test&.id
          end
          return
        end

        message, *args = @parent_socket.read
        case message
        when nil
          # Socket closed, child probably died
          @parent_socket.close
        when :pop
          if @assigned_test = queue.pop_test
            reporters.each { |r| r.before_test_case(queue, @assigned_test) }
            @parent_socket << @assigned_test&.id
          else
            @idle = true
          end
        when :record
          result = queue.record_result(*args)
          test_case = @assigned_test
          @assigned_test = nil
          @parent_socket << result
          reporters.each { |r| r.after_test_case(queue, test_case, result) }
          @config.circuit_breaker.record_result(result)
        else
          raise "Unexpected message: #{message.inspect}"
        end
      end

      def on_exit(queue, reporters)
        if @assigned_test
          result = queue.record_lost_test(@assigned_test)
          @assigned_test = nil
          reporters.each { |r| r.after_test_case(queue, nil, result) }
        end
      end

      def reap
        Process.wait(@pid)
      end
    end

    class InlineMonitor
      def initialize(config, queue)
        @config = config
        @queue = queue
        @last_heartbeat = 0
      end

      def tick
        now = Megatest.now
        if now - @last_heartbeat > @config.heartbeat_frequency && @queue.heartbeat
          @last_heartbeat = now
        end
      end
    end

    class Executor
      attr_reader :wall_time

      def initialize(config, out, managed: false)
        @config = config
        @out = Output.new(out, colors: config.colors)
        @managed = managed
      end

      def concurrent?
        true
      end

      def after_fork_in_child(active_job)
        @jobs.each do |job|
          job.close unless job == active_job
        end
      end

      def run(queue, reporters)
        start_time = Megatest.now
        @config.run_global_setup_callbacks
        reporters.each { |r| r.start(self, queue) }
        @jobs = @config.jobs_count.times.map { |index| Job.new(@config, index) }

        @config.before_fork_callbacks.each(&:call)
        @jobs.each { |j| j.run(self, queue.test_cases_index) }

        monitor = InlineMonitor.new(@config, queue) if queue.respond_to?(:heartbeat)

        begin
          while true
            monitor&.tick
            dead_jobs = @jobs.select(&:closed?).each { |j| j.on_exit(queue, reporters) }
            @jobs -= dead_jobs
            break if @jobs.empty?
            break if queue.empty?

            @jobs.select(&:idle?).each do |job|
              job.process(queue, reporters)
            end

            reads, = IO.select(@jobs, nil, nil, 1)
            reads&.each do |job|
              job.process(queue, reporters)
            end

            break if @config.circuit_breaker.break?
          end
        rescue Interrupt
          @jobs.each(&:term) # Early exit
        end

        @jobs.each(&:close)
        @jobs.each(&:reap)
        @wall_time = Megatest.now - start_time
        reporters.each { |r| r.summary(self, queue, queue.summary) }

        if @config.circuit_breaker.break? && !@managed
          @out.error("Exited early because too many failures were encountered")
        end

        queue.cleanup
      end
    end
  end
end
