# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    tag parent: 1, global: 1
    # base test class where to put helpers and such
  end

  class TruthTest < TestCase
    tag class: 2, parent: 2

    test "first", first: 4 do
      assert true
    end

    test "override", class: 3 do
      assert true
    end
  end
end
