# frozen_string_literal: true

require "megatest/queue_shared_tests"

module Megatest
  class PatienceDiffTest < MegaTestCase
    def setup
      @differ = PatienceDiff::Differ.new(Output::NoColors)
    end

    def test_no_difference
      sequence = %w(foo bar baz)
      assert_nil @differ.diff_sequences(sequence, sequence)
    end

    def test_single_difference
      expected = %w(foo bar baz)
      actual = %w(foo plop baz)

      assert_equal <<~TEXT, @differ.diff_sequences(expected, actual).join("\n") << "\n"
         foo
        -bar
        +plop
         baz
      TEXT
    end

    def test_multiple_difference
      expected = %w(foo bar baz) + (1..100).map(&:to_s) + %w(egg spam)
      actual = %w(foo plop baz) + (1..100).map(&:to_s) + %w(spam egg)
      assert_equal <<~TEXT, @differ.diff_sequences(expected, actual).join("\n") << "\n"
         foo
        -bar
        +plop
         baz
         1
         2
        @@ -101,5 +101,6 @@
         98
         99
         100
        +spam
         egg
        -spam
      TEXT
    end

    def test_trailing_newline
      expected = "foo\nbar\nbaz\n".lines
      actual = "foo\nbar\nbaz".lines
      output = [
        " foo\n",
        " bar\n",
        "-baz\n",
        "+baz",
      ]
      assert_equal output, @differ.diff_sequences(expected, actual)
    end

    def test_with_colors
      @differ = PatienceDiff::Differ.new(Output::ANSIColors)

      expected = "foo\nbar\nbaz\n".lines
      actual = "foo\nplop\nbaz\n".lines

      diff = [
        " foo\n",
        "\e[31m-bar\e[0m\n", # red
        "\e[32m+plop\e[0m\n", # green
        " baz\n",
      ]
      assert_equal diff, @differ.diff_sequences(expected, actual)
    end
  end
end
