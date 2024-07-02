# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class_eval <<~RUBY, "test_helper.rb"
    class AbstractCase < TestCase
      test "predefined" do
        assert true
      end

      test "overridable" do
        raise NotImplementedError
      end
    end
  RUBY

  anonymous_class = Class.new(AbstractCase)

  class ConcreteATest < anonymous_class
    test "concrete A" do
      assert true
    end

    test "overridable" do
      assert true
    end
  end

  ConcreteBTest = Class.new(AbstractCase) do
    test "concrete B" do
      assert true
    end

    test "overridable" do
      assert true
    end
  end

  class_eval <<~RUBY, "another_test_helper.rb"
    class AbstractCase < TestCase
      test "reopened" do
        assert true
      end
    end
  RUBY
end
