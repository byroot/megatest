# frozen_string_literal: true

begin
  require "rake/tasklib"
rescue LoadError => e
  warn e.message
  return
end

module Megatest # :nodoc:
  ##
  # Megatest::TestTask is a rake helper that generates several rake
  # tasks under the main test task's name-space.
  #
  #   task <name>      :: the main test task
  #   task <name>:cmd  :: prints the command to use
  #
  # Examples:
  #
  #   Megatest::TestTask.create
  #
  # The most basic and default setup.
  #
  #   Megatest::TestTask.create :my_tests
  #
  # The most basic/default setup, but with a custom name
  #
  #   Megatest::TestTask.create :unit do |t|
  #     t.warning = true
  #   end
  #
  # Customize the name and only run unit tests.

  class TestTask < Rake::TaskLib
    WINDOWS = RbConfig::CONFIG["host_os"] =~ /mswin|mingw/ # :nodoc:

    ##
    # Create several test-oriented tasks under +name+. Takes an
    # optional block to customize variables.

    def self.create(name = :test, &block)
      task = new name
      task.instance_eval(&block) if block
      task.define
      task
    end

    ##
    # Extra arguments to pass to the tests. Defaults empty.

    attr_accessor :extra_args

    ##
    # Extra library directories to include.

    attr_accessor :libs

    ##
    # The name of the task and base name for the other tasks generated.

    attr_accessor :name

    ##
    # Test files or directories to run. Defaults to +test/+

    attr_accessor :tests

    ##
    # Turn on ruby warnings (-w flag). Defaults to true.

    attr_accessor :warning

    ##
    # Print out commands as they run. Defaults to Rake's +trace+ (-t
    # flag) option.

    attr_accessor :verbose

    ##
    # Show full backtraces on error

    attr_accessor :full_backtrace

    ##
    # Use TestTask.create instead.

    def initialize(name = :test) # :nodoc:
      super()
      self.libs = []
      self.name = name
      self.tests = ["test/"]
      self.extra_args = []
      self.verbose = Rake.application.options.trace || Rake.verbose == true
      self.warning = true
    end

    def define # :nodoc:
      desc "Run the test suite. Use N, X, A, and TESTOPTS to add flags/args."
      task name do
        sh(*make_test_cmd, verbose: verbose)
      end

      desc "Print out the test command. Good for profiling and other tools."
      task "#{name}:cmd" do
        puts make_test_cmd.join(" ")
      end
    end

    ##
    # Generate the test command-line.

    def make_test_cmd
      cmd = ["megatest"]
      cmd << "-I#{libs.join(File::PATH_SEPARATOR)}" unless libs.empty?
      cmd << "-w" if warning
      cmd << "--backtrace" if full_backtrace
      cmd.concat(extra_args)
      cmd.concat(tests)
      cmd
    end
  end
end
