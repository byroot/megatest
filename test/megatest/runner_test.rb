# frozen_string_literal: true

module Megatest
  class RunnerTest < MegaTestCase
    setup do
      load_fixture("errors/isolated_test.rb")
      @config.selectors = Selector.parse(["fixtures/errors/isolated_test.rb"])
      @config.global_setup { 42 }
      @isolated = @registry.test_cases[0]
      @not_isolated = @registry.test_cases[1]
      @crashing = @registry.test_cases[2]
      @runner = Runner.new(@config)
    end

    test "isolated test runs in a subprocess" do
      result = @runner.execute(@isolated)
      assert_predicate result, :success?
    end

    test "not isolated runs in the same process" do
      result = @runner.execute(@not_isolated)
      assert_predicate result, :success?
    end

    test "isolated tests can crash" do
      result = @runner.execute(@crashing)
      assert_predicate result, :lost?
    end
  end
end
