# frozen_string_literal: true

module Megatest
  class Backtrace
    # Remove traces of Megatest itself from backtraces
    MegatestFilter = lambda do |backtrace|
      backtrace = backtrace.drop_while { |f| f.start_with?(Megatest::ROOT) }

      # This unfortunately is a bit fragile. I'd like to find a better way
      backtrace = backtrace.take_while { |f| !f.start_with?(Megatest::ROOT) && !f.end_with?("instance_exec'") }
      backtrace
    end

    RelativePathCleaner = Megatest.method(:relative_path)

    attr_accessor :filters, :formatters

    def initialize
      @filters = [MegatestFilter]
      @formatters = [RelativePathCleaner]
      @full = false
    end

    def full!
      @full = true
    end

    def clean(backtrace)
      return backtrace if @full

      format(filter(backtrace))
    end

    def filter(backtrace)
      return backtrace if @full

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
      return backtrace if @full

      backtrace.map do |frame|
        formatters.each do |formatter|
          frame = formatter.call(frame)
        end
        frame
      end
    end
  end
end
