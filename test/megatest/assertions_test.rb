# frozen_string_literal: true

require "test_helper"

module Megatest
  class AssertionsTest < MegaTestCase
    class DummyTester
      include Assertions

      def initialize(mega_state)
        @__mega = mega_state
      end
    end

    def setup
      @state = State::TestCase.new
      @case = DummyTester.new(@state)
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

    def test_assert
      assert_equal 0, @state.assertions

      assertion = assert_raises(Assertion) do
        @case.assert false
      end
      assert_equal 1, @state.assertions
      assert_equal "Failed", assertion.message

      assertion = assert_raises(Assertion) do
        @case.assert false, message: "Keyword"
      end
      assert_equal 2, @state.assertions
      assert_equal "Keyword", assertion.message

      assertion = assert_raises(Assertion) do
        @case.assert false, message: -> { "Callable" }
      end
      assert_equal 3, @state.assertions
      assert_equal "Callable", assertion.message

      @case.assert true
      assert_equal 4, @state.assertions

      @case.assert "truthy"
      assert_equal 5, @state.assertions

      assert_raises(Assertion) do
        @case.assert nil
      end
      assert_equal 6, @state.assertions
    end
  end
end
