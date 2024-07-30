# frozen_string_literal: true

module Megatest
  class << self
    attr_writer :config

    def config
      yield @config if block_given?
      @config
    end
  end

  class CircuitBreaker
    def initialize(max)
      @max = max
      @consecutive_failures = 0
    end

    def record_result(result)
      if result.bad?
        @consecutive_failures += 1
      elsif result.success?
        @consecutive_failures = 0
      end
    end

    def break?
      @consecutive_failures >= @max
    end
  end

  class CIService
    @implementations = []

    class << self
      def inherited(base)
        super
        @implementations << base
      end

      def configure(config, env)
        @implementations.each do |service|
          service.new(env).configure(config)
        end
      end
    end

    attr_reader :env

    def initialize(env)
      @env = env
    end

    def configure(_config)
      raise NotImplementedError
    end

    class CircleCI < self
      def configure(config)
        if env["CIRCLE_BUILD_URL"]
          config.build_id = env["CIRCLE_BUILD_URL"]
          config.worker_id = env["CIRCLE_NODE_INDEX"]
          config.workers_count = Integer(env["CIRCLE_NODE_TOTAL"])
          config.seed = env["CIRCLE_SHA1"]&.first(4)&.to_i(16)
        end
      end
    end

    class Buildkite < self
      def configure(config)
        if env["BUILDKITE_BUILD_ID"]
          config.build_id = env["BUILDKITE_BUILD_ID"]
          config.worker_id = env["BUILDKITE_PARALLEL_JOB"]
          config.workers_count = env["BUILDKITE_PARALLEL_JOB_COUNT"]
          config.seed = env["BUILDKITE_COMMIT"]&.first(4)&.to_i(16)
        end
      end
    end

    class Travis < self
      def configure(config)
        if env["TRAVIS_BUILD_ID"]
          config.build_id = env["TRAVIS_BUILD_ID"]
          # Travis doesn't have builtin parallelization
          # but CI_NODE_INDEX is what is used in their documentation
          # https://docs.travis-ci.com/user/speeding-up-the-build#parallelizing-rspec-cucumber-and-minitest-on-multiple-vms
          config.worker_id = env["CI_NODE_INDEX"]
          config.workers_count = env["CI_NODE_TOTAL"]
          config.seed = env["TRAVIS_COMMIT"]&.first(4)&.to_i(16)
        end
      end
    end

    class Heroku < self
      def configure(config)
        if env["HEROKU_TEST_RUN_ID"]
          config.build_id = env["HEROKU_TEST_RUN_ID"]
          config.worker_id = env["CI_NODE_INDEX"]
          config.workers_count = env["CI_NODE_TOTAL"]
          config.seed = env["HEROKU_TEST_RUN_COMMIT_VERSION"]&.first(4)&.to_i(16)
        end
      end
    end

    class Megatest < self
      def configure(config)
        if url = env["MEGATEST_QUEUE_URL"]
          config.queue_url = url
        end

        if id = env["MEGATEST_BUILD_ID"]
          config.build_id = id
        end

        if id = env["MEGATEST_WORKER_ID"]
          config.worker_id = id
        end

        if seed = env["SEED"]
          config.seed = seed
        end
      end
    end
  end

  class Config
    attr_accessor :queue_url, :retry_tolerance, :max_retries, :jobs_count, :job_index, :load_paths, :deprecations,
                  :build_id, :heartbeat_frequency, :program_name, :minitest_compatibility
    attr_reader :before_fork_callbacks, :global_setup_callbacks, :worker_setup_callbacks, :backtrace, :circuit_breaker, :seed,
                :worker_id, :workers_count
    attr_writer :differ, :pretty_printer

    def initialize(env)
      @load_paths = ["test"] # For easier transition from other frameworks
      @retry_tolerance = 0.0
      @max_retries = 0
      @deprecations = true
      @full_backtrace = false
      @queue_url = env["MEGATEST_QUEUE_URL"]
      @build_id = nil
      @worker_id = nil
      @workers_count = 1
      @jobs_count = 1
      @colors = nil # auto
      @before_fork_callbacks = []
      @global_setup_callbacks = []
      @job_setup_callbacks = []
      @heartbeat_frequency = 5
      @backtrace = Backtrace.new
      @program_name = "megatest"
      @circuit_breaker = CircuitBreaker.new(Float::INFINITY)
      @seed = Random.rand(0xFFFF)
      @differ = Differ.new(self)
      @pretty_printer = PrettyPrint.new(self)
      @minitest_compatibility = false
      CIService.configure(self, env)
    end

    def worker_id=(id)
      @worker_id = if id.is_a?(String) && /\A\d+\z/.match?(id)
        Integer(id)
      else
        id
      end
    end

    def workers_count=(count)
      @workers_count = count ? Integer(count) : 1
    end

    def valid_worker_index?
      worker_id.is_a?(Integer) && worker_id.positive? && worker_id < workers_count
    end

    def colors(io = nil)
      case @colors
      when true
        Output::ANSIColors
      when false
        Output::NoColors
      else
        if io && !io.tty?
          Output::NoColors
        else
          Output::ANSIColors
        end
      end
    end

    def max_consecutive_failures=(max)
      @circuit_breaker = CircuitBreaker.new(max)
    end

    def diff(expected, actual)
      @differ&.call(expected, actual)
    end

    def pretty_print(object)
      @pretty_printer.pretty_print(object)
    end
    alias_method :pp, :pretty_print

    # We always return a new generator with the same seed as to
    # best reproduce remote builds locally if the same seed is given.
    def random
      Random.new(@seed)
    end

    def seed=(seed)
      @seed = Integer(seed)
    end

    def build_queue
      case @queue_url
      when nil
        Queue.build(self)
      when /\Arediss?:/
        require "megatest/redis_queue"
        RedisQueue.build(self)
      else
        raise ArgumentError, "Unsupported queue type: #{@queue_url.inspect}"
      end
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
  end

  @config = Config.new({})
end
