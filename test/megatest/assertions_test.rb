# frozen_string_literal: true

module Megatest
  class AssertionsTest < MegaTestCase
    class DummyTester
      include Assertions

      def initialize(result, config)
        @__mega_result = result
        @__mega_config = config
      end
    end

    def setup
      @color = Output::ANSIColors
      fake_test_case = BlockTest.new(:__suite__, DummyTester, "fake test case", -> {})
      @result = TestCaseResult.new(fake_test_case)
      @config = Config.new({})
      @case = DummyTester.new(@result, @config)
    end

    def test_flunk_raises
      assertion = assert_raises(Assertion) do
        @case.flunk
      end
      assert_equal "Failed", assertion.message

      assertion = assert_raises(Assertion) do
        @case.flunk "Positional message"
      end
      assert_equal "Positional message", assertion.message

      assertion = assert_raises(Assertion) do
        @case.flunk message: "Keyword message"
      end
      assert_equal "Keyword message", assertion.message
    end

    def test_assert_raises
      assert_equal 0, @result.assertions_count

      @case.assert_raises do
        raise "Oops"
      end
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.assert_raises(NotImplementedError) do
          raise "Oops"
        end
      end
      assert_equal 2, @result.assertions_count
      assert_equal "[NotImplementedError] exception expected, not #<RuntimeError: Oops>", assertion.message

      @case.assert_raises(NotImplementedError, RuntimeError) do
        raise "Oops"
      end
      assert_equal 3, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.assert_raises(NotImplementedError) do
          @case.assert false, message: "Failed assertion in assert_raises"
        end
      end
      assert_equal 5, @result.assertions_count
      assert_equal "Failed assertion in assert_raises", assertion.message
    end

    def test_assert
      assert_equal 0, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.assert nil
      end
      assert_equal 1, @result.assertions_count
      assert_equal "Expected nil to be truthy", assertion.message

      assertion = assert_raises(Assertion) do
        @case.assert false, message: "Keyword"
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Keyword", assertion.message

      assertion = assert_raises(Assertion) do
        @case.assert false, message: -> { "Callable" }
      end
      assert_equal 3, @result.assertions_count
      assert_equal "Callable", assertion.message

      @case.assert true
      assert_equal 4, @result.assertions_count

      @case.assert "truthy"
      assert_equal 5, @result.assertions_count

      assert_raises(Assertion) do
        @case.assert nil
      end
      assert_equal 6, @result.assertions_count
    end

    def test_assert_nil
      assert_equal 0, @result.assertions_count

      @case.assert_nil(nil)
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.assert_nil 42
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Expected 42 to be nil", assertion.message
    end

    def test_refute_nil
      assert_equal 0, @result.assertions_count

      @case.refute_nil(42)
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.refute_nil nil
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Expected nil to not be nil", assertion.message
    end

    def test_assert_equal
      assert_equal 0, @result.assertions_count

      @case.assert_equal(1, 1)
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.assert_equal 1, 2
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Expected: 1\n  Actual: 2", assertion.message

      assertion = assert_raises(Assertion) do
        @case.assert_equal nil, nil
      end
      assert_equal 3, @result.assertions_count
      assert_equal "Use assert_nil if expecting nil, or pass `allow_nil: true`", assertion.message

      @case.assert_equal(nil, nil, allow_nil: true)
      assert_equal 4, @result.assertions_count
    end

    def test_assert_equal_multiline_strings
      expected = "foo\nbar\nbaz\n"
      actual = "foo\nplop\nbaz\n"
      message = @color.strip(assert_equal_message(expected, actual))
      expect = <<~MESSAGE
        +++ expected
        --- actual

         foo
        -bar
        +plop
         baz
      MESSAGE
      assert_equal expect, message
    end

    def test_assert_predicate
      assert_equal 0, @result.assertions_count

      @case.assert_predicate(1, :odd?)
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.assert_predicate(2, :odd?)
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Expected 2 to be odd?", assertion.message

      assertion = assert_raises(Assertion) do
        @case.assert_predicate(2, :does_not_exist?)
      end
      assert_equal 3, @result.assertions_count
      assert_equal "Unexpected exception", assertion.message
    end

    def test_refute_predicate
      assert_equal 0, @result.assertions_count

      @case.refute_predicate(2, :odd?)
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.refute_predicate(1, :odd?)
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Expected 1 to not be odd?", assertion.message

      assertion = assert_raises(Assertion) do
        @case.refute_predicate(2, :does_not_exist?)
      end
      assert_equal 3, @result.assertions_count
      assert_equal "Unexpected exception", assertion.message
    end

    def test_instance_of
      assert_equal 0, @result.assertions_count

      @case.assert_instance_of(Integer, 42)
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.assert_instance_of(Integer, [])
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Expected [] to be an instance of Integer, not Array", assertion.message
    end

    private

    def assert_equal_message(expected, actual)
      assertion = assert_raises(Assertion) do
        @case.assert_equal expected, actual
      end
      assertion.message
    end
  end
end
