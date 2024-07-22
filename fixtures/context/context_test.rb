# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class ContextTest < TestCase
    tag some_tag: 0

    context "some context", some_tag: 1 do
      test "the truth" do
        assert true
      end

      test "the lie", some_tag: 2 do
        assert false
      end

      context "some more context", some_tag: 3, focus: true do
        test "the unexpected", some_tag: 4 do
          1 + nil
        end
      end
    end

    context "something else" do
      test "the void" do
      end
    end
  end
end
