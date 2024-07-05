# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class TruthTest < TestCase
    test "the truth" do
      assert true
    end

    test "the lie" do
      assert false
    end

    test "the unexpected" do
      1 + "1" # rubocop:disable Style/StringConcatenation
    end

    test "the void" do
    end
  end
end
