# frozen_string_literal: true

# :stopdoc:

module Megatest
  class QueueMonitor
    class << self
      def run(stdin, stdout)
        config = Marshal.load(stdin)
        stdout.puts("ready")
        stdout.close
        new(config, stdin).run
      end
    end

    def initialize(config, stdin)
      @config = config
      @in = stdin
    end

    def run
      queue = @config.build_queue
      queue.heartbeat

      queue.heartbeat until @in.wait_readable(@config.heartbeat_frequency)

      0
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  require "megatest"
  exit(Megatest::QueueMonitor.run($stdin, $stdout))
end
