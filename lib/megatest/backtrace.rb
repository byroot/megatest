# frozen_string_literal: true

module Megatest
  module Backtrace
    class << self
      attr_accessor :filters, :formatters

      def clean(backtrace)
        format(filter(backtrace))
      end

      def filter(backtrace)
        if backtrace
          filters.each do |filter|
            backtrace = filter.call(backtrace)
          end
          backtrace
        else
          []
        end
      end

      def format(backtrace)
        backtrace.map do |frame|
          formatters.each do |formatter|
            frame = formatter.call(frame)
          end
          frame
        end
      end
    end

    self.filters = []
    self.formatters = []

    # Remove traces of Megatest itself from backtraces
    MegatestFilter = lambda do |backtrace|
      backtrace = backtrace.drop_while { |f| f.start_with?(Megatest::ROOT) }

      # This unfortunately is a bit fragile. I'd like to find a better way
      backtrace = backtrace.take_while { |f| !f.start_with?(Megatest::ROOT) && !f.end_with?("instance_exec'") }
      backtrace
    end

    RelativePathCleaner = Megatest.method(:relative_path)

    self.filters = [MegatestFilter]
    self.formatters = [RelativePathCleaner]
  end
end
