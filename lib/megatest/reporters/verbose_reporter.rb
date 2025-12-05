# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Reporters
    class VerboseReporter < SimpleReporter
      def start(executor, _queue)
        @concurrent = executor.concurrent?
      end

      def before_test_case(_queue, test_case)
        unless @concurrent
          @out.print("#{test_case.id} = ")
        end
      end

      def after_test_case(_queue, test_case, result)
        if @concurrent
          @out.print("#{test_case.id} = ")
        end

        if result.skipped?
          @out.print(@out.yellow("SKIPPED"))
        elsif result.retried?
          @out.print(@out.yellow("RETRIED"))
        elsif result.error?
          @out.print(@out.red("ERROR"))
        elsif result.failed?
          @out.print(@out.red("FAILED"))
        else
          @out.print(@out.green("SUCCESS"))
        end

        if result.duration
          @out.print " (in #{result.duration.round(3)}s)"
        end

        @out.puts
        if result.bad?
          @out.puts @out.colored(render_failure(result: result))
        end
      end
    end
  end
end
