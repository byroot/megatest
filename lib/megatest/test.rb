# frozen_string_literal: true

module Megatest
  class BlockTest
    attr_reader :klass, :name, :block, :source_file, :source_line

    def initialize(klass, name, block, source_file, source_line)
      @klass = klass
      @name = name
      @block = block
      @source_file = source_file
      @source_line = source_line
    end
  end

  class TestCaseState
    attr_reader :tests

    def initialize(test_case)
      @test_case = test_case
      @tests = []
    end

    def register_test(klass, name, block, source_path, source_line)
      @tests << BlockTest.new(klass, name, block, source_path, source_line)
    end
  end

  class TestState
    attr_accessor :assertions

    def initialize
      @assertions = 0
    end
  end

  class Test
    class << self
      def __mega_state
        @__mega_state ||= ::Megatest::TestCaseState.new(self)
      end

      def test(name, &block)
        location = caller_locations(1, 1).first
        __mega_state.register_test(self, -name, block, location&.path, location&.lineno)
      end
    end

    def initialize(mega_state)
      @__mega_state = mega_state
    end
  end
end
