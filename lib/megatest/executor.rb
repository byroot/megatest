# frozen_string_literal: true

module Megatest
  class Executor
    attr_reader :test_suites, :test_cases

    def initialize(registry, reporters)
      @reporters = reporters
      @test_suites = registry.test_suites
      @test_cases = registry.test_cases
    end

    def run
      @test_cases.sort!
      @test_cases.shuffle!(random: Megatest.seed)

      @reporters.each { |r| r.start(self) }

      @test_cases.each do |test_case|
        @reporters.each { |r| r.before_test_case(self, test_case) }
        result = test_case.run
        @reporters.each { |r| r.after_test_case(self, test_case, result) }
      end

      @reporters.each { |r| r.summary(self) }
    end
  end
end
