# frozen_string_literal: true

module Megatest
  module Selector
    class List
      def initialize(selectors)
        @selectors = selectors
      end

      def main_paths
        paths = @selectors.map(&:path)
        paths.compact!
        paths.uniq!
        paths
      end

      def paths(random:)
        paths = @selectors.reduce([]) do |paths_to_load, selector|
          selector.append_paths(paths_to_load)
        end
        paths.uniq!
        paths.sort!
        paths.shuffle!(random: random) if random
        paths
      end

      def select(registry, random:)
        # If any of the selector points to an exact test or a subset of a suite,
        # then each selector is responsible for shuffling the group of tests it selects,
        # so that tests are shuffled inside groups, but groups are ordered.
        if @selectors.any?(&:partial?)
          @selectors.reduce([]) do |tests_to_run, selector|
            selector.append_tests(tests_to_run, registry, random: random)
          end
        else
          # Otherwise, we do one big shuffle at the end, all groups are mixed.
          test_cases = registry.test_cases
          test_cases.sort!
          test_cases.shuffle!(random: random) if random
          test_cases
        end
      end
    end

    class Base
      attr_reader :path

      def initialize(path)
        @path = File.expand_path(path)
      end

      def append_paths(paths_to_load)
        if @path
          paths_to_load << @path
        end
        paths_to_load
      end

      def append_tests(tests_to_run, registry, random:)
        test_cases = select(registry)
        if partial?
          test_cases.sort!
          test_cases.shuffle!(random: random) if random
        end
        tests_to_run.concat(test_cases)
      end

      def partial?
        raise NotImplementedError
      end

      def select(registry)
        raise NotImplementedError
      end
    end

    class PathSelector < Base
      singleton_class.alias_method(:parse, :new)

      attr_reader :paths

      def initialize(path)
        super
        if @directory = File.directory?(@path)
          @path = File.join(@path, "/")
          @paths = Megatest.glob(@path)
        else
          @paths = [@path]
        end
      end

      def partial?
        false
      end

      def append_paths(paths_to_load)
        paths_to_load.concat(@paths)
      end

      def select(registry)
        if @directory
          registry.test_cases.select do |test_case|
            test_case.source_file.start_with?(@path)
          end
        else
          registry.test_cases_by_path(@path)
        end
      end
    end

    class ExactLineSelector < Base
      class << self
        def parse(arg)
          if match = arg.match(/\A([^:]*):(\d+)(?:~(\d+))?\z/)
            new(match[1], Integer(match[2]), match[3]&.to_i)
          end
        end
      end

      def initialize(path, line, index)
        super(path)
        @line = line
        @index = index
      end

      def partial?
        true
      end

      def select(registry)
        test_cases = registry.test_cases_by_path(@path)
        return [] unless test_cases

        test_cases.sort! { |a, b| b.source_line <=> a.source_line }
        test_cases = test_cases.drop_while { |t| t.source_line > @line }

        # Line not found, fallback to run the whole file?
        return [] if test_cases.empty?

        real_line = test_cases.first&.source_line
        test_cases = test_cases.take_while { |t| t.source_line == real_line }

        if @index
          test_cases.select! { |t| t.index == @index }
        end
        test_cases
      end
    end

    class NameMatchSelector < Base
      class << self
        def parse(arg)
          if match = arg.match(%r{\A([^:]*):/(.+)\z})
            new(match[1], match[2])
          end
        end
      end

      def initialize(path, pattern)
        super(path)
        @pattern = Regexp.new(pattern)
      end

      def partial?
        true
      end

      def select(registry)
        test_cases = registry.test_cases_by_path(@path)
        return [] unless test_cases

        test_cases.select do |t|
          @pattern.match?(t.name) || @pattern.match?(t.id)
        end
      end
    end

    class NameSelector < Base
      class << self
        def parse(arg)
          if match = arg.match(/\A([^:]*):(.+)\z/)
            new(match[1], match[2])
          end
        end
      end

      def initialize(path, name)
        super(path)
        @name = name
      end

      def partial?
        true
      end

      def select(registry)
        test_cases = registry.test_cases_by_path(@path)
        return [] unless test_cases

        test_cases.select do |t|
          @name == t.name || @name == t.id
        end
      end
    end

    class NegativeSelector
      def initialize(selector)
        @selector = selector
      end

      def path
        nil
      end

      def paths
        []
      end

      def partial?
        @selector.partial?
      end

      def append_paths(paths_to_load)
        if @selector.partial?
          paths_to_load
        else
          paths_to_not_load = @selector.append_paths([])
          paths_to_load - paths_to_not_load
        end
      end

      def append_tests(tests_to_run, registry, random:)
        tests_to_not_run = @selector.append_tests([], registry, random: nil)
        tests_to_run - tests_to_not_run
      end
    end

    ALL = [
      ExactLineSelector,
      NameMatchSelector,
      NameSelector,
      PathSelector,
    ].freeze

    class << self
      def parse(argv)
        if argv.empty?
          return List.new([PathSelector.parse("test")])
        end

        argv = argv.dup
        selectors = []

        negative = false

        until argv.empty?
          case argument = argv.shift
          when "!"
            negative = true
          else
            selector = nil
            ALL.each do |selector_class|
              if selector = selector_class.parse(argument)
                break
              end
            end

            if negative
              negative = false
              selector = NegativeSelector.new(selector)
            end

            selectors << selector
          end
        end

        List.new(selectors)
      end
    end
  end
end
