# frozen_string_literal: true

# :stopdoc:

require "optparse"

module Megatest
  class CLI
    InvalidArgument = Class.new(ArgumentError)

    class << self
      def run!
        program_name = $PROGRAM_NAME
        if paths = ENV["PATH"]
          paths.split(":").each do |path|
            if program_name.start_with?(path)
              program_name = program_name.delete_prefix(path)
              program_name = program_name.delete_prefix("/")
              break
            end
          end
        end

        exit(new(program_name, $stdout, $stderr, ARGV, ENV).run)
      end
    end

    undef_method :puts, :print # Should only use @out.puts or @err.puts

    RUNNERS = {
      "report" => :report,
      "run" => :run,
    }.freeze

    def initialize(program_name, out, err, argv, env)
      @out = out
      @err = err
      @argv = argv.dup
      @processes = nil
      @config = Config.new(env)
      @program_name = @config.program_name = program_name
      @runner = nil
      @verbose = false
      @junit = false
    end

    def run
      configure
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
      @err.puts @parser
      1
    end

    def configure
      if @runner = RUNNERS[@argv.first]
        @argv.shift
      end

      Megatest.config = @config
      @parser = build_parser(@runner)
      @parser.parse!(@argv)
      @argv.shift if @argv.first == "--"
      @config
    end

    def run_tests
      queue = @config.build_queue

      if queue.distributed?
        raise InvalidArgument, "Distributed queues require a build-id" unless @config.build_id
        raise InvalidArgument, "Distributed queues require a worker-id" unless @config.worker_id
      elsif queue.sharded?
        unless @config.valid_worker_index?
          raise InvalidArgument, "Splitting the queue requires a worker-id lower than workers-count, got: #{@config.worker_id.inspect}"
        end
      end

      @config.selectors = Selector.parse(@argv)
      Megatest.load_config(@config)
      Megatest.init(@config)
      test_cases = Megatest.load_tests(@config)

      if test_cases.empty?
        @err.puts "No tests to run"
        return 1
      end

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
      reporters = if @verbose || @config.ci
        [
          Reporters::VerboseReporter.new(@config, @out),
        ]
      else
        [
          Reporters::SimpleReporter.new(@config, @out),
        ]
      end

      if @config.ci
        reporters << Reporters::OrderReporter.new(@config, open_file("log/test_order.log"))
      end

      if @junit != false
        junit_file = open_file(@junit || "log/junit.xml")
        reporters << Reporters::JUnitReporter.new(@config, Megatest::Output.new(junit_file, colors: true))
      end

      reporters
    end

    def open_file(path)
      File.open(path, "w+")
    rescue Errno::ENOENT
      mkdir_p(File.dirname(path))
      retry
    end

    def mkdir_p(directory)
      raise InvalidArgument if directory.empty?

      Dir.mkdir(directory)
    rescue Errno::ENOENT
      mkdir_p(File.dirname(directory))
      retry
    rescue InvalidArgument
      raise InvalidArgument, "Couldn't create directory: #{directory}"
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
      runner = :run if runner.nil?
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

        opts.on("-v", "--verbose", "Use the verbose reporter") do
          @verbose = true
        end

        opts.on("--junit [PATH]", String, "Generate a junit.xml file") do |path|
          @junit = path
        end

        if runner == :run
          opts.on("--seed SEED", Integer, "The seed used to define run order") do |seed|
            @config.seed = seed
          end

          opts.on("-j", "--jobs JOBS", Integer, "Number of processes to use") do |jobs|
            @config.jobs_count = jobs
          end

          help = "Number of consecutive failures before exiting. Default to 1"
          opts.on("-f", "--fail-fast [COUNT]", Integer, help) do |max|
            @config.max_consecutive_failures = (max || 1)
          end

          opts.on("--max-retries COUNT", Integer, "How many times a given test may be retried") do |max_retries|
            @config.max_retries = max_retries
          end

          opts.on("--retry-tolerance RATE", Float, "The proportion of tests that may be retried. e.g. 0.05 for 5% of retried tests") do |retry_tolerance|
            @config.retry_tolerance = retry_tolerance
          end
        end

        opts.separator ""
        opts.separator "Test distribution and sharding:"
        opts.separator ""

        opts.on("--queue URL", String, "URL of queue server to use for test distribution. Default to $MEGATEST_QUEUE_URL") do |queue_url|
          @config.queue_url = queue_url
        end

        opts.on("--build-id ID", String, "Unique identifier for the CI build") do |build_id|
          @config.build_id = build_id
        end

        if runner == :run
          opts.on("--worker-id ID", String, "Unique identifier for the CI job") do |worker_id|
            @config.worker_id = worker_id
          end

          opts.on("--workers-count COUNT", Integer, "Number of CI jobs") do |workers_count|
            @config.workers_count = workers_count
          end
        end
      end
    end
  end
end
