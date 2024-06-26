# frozen_string_literal: true

module Megatest
  class Registry
    attr_reader :test_cases

    def initialize
      @test_cases = []
    end

    def add_test_case(test_case)
      state = TestCaseState.new(test_case)
      test_case.instance_variable_set(:@__mega, state)
      @test_cases << state
    end
  end

  singleton_class.attr_accessor :registry
  self.registry = Registry.new

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
end
