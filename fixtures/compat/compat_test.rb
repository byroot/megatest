# frozen_string_literal: true

module TestedApp
  class CompatTest < Megatest::Test
    def test_the_truth
      assert true
    end

    def test_the_lie
      assert false
    end

    def test_the_unexpected
      1 + "1" # rubocop:disable Style/StringConcatenation
    end
  end
end
