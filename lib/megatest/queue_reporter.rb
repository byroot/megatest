# frozen_string_literal: true

# :stopdoc:

module Megatest
  class QueueReporter
    POLL_FREQUENCY = 1

    def initialize(config, queue, out)
      @config = config
      @queue = queue
      @out = out
    end

    def wall_time
      nil
    end

    def wait
      wait_for("Waiting for workers to start") { @queue.populated? }
      wait_for("Waiting for tests to be ran") { @queue.empty? }
    end

    def run(reporters)
      summary = @queue.global_summary
      summary.deduplicate!
      reporters.each { |r| r.summary(self, @queue, summary) }

      @queue.populated? && @queue.empty? && summary.success?
    end

    private

    def wait_for(label)
      unless yield
        @out.puts label
        sleep POLL_FREQUENCY
        sleep POLL_FREQUENCY until yield
      end
    end
  end
end
