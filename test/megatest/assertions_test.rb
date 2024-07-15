# frozen_string_literal: true

module Megatest
  class AssertionsTest < MegaTestCase
    class DummyTester
      include Assertions

      def initialize(runtime)
        @__m = runtime
      end
    end

    def setup
      @color = Output::ANSIColors
      fake_test_case = BlockTest.new(:__suite__, DummyTester, "fake test case", -> {})
      @result = TestCaseResult.new(fake_test_case)
      @config = Config.new({})
      @runtime = Runtime.new(@config, @result)
      @case = DummyTester.new(@runtime)
    end

    def test_flunk_raises
      assertion = assert_raises(Assertion) do
        @case.flunk
      end
      assert_equal "Failed", assertion.message

      assert_failure_message("Positional message") do
        @case.flunk "Positional message"
      end

      assert_failure_message("Keyword message") do
        @case.flunk message: "Keyword message"
      end
    end

    def test_assert_raises
      assert_equal 0, @result.assertions_count

      @case.assert_raises do
        raise "Oops"
      end
      assert_equal 1, @result.assertions_count

      error = assert_raises(Assertion) do
        @case.assert_raises(NotImplementedError) do
          1 + "1" # rubocop:disable Style/StringConcatenation
        end
      end
      lines = error.message.split("\n")
      assert_equal "NotImplementedError exception expected, not:", lines[0]
      assert_equal "Class: <TypeError>", lines[1]
      assert_equal %{Message: <"String can't be coerced into Integer">}, lines[2]
      assert_equal "---Backtrace---", lines[3]
      assert_match(%r{\Atest/megatest/assertions_test.rb:\d+:in .*\+.*}, lines[4])
      assert_match(%r{\Atest/megatest/assertions_test.rb:\d+:in .*test_assert_raises.*}, lines[5])
      assert_match(%r{\Atest/megatest/assertions_test.rb:\d+:in .*test_assert_raises.*}, lines[6])
      assert_equal "---------------", lines[7]
      assert_equal 8, lines.size
      assert_equal 2, @result.assertions_count

      @case.assert_raises(NotImplementedError, RuntimeError) do
        raise "Oops"
      end
      assert_equal 3, @result.assertions_count

      assert_failure_message("Failed assertion in assert_raises") do
        @case.assert_raises(NotImplementedError) do
          @case.assert false, message: "Failed assertion in assert_raises"
        end
      end
      assert_equal 5, @result.assertions_count
    end

    def test_assert
      assert_equal 0, @result.assertions_count

      assert_failure_message("Expected nil to be truthy") do
        @case.assert nil
      end
      assert_equal 1, @result.assertions_count

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

    def test_refute
      assert_equal 0, @result.assertions_count

      assert_failure_message("Expected true to be falsy") do
        @case.refute true
      end
      assert_equal 1, @result.assertions_count

      assertion = assert_raises(Assertion) do
        @case.refute true, message: "Keyword"
      end
      assert_equal 2, @result.assertions_count
      assert_equal "Keyword", assertion.message

      assertion = assert_raises(Assertion) do
        @case.refute true, message: -> { "Callable" }
      end
      assert_equal 3, @result.assertions_count
      assert_equal "Callable", assertion.message

      @case.refute false
      assert_equal 4, @result.assertions_count

      assert_raises(Assertion) do
        @case.refute true
      end
      assert_equal 5, @result.assertions_count
    end

    def test_assert_nil
      assert_equal 0, @result.assertions_count

      @case.assert_nil(nil)
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected 42 to be nil") do
        @case.assert_nil 42
      end
      assert_equal 2, @result.assertions_count

      assert_failure_message("Some useful context\nExpected 42 to be nil") do
        @case.assert_nil 42, message: "Some useful context"
      end
      assert_equal 3, @result.assertions_count
    end

    def test_refute_nil
      assert_equal 0, @result.assertions_count

      @case.refute_nil(42)
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected nil to not be nil") do
        @case.refute_nil nil
      end
      assert_equal 2, @result.assertions_count

      assert_failure_message("Some useful context\nExpected nil to not be nil") do
        @case.refute_nil nil, message: "Some useful context"
      end
      assert_equal 3, @result.assertions_count
    end

    def test_assert_equal
      assert_equal 0, @result.assertions_count

      @case.assert_equal(1, 1)
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected: 1\n  Actual: 2") do
        @case.assert_equal 1, 2
      end
      assert_equal 2, @result.assertions_count

      assert_failure_message("Use assert_nil if expecting nil, or pass `allow_nil: true`") do
        @case.assert_equal nil, nil
      end
      assert_equal 3, @result.assertions_count

      @case.assert_equal(nil, nil, allow_nil: true)
      assert_equal 4, @result.assertions_count

      assert_failure_message("Some useful context\nExpected: 1\n  Actual: 2") do
        @case.assert_equal 1, 2, message: "Some useful context\n"
      end
      assert_equal 5, @result.assertions_count
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

    def test_assert_equal_encoded_string
      expected = "Résultat"
      actual = "Résultat".b
      message = assert_equal_message(expected, actual)
      assert_equal <<~MESSAGE.strip, message
        Expected: "Résultat"
          Actual: "R\\xC3\\xA9sultat"
      MESSAGE
    end

    def test_assert_predicate
      assert_equal 0, @result.assertions_count

      @case.assert_predicate(1, :odd?)
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected 2 to be odd?") do
        @case.assert_predicate(2, :odd?)
      end
      assert_equal 2, @result.assertions_count

      assert_failure_message("Unexpected exception") do
        @case.assert_predicate(2, :does_not_exist?)
      end
      assert_equal 3, @result.assertions_count
    end

    def test_refute_predicate
      assert_equal 0, @result.assertions_count

      @case.refute_predicate(2, :odd?)
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected 1 to not be odd?") do
        @case.refute_predicate(1, :odd?)
      end
      assert_equal 2, @result.assertions_count

      assert_failure_message("Unexpected exception") do
        @case.refute_predicate(2, :does_not_exist?)
      end
      assert_equal 3, @result.assertions_count
    end

    def test_instance_of
      assert_equal 0, @result.assertions_count

      @case.assert_instance_of(Integer, 42)
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected [] to be an instance of Integer, not Array") do
        @case.assert_instance_of(Integer, [])
      end
      assert_equal 2, @result.assertions_count
    end

    def test_assert_match
      assert_equal 0, @result.assertions_count

      match = @case.assert_match(/bb|[^b]{2}/, "abba")
      assert_instance_of MatchData, match
      assert_equal "bb", match[0]
      assert_equal 1, @result.assertions_count

      match = @case.assert_match("foo/bar[12]", "before foo/bar[12] after")
      assert_instance_of MatchData, match
      assert_equal "foo/bar[12]", match[0]
      assert_equal 2, @result.assertions_count

      assert_failure_message('Expected /bb|[^b]{2}/ to match "baba"') do
        @case.assert_match(/bb|[^b]{2}/, "baba")
      end
    end

    def test_assert_respond_to
      assert_equal 0, @result.assertions_count

      @case.assert_respond_to 1, :odd?
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected 1 to respond to :blah?") do
        @case.assert_respond_to 1, :blah?
      end
      assert_equal 2, @result.assertions_count
    end

    def test_refute_respond_to
      assert_equal 0, @result.assertions_count

      @case.refute_respond_to 1, :blah?
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected 1 to not respond to :odd?") do
        @case.refute_respond_to 1, :odd?
      end
      assert_equal 2, @result.assertions_count
    end

    def test_assert_same
      assert_equal 0, @result.assertions_count

      str = "foo"
      @case.assert_same str, str
      assert_equal 1, @result.assertions_count

      expected, actual = "foo", "foo".dup
      message = <<~MESSAGE.strip
        Expected          "foo" (id: #{actual.object_id})
        To be the same as "foo" (id: #{expected.object_id})
      MESSAGE
      assert_failure_message(message) do
        @case.assert_same(expected, actual)
      end
      assert_equal 2, @result.assertions_count
    end

    def test_refute_same
      assert_equal 0, @result.assertions_count

      @case.refute_same "foo", "foo".dup
      assert_equal 1, @result.assertions_count

      expected = actual = "foo"
      message = <<~MESSAGE.strip
        Expected              "foo" (id: #{actual.object_id})
        To not be the same as "foo" (id: #{expected.object_id})
      MESSAGE
      assert_failure_message(message) do
        @case.refute_same(expected, actual)
      end
      assert_equal 2, @result.assertions_count
    end

    def test_pass
      assert_equal 0, @result.assertions_count

      @case.pass
      assert_equal 1, @result.assertions_count
    end

    def test_assert_includes
      assert_equal 0, @result.assertions_count

      @case.assert_includes %w(foo), "foo"
      assert_equal 1, @result.assertions_count

      message = <<~MESSAGE.strip
        Expected

        ["foo", "bar", "baz"]

        to include

        "spam"
      MESSAGE
      assert_failure_message(message) do
        @case.assert_includes(%w(foo bar baz), "spam")
      end
      assert_equal 2, @result.assertions_count

      message = <<~'MESSAGE'.strip
        Expected

        "foo\n" + "bar\n" + "baz\n"

        to include

        "spam"
      MESSAGE
      assert_failure_message(message) do
        @case.assert_includes("foo\nbar\nbaz\n", "spam")
      end
      assert_equal 3, @result.assertions_count
    end

    def test_refute_includes
      assert_equal 0, @result.assertions_count

      @case.refute_includes %w(foo), "bar"
      assert_equal 1, @result.assertions_count

      message = <<~MESSAGE.strip
        Expected

        ["foo", "bar", "baz"]

        to not include

        "bar"
      MESSAGE
      assert_failure_message(message) do
        @case.refute_includes(%w(foo bar baz), "bar")
      end
      assert_equal 2, @result.assertions_count
    end

    def test_assert_operator
      assert_equal 0, @result.assertions_count

      @case.assert_operator 2, :>, 1
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected 1 to be > 2") do
        @case.assert_operator 1, :>, 2
      end
      assert_equal 2, @result.assertions_count
    end

    def test_assert_in_delta
      assert_equal 0, @result.assertions_count

      @case.assert_in_delta 10, 9.5, 0.6
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected |10 - 9.5| (0.5) to be <= 0.2") do
        @case.assert_in_delta 10, 9.5, 0.2
      end
      assert_equal 2, @result.assertions_count
    end

    def test_assert_in_epsilon
      assert_equal 0, @result.assertions_count

      @case.assert_in_epsilon 10, 9.5, 0.6
      assert_equal 1, @result.assertions_count

      assert_failure_message("Expected |10000 - 9999| (1) to be <= 0.9999") do
        @case.assert_in_epsilon 10_000, 9_999, 0.0001
      end
      assert_equal 2, @result.assertions_count
    end

    private

    def assert_failure_message(message, &block)
      assertion = assert_raises(Assertion, &block)
      assert_equal message, assertion.message
    end

    def assert_equal_message(expected, actual)
      assertion = assert_raises(Assertion) do
        @case.assert_equal expected, actual
      end
      assertion.message
    end
  end
end
