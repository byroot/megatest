# frozen_string_literal: true

require "tmpdir"
require "socket"

module Megatest
  # Fairly experimental multi-process queue implementation.
  # It's absolutely not resilient yet, if something goes a bit wrong
  # in may fail in unexpected ways (e.g. hang or whatever).
  # At this stage it's only here to uncover what in the design
  # need to be refactored to make multi-processing and test
  # distribution work well (See the TODOs).
  module MultiProcess
    class MessageSocket
      def initialize(socket)
        @socket = socket
      end

      def <<(message)
        @socket.write(Marshal.dump(message))
      end

      def read
        Marshal.load(@socket)
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
      def initialize(socket)
        @socket = socket
      end

      def pop_test
        @socket << [:pop]
        if test_id = @socket.read
          Megatest.registry[test_id] # TODO: refactor this
        end
      end

      def record_result(result)
        result.instance_variable_set(:@test_case, nil) # TODO: proper serialization
        @socket << [:record, result]
        @socket.read # TODO: really necessary?
      end

      def close
        @socket.close
      end

      def to_io
        @socket.to_io
      end
    end

    class Worker
      def initialize(index)
        @index = index
        @pid = nil
        @child_socket, @parent_socket = UNIXSocket.socketpair(:SOCK_STREAM).map { |s| MessageSocket.new(s) }
      end

      def run
        @pid = Process.fork do
          @parent_socket.close
          queue = ClientQueue.new(@child_socket)

          while (test_case = queue.pop_test)
            result = test_case.run
            queue.record_result(result)
          end

          Megatest::Executor.new.run(queue, [])
          queue.close
        end
        @child_socket.close
      end

      def to_io
        @parent_socket.to_io
      end

      def close
        @parent_socket.close
        @child_socket.close
      end

      def closed?
        @parent_socket.closed?
      end

      def process(queue, reporters)
        message, *args = @parent_socket.read
        case message
        when :pop
          @parent_socket << queue.pop_test&.id
        when :record
          result = queue.record_result(*args)
          @parent_socket << result
          reporters.each { |r| r.after_test_case(queue, nil, result) }
        else
          raise "Unexpected message: #{message.inspect}"
        end
      rescue EOFError
        @parent_socket.close
      end

      def reap
        Process.wait(@pid)
      end
    end

    class Executor
      attr_reader :wall_time

      def initialize(workers_count)
        @workers_count = workers_count
      end

      def run(queue, reporters)
        start_time = Megatest.now
        @workers = @workers_count.times.map { |index| Worker.new(index) }
        @workers.each(&:run)

        until @workers.all?(&:closed?)
          reads, = IO.select(@workers.reject(&:closed?))
          reads.each do |worker|
            worker.process(queue, reporters)
          end
        end

        @workers.each(&:close)
        @workers.each(&:reap)
        @wall_time = Megatest.now - start_time
        reporters.each { |r| r.summary(self, queue) }
      end
    end
  end
end
