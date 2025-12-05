# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Reporters
    class OrderReporter < AbstractReporter
      def before_test_case(_queue, test_case)
        @out.puts(test_case.id)
      end
    end
  end
end
