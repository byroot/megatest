# frozen_string_literal: true

module Megatest
  module Reporters
    module Announcements
      class Failure
        LABELS = {
          retried: "Retried",
          error: "Error",
          failure: "Failure",
          skipped: "Skipped",
        }.freeze

        def initialize(config:, out:, result:, show_command: true)
          @config = config
          @out = out
          @result = result
          @show_command = show_command
        end

        def to_s
          str = status_and_id
          str << "\n"

          if result.error?
            str << out.indent("#{result.failure.cause.name}: #{out.colored(result.failure.cause.message)}\n")
          elsif result.failed?
            str << out.indent(out.colored(result.failure.message.to_s))
          end

          str << "\n" unless str.end_with?("\n")
          str << "\n"

          config.backtrace.clean(result.failure.backtrace)&.each do |frame|
            str << "  #{out.cyan(frame)}\n"
          end

          if show_command
            str << "\n"
            str << out.yellow(Snippets::CommandToRerun.new(config: config, result: result).to_s)
          end

          str
        end

        private

        attr_reader :config, :out, :result, :show_command

        def status_and_id
          message = "#{LABELS.fetch(result.status)}: #{result.test_id}\n"

          if result.retried? || result.skipped?
            out.yellow(message)
          else
            out.red(message)
          end
        end
      end
    end
  end
end
