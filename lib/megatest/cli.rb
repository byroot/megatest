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

    RUNNERS = {
      "report" => :report,
      "run" => :run,
    }.freeze

    def initialize(program_name, out, err, argv, env)
      @program_name = program_name
      @out = out
      @err = err
      @argv = argv.dup
      @processes = nil
      @config = Config.new(env)
      @runner = nil
    end

    def run
      if @runner = RUNNERS[@argv.first]
        @argv.shift
      end

      Megatest.config = @config
      parser = build_parser(@runner)
      parser.parse!(@argv)
      @argv.shift if @argv.first == "--"

      case @runner
      when :report
        report
      when nil, :run
        run_tests
      else
        raise InvalidArgument, "Parsing failure"
      end
    rescue InvalidArgument, OptionParser::ParseError => error
      if error.is_a?(InvalidArgument)
        @err.puts "invalid arguments: #{error.message}"
      else
        @err.puts error.message
      end
      @err.puts
      @err.puts parser
      1
    end

    def run_tests
      queue = @config.build_queue

      if queue.distributed?
        raise InvalidArgument, "Distributed queues require a build-id" unless @config.build_id
        raise InvalidArgument, "Distributed queues require a worker-id" unless @config.worker_id
      end

      selectors = Selector.parse(@argv)

      Megatest.load_config(selectors.paths)

      registry = Megatest.with_registry do
        Megatest.append_load_path(@config)
        Megatest.load_test_helper(selectors.paths)
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
      queue = @config.build_queue

      raise InvalidArgument, "Only distributed queues can be summarized" unless queue.distributed?
      raise InvalidArgument, "Distributed queues require a build-id" unless @config.build_id
      raise InvalidArgument, @argv.join(" ") unless @argv.empty?

      Megatest.load_config(@argv)

      QueueReporter.new(@config, queue, @out).run(default_reporters) ? 0 : 1
    end

    private

    def default_reporters
      [
        Reporters::SimpleReporter.new(@config, @out),
      ]
    end

    def executor
      if @config.jobs_count > 1
        require "megatest/multi_process"
        MultiProcess::Executor.new(@config, @out)
      else
        Executor.new(@config, @out)
      end
    end

    def build_parser(runner)
      OptionParser.new do |opts|
        case runner
        when :report
          opts.banner = "Usage: #{@program_name} report [options]"
        when :run
          opts.banner = "Usage: #{@program_name} run [options] [files or directories]"
        else
          opts.banner = "Usage: #{@program_name} command [options] [files or directories]"
          opts.separator ""
          opts.separator "Commands:"
          opts.separator ""

          opts.separator "\trun\t\tExecute the given tests."
          opts.separator "\t\t\t  $ #{@program_name} test/integration/"
          opts.separator "\t\t\t  $ #{@program_name} test/my_test.rb:42 test/another_test.rb:36"
          opts.separator ""

          opts.separator "\treport\t\tWait for the queue to be entirely processed and report the status"
          opts.separator "\t\t\t  $ #{@program_name} report --queue redis://ci-queue.example.com --build-id $CI_BUILD_ID"
          opts.separator ""
        end

        opts.separator ""
        opts.separator "Options:"
        opts.separator ""

        opts.on("-b", "--backtrace", "Print full backtraces") do
          @config.backtrace.full!
        end

        if runner == :run || runner.nil?
          opts.on("--seed SEED", Integer, "The seed used to define run order") do |seed|
            Megatest.seed = Random.new(seed)
          end

          opts.on("-j", "--jobs JOBS", Integer, "Number of processes to use") do |jobs|
            @config.jobs_count = jobs
          end

          help = "Number of consecutive failures before exiting. Default to 1"
          opts.on("-f", "--fail-fast [COUNT]", Integer, help) do |max|
            @config.max_consecutive_failures = (max || 1)
          end
        end

        opts.on("--queue URL", String) do |queue_url|
          @config.queue_url = queue_url
        end

        opts.on("--build-id ID", String) do |build_id|
          @config.build_id = build_id
        end

        if runner == :run || runner.nil?
          opts.on("--worker-id ID", String) do |worker_id|
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
end
