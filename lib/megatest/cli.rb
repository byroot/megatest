# frozen_string_literal: true

require "optparse"
require "megatest/selector"

module Megatest
  class CLI
    class << self
      def run!
        exit(new($PROGRAM_NAME, $stdout, $stderr, ARGV).run)
      end
    end

    undef_method :puts, :print # Should only use @out.puts or @err.puts

    def initialize(program_name, out, err, argv)
      @program_name = program_name
      @out = out
      @err = err
      @argv = argv.dup
      @processes = nil
    end

    def run
      parser.parse!(@argv)

      run_tests
    end

    def run_tests
      selectors = Selector.parse(@argv)
      Megatest.load_suites(selectors.map(&:path))

      test_cases = []
      selectors.each do |selector|
        test_cases.concat(selector.select(Megatest.registry))
      end

      # TODO: figure out when to shuffle. E.g. if passing file:line file:line we want to keep the order
      # but file, file we want to shuffle. It also should just be a default we should be able to flip it
      # with CLI arguments.
      test_cases.sort!
      test_cases.shuffle!(random: Megatest.seed)

      queue = Queue.new(test_cases)
      executor.run(queue, default_reporters)
      queue.success? ? 0 : 1
    end

    private

    def default_reporters
      [
        SimpleReporter.new(@out),
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
          Usage: #{@program_name} [SUBCOMMAND] [ARGS]"

          SUBCOMMANDS

          GLOBAL OPTIONS
        HELP

        opts.separator ""

        opts.on("--seed=SEED", Integer, "The seed used to define run order") do |seed|
          Megatest.seed = Random.new(seed)
        end

        opts.on("-j", "--jobs=JOBS", Integer, "Number of processes to use") do |jobs|
          @processes = jobs
        end
      end
    end
  end
end
