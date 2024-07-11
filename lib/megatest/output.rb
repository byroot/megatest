# frozen_string_literal: true

module Megatest
  class Output
    module ANSIColors
      extend self

      def strip(text)
        text.gsub(/\e\[\d+m/, "")
      end

      def red(text)
        colorize(text, 31)
      end

      def green(text)
        colorize(text, 32)
      end

      def yellow(text)
        colorize(text, 33)
      end

      def blue(text)
        colorize(text, 34)
      end

      def magenta(text)
        colorize(text, 35)
      end

      def cyan(text)
        colorize(text, 36)
      end

      private

      def colorize(text, color_code)
        "\e[#{color_code}m#{text}\e[0m"
      end
    end

    module NoColors
      extend self

      def red(text)
        text
      end
      alias_method :green, :red
      alias_method :yellow, :red
      alias_method :blue, :red
      alias_method :magenta, :red
      alias_method :cyan, :red
    end

    attr_reader :color

    def initialize(io, colors: nil)
      @io = io
      @colors = colors.nil? ? io.tty? : colors
      @color = @colors ? ANSIColors : NoColors
    end

    def colors?
      @colors
    end

    def colored(text)
      if @colors
        text
      else
        ANSIColors.strip(text)
      end
    end

    def warning(message)
      puts(yellow(message))
    end

    def error(message)
      puts(red(message))
    end

    def print(*args)
      @io.print(*args)
    end

    def puts(*args)
      @io.puts(*args)
    end

    def red(text)
      @color.red(text)
    end

    def green(text)
      @color.green(text)
    end

    def yellow(text)
      @color.yellow(text)
    end

    def blue(text)
      @color.blue(text)
    end

    def magenta(text)
      @color.magenta(text)
    end

    def cyan(text)
      @color.cyan(text)
    end
  end
end
