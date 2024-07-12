# frozen_string_literal: true

module Megatest
  class Backtrace
    RelativePathCleaner = Megatest.method(:relative_path)

    attr_accessor :filters, :formatters

    def initialize
      @filters = []
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
