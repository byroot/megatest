# frozen_string_literal: true

module Megatest
  class TagsTest < MegaTestCase
    setup do
      load_fixture("tags/tagged_test.rb")
      @first = @registry.test_cases[0]
      @override = @registry.test_cases[1]
    end

    test "missing" do
      assert_nil @first.tag(:does_not_exist)
    end

    test "test tags" do
      assert_equal 4, @first.tag(:first)
    end

    test "suite tags" do
      assert_equal 2, @first.tag(:class)
    end

    test "precedence" do
      assert_equal 3, @override.tag(:class)
      assert_equal 2, @override.tag(:parent)
      assert_equal 1, @override.tag(:global)
    end
  end
end
