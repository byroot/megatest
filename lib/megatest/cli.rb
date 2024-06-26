# frozen_string_literal: true

require "optparse"

module Megatest
  class CLI
    class << self
      def run!
        exit(new($PROGRAM_NAME, $stdout, $stderr, ARGV).run)
      end
    end

    undef_method :puts # Should only use @out.puts or @err.puts

    def initialize(program_name, out, err, argv)
      @program_name = program_name
      @out = out
      @err = err
      @argv = argv.dup
    end

    def run
      parser.parse!(@argv)

      run_tests
    end

    def run_tests
      Megatest.load_suites(@argv)
      executor = executor_class.new(Megatest.registry)
      @err.puts("Running #{executor.test_cases.size} test cases with --seed #{Megatest.seed.seed}")
      results = executor.run

      exitcode = 0
      results.each do |result|
        exitcode = 1 if result.failed?
      end
      exitcode
    end

    private

    def executor_class
      Executor
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
      end
    end
  end
end
