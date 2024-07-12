# frozen_string_literal: true

module Megatest
  class Differ
    HEADER = "+++ expected\n--- actual\n\n"

    def initialize(config)
      @config = config
    end

    def call(expected, actual)
      if expected.is_a?(String) && actual.is_a?(String)
        return unless expected.include?("\n")

        string_diff(expected, actual)
      elsif expected.is_a?(Array) && actual.is_a?(Array)
        array_diff(expected, actual)
      elsif expected.is_a?(Hash) && actual.is_a?(Hash)
        hash_diff(expected, actual)
      end
    end

    private

    def string_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)
      diff = differ.diff_text(expected, actual)
      "#{HEADER}#{diff}"
    end

    def array_diff(expected, actual)
      differ = PatienceDiff::Differ.new(@config.colors)
      diff = differ.diff_sequences(array_sequence(expected), array_sequence(actual))
      "#{HEADER}#{diff.join}"
    end

    def array_sequence(array)
      array = array.map { |e| "  ".dup << @config.pretty_print(e).chomp << ",\n" }
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
        "  ".dup << @config.pretty_print(k) << " => " << @config.pretty_print(v).chomp << ",\n"
      end
      pairs.unshift("{\n")
      pairs << "}\n"
    end
  end
end
