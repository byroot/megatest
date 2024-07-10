# frozen_string_literal: true

module Megatest
  class Output
    def initialize(io)
      @io = io
      @tty = io.tty?
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
      if @tty
        "\e[#{color_code}m#{text}\e[0m"
      else
        text
      end
    end
  end
end
