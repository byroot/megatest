# frozen_string_literal: true

module Megatest
  class Executor
    attr_reader :test_suites, :test_cases

    def initialize(registry)
      @test_suites = registry.test_suites
      @test_cases = registry.test_cases
    end

    def run
      @test_cases.sort!
      @test_cases.shuffle!(random: Megatest.seed)
      @test_cases.map(&:run)
    end
  end
end
