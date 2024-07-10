# frozen_string_literal: true

module Megatest
  class CLITest < MegaTestCase
    def test_seed_argument
      config = new_cli("--seed", "42").configure
      assert_equal 42, config.seed

      config = new_cli("--seed=44").configure
      assert_equal 44, config.seed

      config = new_cli(env: { "SEED" => "12" }).configure
      assert_equal 12, config.seed

      config = new_cli("--seed=44", env: { "SEED" => "12" }).configure
      assert_equal 44, config.seed
    end

    def test_execute_directory
      cli = new_cli(fixture("simple/"))
      assert_equal 1, cli.run
    end

    private

    def new_cli(*argv, env: {})
      @out = StringIO.new
      @err = StringIO.new
      @progname = "megatest"
      CLI.new(@progname, @out, @err, argv, env)
    end
  end
end
