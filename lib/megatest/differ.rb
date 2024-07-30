# frozen_string_literal: true

# :stopdoc:

module Megatest
  class Differ
    HEADER = "--- expected\n+++ actual\n\n"

    def initialize(config)
      @config = config
    end

    using Compat::ByteRIndex unless String.method_defined?(:byterindex)

    def call(expected, actual)
      if String === expected && String === actual
        if multiline?(expected) || multiline?(actual)
          multiline_string_diff(expected, actual)
        else
          single_line_string_diff(expected, actual)
        end
      elsif Array === expected && Array === actual
        array_diff(expected, actual)
      elsif Hash === expected && Hash === actual
        hash_diff(expected, actual)
      else
        expected_inspect = pp(expected)
        actual_inspect = pp(actual)

        if multiline?(expected_inspect) || multiline?(actual_inspect)
          object_diff(expected, expected_inspect, actual_inspect)
        end
      end
    end

    private

    def pp(object)
      @config.pretty_print(object)
    end

    def object_diff(expected, expected_inspect, actual_inspect)
      differ = PatienceDiff::Differ.new(@config.colors)
      diff = differ.diff_text(expected_inspect, actual_inspect)
      render_diff(expected, diff)
    end

    def multiline_string_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)

      if expected.encoding != actual.encoding
        expected = encoding_prefix(expected) << expected
        actual = encoding_prefix(actual) << actual
      end

      if need_escape?(expected) || need_escape?(actual)
        expected = escape_string(expected)
        actual = escape_string(actual)
      end

      if expected.end_with?("\n") ^ actual.end_with?("\n")
        expected = "#{expected}\n\\ No newline at end of string" unless expected.end_with?("\n")
        actual = "#{actual}\n\\ No newline at end of string" unless actual.end_with?("\n")
      end
      diff = differ.diff_text(expected, actual)
      render_diff(expected, diff)
    end

    def multiline?(string)
      string.byterindex("\n", -1)
    end

    def render_diff(expected, diff)
      if diff
        "#{HEADER}#{diff.join}"
      else
        <<~TEXT
          No visible difference in the #{expected.class}#inspect output.
          You should look at the implementation of #== on #{expected.class.name} or its members.
          #{pp(expected)}
        TEXT
      end
    end

    def encoding_prefix(string)
      encoding_name = string.encoding == Encoding::BINARY ? "BINARY" : string.encoding.name
      prefix = +"# encoding: #{encoding_name}\n"
      prefix.force_encoding(string.encoding)
    end

    def escape_string(string)
      string.b.split("\n").map { |line| line.inspect.byteslice(1..-2) }.join("\n")
    end

    def need_escape?(string)
      (string.encoding == Encoding::BINARY && !string.ascii_only?) || !string.valid_encoding?
    end

    def single_line_string_diff(expected, actual)
      "Expected: #{pp(expected)}\n  Actual: #{pp(actual)}"
    end

    def array_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)
      diff = differ.diff_sequences(array_sequence(expected), array_sequence(actual))
      render_diff(expected, diff)
    end

    def array_sequence(array)
      array = array.map { |e| "  ".dup << pp(e).chomp << ",\n" }
      array.unshift("[\n")
      array << "]\n"
    end

    def hash_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)
      expected_seq, actual_seq = hash_sort(expected, actual)
      diff = differ.diff_sequences(hash_sequence(expected_seq), hash_sequence(actual_seq))
      render_diff(expected, diff)
    end

    def hash_sort(expected, actual)
      [expected.sort, actual.sort]
    rescue ArgumentError
      [expected, actual]
    end

    def hash_sequence(pairs)
      pairs = pairs.map do |k, v|
        "  ".dup << pp(k) << " => " << pp(v).chomp << ",\n"
      end
      pairs.unshift("{\n")
      pairs << "}\n"
    end
  end
end
