# frozen_string_literal: true

module Megatest
  class Differ
    HEADER = "++ expected\n-- actual\n\n"
    def initialize(config)
      @config = config
    end

    def call(expected, actual)
      if expected.is_a?(String) && actual.is_a?(String)
        return unless expected.include?("\n")

        string_diff(expected, actual)
      end
    end

    def string_diff(expected, actual)
      color = @config.colors ? Output::ANSIColors : Output::NoColors
      differ = PatienceDiff::Differ.new(color: color)
      diff = differ.diff_sequences(expected.lines, actual.lines)
      "#{HEADER}#{diff.join}"
    end
  end
end
