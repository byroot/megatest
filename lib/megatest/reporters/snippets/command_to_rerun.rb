# frozen_string_literal: true

module Megatest
  module Reporters
    module Snippets
      class CommandToRerun
        def initialize(config:, result:)
          @config = config
          @result = result
        end

        def to_s
          "#{config.program_name} #{Megatest.relative_path(result.test_location)}"
        end

        private

        attr_reader :config, :result
      end
    end
  end
end
