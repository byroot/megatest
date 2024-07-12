# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class AssertEqualTest < TestCase
    test "single line string" do
      assert_equal "foo", "bar"
    end

    test "multi-line string" do
      assert_equal "foo\nbar\nbaz\negg\nspam\n", "foo\nbar\negg\nbaz\nspam\n"
    end

    test "symbol array" do
      assert_equal %i(foo bar baz egg spam), %i(foo spam bar baz egg)
    end

    test "multi-line string array" do
      expected = [
        "foo\nbar\nbaz\negg\nspam\n",
        "baz\nfoo\nbar\negg\nspam\n",
        "foo\nbar\negg\nbaz\nspam\n",
      ]

      actual = [
        "foo\nbar\nbaz\negg\nspam\n",
        "foo\nbar\negg\nbaz\nspam\n",
      ]

      assert_equal expected, actual
    end

    test "hashes" do
      expected = {
        foo: 12,
        bar: 24,
        plop: 32,
      }

      actual = {
        foo: 12,
        bar: 42,
        plop: 32,
      }

      assert_equal expected, actual
    end
  end
end
