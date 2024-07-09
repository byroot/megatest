# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class SkipTest < TestCase
    test "the skip" do
      skip "soon™"
    end
  end
end
