# frozen_string_literal: true

require "megatest/autorun"

class SomeTest < Megatest::Test
  test "something" do
    assert_equal 4, 1 + 1
  end
end
