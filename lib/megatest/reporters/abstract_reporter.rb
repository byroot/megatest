# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Reporters
    class AbstractReporter
      undef_method :puts, :print

      def initialize(config, out)
        @config = config
        @out = Output.new(out, colors: config.colors)
      end

      def start(_executor, _queue)
      end

      def before_test_case(_queue, _test_case)
      end

      def after_test_case(_queue, _test_case, _result)
      end

      def summary(_executor, _queue, _summary)
      end

      private

      def render_failure(result:, show_command: true)
        Announcements::Failure.new(config: @config, out: @out, result: result, show_command: show_command).to_s
      end

      def run_command(result:)
        Snippets::CommandToRerun.new(config: @config, result: result).to_s
      end
    end
  end
end
