# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Selector
    class List
      def initialize(loaders, filters)
        @loaders = loaders
        if loaders.empty?
          @loaders = [Loader.new("test")]
        end
        @filters = filters
      end

      def main_paths
        paths = @loaders.map(&:path)
        paths.compact!
        paths.uniq!
        paths
      end

      def paths(random:)
        paths = @loaders.reduce([]) do |paths_to_load, loader|
          loader.append_paths(paths_to_load)
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
        test_cases = if @loaders.any?(&:partial?)
          @loaders.reduce([]) do |tests_to_run, loader|
            loader.append_tests(tests_to_run, registry, random: random)
          end
        else
          # Otherwise, we do one big shuffle at the end, all groups are mixed.
          test_cases = registry.test_cases
          test_cases.sort!
          test_cases.shuffle!(random: random) if random
          test_cases
        end

        @filters.reduce(test_cases) do |cases, filter|
          filter.select(cases)
        end
      end
    end

    class Loader
      attr_reader :path

      def initialize(path, filter = nil)
        @path = File.expand_path(path)
        if @directory = File.directory?(@path)
          @path = File.join(@path, "/")
          @paths = Megatest.glob(@path)
        else
          @paths = [@path]
        end
        @filter = filter
      end

      def partial?
        !!@filter
      end

      def append_tests(tests_to_run, registry, random:)
        test_cases = select(registry)
        if partial?
          test_cases.sort!
          test_cases.shuffle!(random: random) if random
        end
        tests_to_run.concat(test_cases)
      end

      def append_paths(paths_to_load)
        paths_to_load.concat(@paths)
      end

      def select(registry)
        test_cases = if @directory
          registry.test_cases.select do |test_case|
            test_case.source_file.start_with?(@path)
          end
        else
          registry.test_cases_by_path(@path)
        end

        if @filter
          @filter.select(test_cases)
        else
          test_cases
        end
      end
    end

    class NegativeLoader
      def initialize(loader)
        @loader = loader
      end

      def partial?
        @loader.partial?
      end

      def append_paths(paths_to_load)
        if @loader.partial?
          paths_to_load
        else
          paths_to_not_load = @loader.append_paths([])
          paths_to_load - paths_to_not_load
        end
      end

      def append_tests(tests_to_run, registry, random:)
        tests_to_not_run = @loader.append_tests([], registry, random: nil)
        tests_to_run - tests_to_not_run
      end
    end

    class TagFilter
      class << self
        def parse(arg)
          if match = arg.match(/\A@([\w-]+)(?:=(.*))?\z/)
            new(match[1], match[2])
          end
        end
      end

      def initialize(tag, value)
        @tag = tag.to_sym
        @value = value
      end

      def select(test_cases)
        if @value
          test_cases.select do |test_case|
            test_case.tag(@tag).to_s == @value
          end
        else
          test_cases.select do |test_case|
            test_case.tag(@tag)
          end
        end
      end
    end

    class ExactLineFilter
      class << self
        def parse(arg)
          if match = arg.match(/\A(\d+)(?:~(\d+))?\z/)
            new(Integer(match[1]), match[2]&.to_i)
          end
        end
      end

      def initialize(line, index)
        @line = line
        @index = index
      end

      def select(test_cases)
        test_cases = test_cases.sort { |a, b| b.source_line <=> a.source_line }
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

    class NameMatchFilter
      class << self
        def parse(arg)
          if match = arg.match(%r{\A/(.+)\z})
            new(match[1])
          end
        end
      end

      def initialize(pattern)
        @pattern = Regexp.new(pattern)
      end

      def select(test_cases)
        test_cases.select do |t|
          @pattern.match?(t.name) || @pattern.match?(t.id)
        end
      end
    end

    class NameFilter
      class << self
        def parse(arg)
          if match = arg.match(/\A#(.+)\z/)
            new(match[1])
          end
        end
      end

      def initialize(name)
        @name = name
      end

      def select(test_cases)
        test_cases.select do |t|
          @name == t.name || @name == t.id
        end
      end
    end

    class NegativeFilter
      def initialize(filter)
        @filter = filter
      end

      def select(test_cases)
        test_cases - @filter.select(test_cases)
      end
    end

    FILTERS = [
      ExactLineFilter,
      TagFilter,
      NameMatchFilter,
      NameFilter,
    ].freeze

    class << self
      def parse(argv)
        if argv.empty?
          return List.new([PathSelector.parse("test")])
        end

        argv = argv.dup
        loaders = []
        filters = []

        negative = false

        until argv.empty?
          case argument = argv.shift
          when "!"
            negative = true
          else
            loader_str, filter_str = argument.split(":", 2)
            loader_str = nil if loader_str.empty?

            filter = nil
            if filter_str
              FILTERS.each do |filter_class|
                if filter = filter_class.parse(filter_str)
                  break
                end
              end
            end

            if loader_str
              loader = Loader.new(loader_str, filter)
              if negative
                loader = NegativeLoader.new(loader)
                negative = false
              end
              loaders << loader
            else
              if negative
                filter = NegativeFilter.new(filter)
                negative = false
              end
              filters << filter
            end
          end
        end

        List.new(loaders, filters)
      end
    end
  end
end
