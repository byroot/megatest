# frozen_string_literal: true

require "optparse"

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
    end

    def run
      parser.parse!(@argv)

      run_tests
    end

    def run_tests
      Megatest.load_suites(@argv)
      success = SuccessReporter.new
      reporters = [success] + default_reporters
      executor = executor_class.new(Megatest.registry, reporters)
      executor.run
      success.passed? ? 0 : 1
    end

    private

    def default_reporters
      [
        SimpleReporter.new(@out),
      ]
    end

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
