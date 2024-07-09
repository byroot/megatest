# frozen_string_literal: true

require "optparse"
require "megatest/selector"

module Megatest
  class CLI
    InvalidArgument = Class.new(ArgumentError)

    class << self
      def run!
        exit(new($PROGRAM_NAME, $stdout, $stderr, ARGV, ENV).run)
      end
    end

    undef_method :puts, :print # Should only use @out.puts or @err.puts

    def initialize(program_name, out, err, argv, env)
      @program_name = program_name
      @out = out
      @err = err
      @argv = argv.dup
      @processes = nil
      @config = Config.new(env)
    end

    def run
      Megatest.config = @config
      parser.parse!(@argv)

      # TODO: need to move queue argument validation here
      # e.g. distributed queues need a `--worker-id` for running tests
      # but not for the summary.
      case @argv.first
      when "report"
        report
      else
        run_tests
      end
    rescue InvalidArgument => error
      @err.puts "Invalid arguments: #{error.message}"
      @err.puts
      @err.puts parser
      1
    end

    def run_tests
      if queue.distributed?
        raise ArgumentError, "Distributed queues require a build-id" unless @config.build_id
        raise ArgumentError, "Distributed queues require a worker-id" unless @config.worker_id
      end

      selectors = Selector.parse(@argv)

      registry = Megatest.with_registry do
        Megatest.load_config(selectors.paths)
        Megatest.append_load_path(@config)
        Megatest.load_suites(selectors.paths)
      end
      test_cases = selectors.select(registry)

      # TODO: figure out when to shuffle. E.g. if passing file:line file:line we want to keep the order
      # but file, file we want to shuffle. It also should just be a default we should be able to flip it
      # with CLI arguments.
      test_cases.sort!
      test_cases.shuffle!(random: Megatest.seed)

      queue.populate(test_cases)
      executor.run(queue, default_reporters)
      queue.success? ? 0 : 1
    end

    def report
      raise ArgumentError, "Only distributed queues can be summarized" unless queue.distributed?
      raise ArgumentError, "Distributed queues require a build-id" unless @config.build_id

      QueueReporter.new(@config, queue, @out).run(default_reporters) ? 0 : 1
    end

    private

    def queue
      @queue ||= @config.build_queue
    end

    def default_reporters
      [
        Reporters::SimpleReporter.new(@out, program_name: @program_name),
      ]
    end

    def executor
      if @config.jobs_count > 1
        require "megatest/multi_process"
        MultiProcess::Executor.new(@config)
      else
        Executor.new(@config)
      end
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = <<~HELP
          Usage: #{@program_name} [SUBCOMMAND] [ARGS...]"

          GLOBAL OPTIONS
        HELP

        opts.separator ""

        opts.on("--seed=SEED", Integer, "The seed used to define run order") do |seed|
          Megatest.seed = Random.new(seed)
        end

        opts.on("-j", "--jobs=JOBS", Integer, "Number of processes to use") do |jobs|
          @config.jobs_count = jobs
        end

        opts.on("--queue=URL", String) do |queue_url|
          @config.queue_url = queue_url
        end

        opts.on("--build-id=ID", String) do |build_id|
          @config.build_id = build_id
        end

        opts.on("--worker-id=ID", String) do |worker_id|
          @config.worker_id = worker_id
        end

        opts.on("--max-retries=COUNT", Integer) do |max_retries|
          @config.max_retries = max_retries
        end

        opts.on("--retry-tolerance=RATE", Float) do |retry_tolerance|
          @config.retry_tolerance = retry_tolerance
        end
      end
    end
  end
end
