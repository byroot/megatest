# frozen_string_literal: true

module Megatest
  class << self
    attr_writer :config

    def config
      yield @config if block_given?
      @config
    end
  end

  class Config
    attr_accessor :queue_url, :retry_tolerance, :max_retries, :jobs_count
    attr_writer :build_id, :worker_id
    attr_reader :before_fork_callbacks, :global_setup_callbacks, :worker_setup_callbacks

    def initialize(env)
      @retry_tolerance = 0.0
      @max_retries = 0
      @queue_url = env["MEGATEST_QUEUE_URL"]
      @build_id = nil
      @worker_id = nil
      @jobs_count = 1
      @before_fork_callbacks = []
      @global_setup_callbacks = []
      @job_setup_callbacks = []
    end

    def run_before_fork_callback
      @before_fork_callback.each { |c| c.call(self) }
    end

    def before_fork(&block)
      @before_fork_callbacks << block
    end

    def run_global_setup_callbacks
      @global_setup_callbacks.each { |c| c.call(self) }
    end

    def global_setup(&block)
      @global_setup_callbacks << block
    end

    def run_job_setup_callbacks(job_index)
      @job_setup_callbacks.each { |c| c.call(self, job_index) }
    end

    def job_setup(&block)
      @job_setup_callbacks << block
    end

    def retries?
      @max_retries.positive?
    end

    def total_max_retries(size)
      if @retry_tolerance.positive?
        (size * @retry_tolerance).ceil
      else
        @max_retries * size
      end
    end

    def build_id
      @build_id or raise InvalidArgument, "Distributed queues require a build-id"
    end

    def worker_id
      @worker_id or raise InvalidArgument, "Distributed queues require a worker-id"
    end
  end

  @config = Config.new({})
end
