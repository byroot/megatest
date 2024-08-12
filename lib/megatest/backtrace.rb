# frozen_string_literal: true

module Megatest
  class Backtrace
    module InternalFilter
      class << self
        INTERNAL_PATHS = [
          File.expand_path("../assertions.rb:", __FILE__).freeze,
          File.expand_path("../runtime.rb:", __FILE__).freeze,
        ].freeze

        def call(backtrace)
          backtrace.reject do |frame|
            frame.start_with?(*INTERNAL_PATHS)
          end
        end
      end
    end

    module RelativePathCleaner
      class << self
        def call(path)
          Megatest.relative_path(path)
        end
      end
    end

    attr_accessor :filters, :formatters

    def initialize
      @filters = [InternalFilter]
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
