# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class_eval <<~RUBY, "test_helper.rb"
    class BaseCase < TestCase
      PREDEFINED_LINE = __LINE__ + 1
      test "predefined" do
        assert true
      end

      OVERRIDABLE_LINE = __LINE__ + 1
      test "overridable" do
        raise NotImplementedError
      end
    end
  RUBY

  class_eval <<~RUBY, "shared_tests_module.rb"
    module SharedCompatTests
      def test_compat_shared
        assert true
      end
    end
  RUBY

  class_eval <<~RUBY, "shared_tests.rb"
    module SharedTests
      extend Megatest::DSL

      test "shared" do
        assert true
      end
    end
  RUBY

  class ConcreteATest < BaseCase
    LINE = __LINE__ - 1
    SHARED_TESTS_LINE = __LINE__ + 1
    include SharedTests

    SHARED_COMPAT_TESTS_LINE = __LINE__ + 1
    include SharedCompatTests

    TEST_1_LINE = __LINE__ + 1
    test "concrete A" do
      assert true
    end

    TEST_2_LINE = __LINE__ + 1
    test "overridable" do
      assert true
    end
  end

  ConcreteBTest = Class.new(BaseCase) do
    self::LINE = __LINE__ - 1

    self::TEST_1_LINE = __LINE__ + 1
    test "concrete B" do
      assert true
    end

    self::TEST_2_LINE = __LINE__ + 1
    test "overridable" do
      assert true
    end
  end

  class_eval <<~RUBY, "another_test_helper.rb"
    class BaseCase < TestCase
      REOPENED_LINE = __LINE__ + 1
      test "reopened" do
        assert true
      end
    end
  RUBY
end
