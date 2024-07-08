# frozen_string_literal: true

require "stringio"

module Megatest
  class CLITest < MegaTestCase
    def test_seed_argument
      original_seed = Megatest.seed
      cli = new_cli("--seed", "42")
      cli.run
      assert_equal 42, Megatest.seed.seed

      cli = new_cli("--seed=44")
      cli.run
      assert_equal 44, Megatest.seed.seed
    ensure
      Megatest.seed = original_seed
    end

    def test_execute_directory
      cli = new_cli(fixture("simple/"))
      assert_equal 1, cli.run
    end

    private

    def new_cli(*argv)
      @out = StringIO.new
      @err = StringIO.new
      @progname = "megatest"
      CLI.new(@progname, @out, @err, argv, ENV)
    end
  end
end
