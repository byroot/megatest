# frozen_string_literal: true

module Megatest
  class Differ
    HEADER = "+++ expected\n--- actual\n\n"

    def initialize(config)
      @config = config
    end

    using Compat::ByteRIndex unless String.method_defined?(:byterindex)

    def call(expected, actual)
      if String === expected && String === actual
        if expected.byterindex("\n", -1) || actual.byterindex("\n", -1)
          multiline_string_diff(expected, actual)
        else
          single_line_string_diff(expected, actual)
        end
      elsif Array === expected && Array === actual
        array_diff(expected, actual)
      elsif Hash === expected && Hash === actual
        hash_diff(expected, actual)
      end
    end

    private

    def pp(object)
      @config.pretty_print(object)
    end

    def multiline_string_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)
      diff = differ.diff_text(expected, actual)
      "#{HEADER}#{diff}"
    end

    def single_line_string_diff(expected, actual)
      "Expected: #{pp(expected)}\n  Actual: #{pp(actual)}"
    end

    def array_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)
      diff = differ.diff_sequences(array_sequence(expected), array_sequence(actual))
      "#{HEADER}#{diff.join}"
    end

    def array_sequence(array)
      array = array.map { |e| "  ".dup << pp(e).chomp << ",\n" }
      array.unshift("[\n")
      array << "]\n"
    end

    def hash_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)
      expected, actual = hash_sort(expected, actual)
      diff = differ.diff_sequences(hash_sequence(expected), hash_sequence(actual))
      "#{HEADER}#{diff.join}"
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
