# frozen_string_literal: true

module Megatest
  class TestTest < MegaTestCase
    test "name is accessible" do
      assert_equal "name is accessible", name
    end

    def test_name_is_accessible
      assert_equal "test_name_is_accessible", name
    end

    test "tags can be checked", some_tag: 12 do
      assert_equal 12, __test__.tag(:some_tag)
    end
  end
end
