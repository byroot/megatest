# frozen_string_literal: true

# :stopdoc:

module Megatest
  class Output
    module ANSIColors
      extend self

      def strip(text)
        text.gsub(/\e\[(\d+(;\d+)?)?m/, "")
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

      def grey(text)
        # TODO: somehow grey is invisible on my terminal (Terminal.app, Pro theme)
        # Grey for unchanged lines in diff seems like a great idea, but need to figure out
        # when it's safe to use.
        # colorize(text, 8)
        text
      end

      private

      def colorize(text, color_code)
        if text.end_with?("\n")
          "\e[#{color_code}m#{text.delete_suffix("\n")}\e[0m\n"
        else
          "\e[#{color_code}m#{text}\e[0m"
        end
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
      alias_method :grey, :red
    end

    attr_reader :color

    def initialize(io, colors: nil)
      raise ArgumentError, "don't nest outputs" if io.is_a?(Output)

      @io = io
      colors = io.tty? if colors.nil?
      case colors
      when true
        @colors = true
        @color = ANSIColors
      when false
        @colors = false
        @color = NoColors
      else
        @color = colors
        @colors = @color != NoColors
      end
    end

    def colors?
      @colors
    end

    def indent(text, depth: 2)
      prefix = " " * depth
      lines = text.lines
      lines.map! { |l| "#{prefix}#{l}" }
      lines.join
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

    def <<(str)
      @io << str
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

    def grey(text)
      @color.grey(text)
    end
  end
end
