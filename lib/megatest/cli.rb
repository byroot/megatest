# frozen_string_literal: true

# :stopdoc:

require "optparse"

module Megatest
  class CLI
    InvalidArgument = Class.new(ArgumentError)

    class << self
      def run!
        program_name = ENV.fetch("MEGATEST_PROGRAM_NAME", $PROGRAM_NAME)
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
      "bisect" => :bisect,
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
      when :bisect
        bisect_tests
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

      @config.selectors = Selector.new(@config).parse(@argv)
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

    def bisect_tests
      require "megatest/multi_process"

      queue = @config.build_queue
      raise InvalidArgument, "Distributed queues can't be bisected" if queue.distributed?

      @config.selectors = Selector.new(@config).parse(@argv)
      Megatest.load_config(@config)
      Megatest.init(@config)
      test_cases = Megatest.load_tests(@config)
      queue.populate(test_cases)
      candidates = queue.dup

      if test_cases.empty?
        @err.puts "No tests to run"
        return 1
      end

      unless failure = find_failing_test(queue)
        @err.puts "No failing test"
        return 1
      end

      bisect_queue(candidates, failure.test_id)
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

    def find_failing_test(queue)
      @config.max_consecutive_failures = 1
      @config.jobs_count = 1

      executor = MultiProcess::Executor.new(@config.dup, @out)
      executor.run(queue, default_reporters)
      queue.summary.failures.first
    end

    def bisect_queue(queue, failing_test_id)
      err = Output.new(@err)
      tests = queue.to_a
      failing_test_index = tests.index { |test| test.id == failing_test_id }
      failing_test = tests[failing_test_index]
      suspects = tests[0...failing_test_index]

      check_passing = @config.build_queue
      check_passing.populate([failing_test])
      executor = MultiProcess::Executor.new(@config.dup, @out, managed: true)
      executor.run(check_passing, [])
      unless check_passing.success?
        err.puts err.red("Test failed by itself, no need to bisect")
        return 1
      end

      run_index = 0
      while suspects.size > 1
        run_index += 1
        err.puts "Attempt #{run_index}, #{suspects.size} suspects left."

        before, after = suspects[0...(suspects.size / 2)], suspects[(suspects.size / 2)..]
        candidates = @config.build_queue
        candidates.populate(before + [failing_test])

        executor = MultiProcess::Executor.new(@config.dup, @out, managed: true)
        executor.run(candidates, default_reporters)

        if candidates.success?
          suspects = after
        else
          suspects = before
        end

        err.puts
      end
      suspect = suspects.first

      validation_queue = @config.build_queue
      validation_queue.populate([suspect, failing_test])
      executor = MultiProcess::Executor.new(@config.dup, @out, managed: true)
      executor.run(validation_queue, [])
      if validation_queue.success?
        err.puts err.red("Bisect inconclusive")
        return 1
      end

      err.print "Found test leak: "
      err.puts err.yellow "#{@config.program_name} #{Megatest.relative_path(suspect.location_id)} #{Megatest.relative_path(failing_test.location_id)}"
      0
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
        when :bisect
          opts.banner = "Usage: #{@program_name} bisect [options] [files or directories]"
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

          opts.separator "\tbisect\t\tRepeatedly run subsets of the given tests."
          opts.separator "\t\t\t  $ #{@program_name} bisect --seed 12345 test/integration"
          opts.separator "\t\t\t  $ #{@program_name} bisect --queue path/to/test_order.log"
          opts.separator ""
        end

        opts.separator ""
        opts.separator "Options:"
        opts.separator ""

        opts.on("-I PATHS", "specify $LOAD_PATH directory (may be used more than once)") do |paths|
          paths.split(":").each do |path|
            $LOAD_PATH.unshift(path)
          end
        end

        opts.on("-b", "--backtrace", "Print full backtraces") do
          @config.backtrace.full!
        end

        opts.on("-v", "--verbose", "Use the verbose reporter") do
          @verbose = true
        end

        opts.on("--junit [PATH]", String, "Generate a junit.xml file") do |path|
          @junit = path
        end

        if %i[run bisect].include?(runner)
          opts.on("--seed SEED", Integer, "The seed used to define run order") do |seed|
            @config.seed = seed
          end
        end

        if runner == :run
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

        if %i[run report].include?(runner)
          opts.on("--build-id ID", String, "Unique identifier for the CI build") do |build_id|
            @config.build_id = build_id
          end
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
