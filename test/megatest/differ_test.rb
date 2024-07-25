# frozen_string_literal: true

require "megatest/queue_shared_tests"

module Megatest
  class DifferTest < MegaTestCase
    def setup
      @differ = Differ.new(@config)
    end

    def test_single_array_difference
      expected = %w(foo bar baz)
      actual = %w(foo plop baz)

      assert_equal <<~TEXT, normalize(@differ.call(expected, actual))
        --- expected
        +++ actual

         [
           "foo",
        -  "bar",
        +  "plop",
           "baz",
         ]
      TEXT
    end

    def test_multiple_array_difference
      expected = %w(foo bar baz) + (1..100).map(&:to_s) + %w(egg spam)
      actual = %w(foo plop baz) + (1..100).map(&:to_s) + %w(spam egg)
      assert_equal <<~TEXT, normalize(@differ.call(expected, actual))
        --- expected
        +++ actual

         [
           "foo",
        -  "bar",
        +  "plop",
           "baz",
           "1",
           "2",
        @@ -102,6 +102,6 @@   "98",
           "99",
           "100",
        +  "spam",
           "egg",
        -  "spam",
         ]
      TEXT
    end

    def test_single_line_difference
      expected = "foo\nbar\nbaz\n"
      actual = "foo\nplop\nbaz\n"

      assert_equal <<~TEXT, normalize(@differ.call(expected, actual))
        --- expected
        +++ actual

         foo
        -bar
        +plop
         baz
      TEXT
    end

    def test_multiple_line_difference
      expected = (%w(foo bar baz) + (1..100).map(&:to_s) + %w(egg spam)).join("\n") << "\n"
      actual = (%w(foo plop baz) + (1..100).map(&:to_s) + %w(spam egg)).join("\n") << "\n"

      assert_equal <<~TEXT, normalize(@differ.call(expected, actual))
        --- expected
        +++ actual

         foo
        -bar
        +plop
         baz
         1
         2
        @@ -101,5 +101,6 @@ 98
         99
         100
        +spam
         egg
        -spam
      TEXT
    end

    def test_trailing_newline
      expected = "foo\nbar\nbaz\n"
      actual = "foo\nbar\nbaz"
      assert_diff expected, actual, <<~TEXT
        --- expected
        +++ actual

         foo
         bar
         baz
        +\\ No newline at end of string
      TEXT

      assert_diff actual, expected, <<~TEXT
        --- expected
        +++ actual

         foo
         bar
         baz
        -\\ No newline at end of string
      TEXT

      expected = "foo\nbar\nbaz"
      actual = "foo\nbar\nplop"
      assert_diff actual, expected, <<~TEXT
        --- expected
        +++ actual

         foo
         bar
        -plop
        +baz
      TEXT
    end

    def test_multiline_binary_strings
      expected = "foo\n\xFF\nbaz\n".b
      actual = "foo\n\xFB\nbaz\n".b
      assert_diff expected, actual, <<~'TEXT'
        --- expected
        +++ actual

         foo
        -\xFF
        +\xFB
         baz
      TEXT
    end

    def test_multiline_invalid_encoding_strings
      expected = "foo\n\xFF\nbaz\n"
      actual = "foo\n\xFB\nbaz\n"
      assert_diff expected, actual, <<~'TEXT'
        --- expected
        +++ actual

         foo
        -\xFF
        +\xFB
         baz
      TEXT
    end

    def test_multiline_diff_encoding_strings
      expected = "foo\n€\nbaz\n"
      actual = expected.b
      assert_diff expected, actual, <<~'TEXT'
        --- expected
        +++ actual

        -# encoding: UTF-8
        +# encoding: BINARY
         foo
         \xE2\x82\xAC
         baz
      TEXT
    end

    def test_hash_diff
      expected = { foo: 1, bar: 2, baz: 3 }
      actual = { foo: 1, bar: 4, baz: 3 }

      assert_diff expected, actual, <<~TEXT
        --- expected
        +++ actual

         {
        -  :bar => 2,
        +  :bar => 4,
           :baz => 3,
           :foo => 1,
         }
      TEXT
    end

    def test_nested_hash_diff
      expected = { foo: 1, bar: { egg: { spam: 2 } }, baz: 3 }
      actual = { foo: 1, bar: { plop: { spam: 2 } }, baz: 3 }

      assert_diff expected, actual, <<~TEXT
        --- expected
        +++ actual

         {
        -  :bar => {:egg=>{:spam=>2}},
        +  :bar => {:plop=>{:spam=>2}},
           :baz => 3,
           :foo => 1,
         }
      TEXT
    end

    def test_no_diff
      expected = { foo: 1, bar: 2, baz: 3 }

      assert_diff expected, expected, <<~TEXT
        No visible difference in the Hash#inspect output.
        You should look at the implementation of #== on Hash or its members.
        {:foo=>1, :bar=>2, :baz=>3}
      TEXT
    end

    SomeObject = Struct.new(:a, :b)

    def test_object_diff
      expected = SomeObject.new(1, SomeObject.new(2, SomeObject.new(3, 4)))
      actual = SomeObject.new(1, SomeObject.new(2, SomeObject.new(5, 4)))

      assert_diff expected, actual, <<~TEXT
        --- expected
        +++ actual

          b=
           #<struct Megatest::DifferTest::SomeObject
            a=2,
        -   b=#<struct Megatest::DifferTest::SomeObject a=3, b=4>>>
        +   b=#<struct Megatest::DifferTest::SomeObject a=5, b=4>>>
      TEXT
    end

    private

    def assert_diff(expected, actual, expected_output)
      assert_equal expected_output, normalize(@differ.call(expected, actual))
    end

    def normalize(output)
      output = Output::ANSIColors.strip(output)
      output << "\n" unless output.end_with?("\n")
      output
    end
  end
end
