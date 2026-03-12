# frozen_string_literal: true

module Megatest
  class CLITest < MegaTestCase
    def test_seed_argument
      assert_equal 42, config("--seed", "42").seed
      assert_equal 44, config("--seed=44").seed
      assert_equal 12, config(env: { "SEED" => "12" }).seed
      assert_equal 44, config("--seed=44", env: { "SEED" => "12" }).seed
    end

    def test_execute_directory
      cli = new_cli(fixture("simple/"))
      assert_equal 1, cli.run
    end

    def test_custom_test_glob
      cli = new_cli(fixture("custom_glob/"))

      assert_equal 0, cli.run

      assert_includes @out.string, "Ran 1 cases, 1 assertions, 0 failures, 0 errors, 0 retries, 0 skips"
    end

    def test_jobs_count
      test = self
      stub(Etc, :nprocessors, -> { test.flunk "Etc.nprocessors was unexpectedly called" }) do
        assert_equal 1, config("--jobs=1").jobs_count
        assert_equal 42, config("--jobs=42").jobs_count
        # sharded and distributed queue runs are not automatically parallelized
        assert_equal 1, config("--worker-id=1", "--workers-count=2").jobs_count
        assert_equal 1, config("--queue=redis://[100::]:6379/1").jobs_count
      end
    end

    if Megatest.fork?
      def test_jobs_count_fork_available
        stub(Etc, :nprocessors, -> { 3 }) do
          assert_equal 3, config("--jobs").jobs_count
          assert_equal 3, config.jobs_count
        end
      end
    else
      def test_jobs_count_warns
        warning = nil
        stub(Warning, :warn, ->(message, *) { warning = message })
        assert_equal 1, config("--jobs").jobs_count
        assert_match(/fork is not available/, warning)
      end
    end

    private

    def config(*argv, env: {})
      new_cli(*argv, env: env).configure
    end

    def new_cli(*argv, env: {})
      @out = StringIO.new
      @err = StringIO.new
      @progname = "megatest"
      CLI.new(@progname, @out, @err, argv, env)
    end
  end
end
