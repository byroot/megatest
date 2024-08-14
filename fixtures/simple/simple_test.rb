# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class TruthTest < TestCase
    test "the truth" do
      assert true
    end

    test "the lie", focus: true do
      assert false
    end

    test "the unexpected", focus: true do
      1 + nil
    end

    test "the void" do
    end
  end
end
