# frozen_string_literal: true

module Megatest
  class AutorunTest < MegaTestCase
    test "running with ruby works" do
      test_file = fixture("autorun/some_test.rb")
      output = `ruby #{test_file}`
      assert_includes output, "Failure: SomeTest#something"
      assert_includes output, "Expected: 4"
      assert_includes output, "Actual: 2"
      refute_predicate $?, :success?
    end
  end
end
