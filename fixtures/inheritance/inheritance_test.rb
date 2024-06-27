# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class AbstractCase < TestCase
    test "predefined" do
      assert true
    end
  end

  class ConcreteATest < AbstractCase
    test "concrete A" do
      assert true
    end
  end

  class ConcreteBTest < AbstractCase
    test "concrete B" do
      assert true
    end
  end

  class AbstractCase < TestCase
    test "reopened" do
      assert true
    end
  end
end
