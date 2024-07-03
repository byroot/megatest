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
      @queue_url = env["MEGATEST_QUEUE_URL"]
      @build_id = nil
      @worker_id = nil
    end

    def run
      parser.parse!(@argv)
      run_tests
    rescue InvalidArgument => error
      @err.puts "Invalid arguments: #{error.message}"
      @err.puts
      @err.puts parser
      1
    end

    def run_tests
      selectors = Selector.parse(@argv)
      Megatest.load_suites(selectors.paths)

      test_cases = selectors.select(Megatest.registry)

      # TODO: figure out when to shuffle. E.g. if passing file:line file:line we want to keep the order
      # but file, file we want to shuffle. It also should just be a default we should be able to flip it
      # with CLI arguments.
      test_cases.sort!
      test_cases.shuffle!(random: Megatest.seed)

      queue.populate(test_cases)
      executor.run(queue, default_reporters)
      queue.success? ? 0 : 1
    end

    private

    def queue
      @queue ||= case @queue_url
      when nil
        Queue.new
      when /\Arediss?:/
        require "megatest/redis_queue"
        RedisQueue.new(url: @queue_url, build: build_id, worker: worker_id)
      else
        raise ArgumentError, "Unsupported queue type: #{@queue_url.inspect}"
      end
    end

    def build_id
      @build_id or raise InvalidArgument, "Distributed queues require a build-id"
    end

    def worker_id
      @worker_id or raise InvalidArgument, "Distributed queues require a worker-id"
    end

    def default_reporters
      [
        Reporters::SimpleReporter.new(@out, program_name: @program_name),
      ]
    end

    def executor
      if @processes
        require "megatest/multi_process"
        MultiProcess::Executor.new(@processes)
      else
        Executor.new
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
          @processes = jobs
        end

        opts.on("--queue=URL", String) do |queue_url|
          @queue_url = queue_url
        end

        opts.on("--build-id=ID", String) do |build_id|
          @build_id = build_id
        end

        opts.on("--worker-id=ID", String) do |worker_id|
          @worker_id = worker_id
        end
      end
    end
  end
end
