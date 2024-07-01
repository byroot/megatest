# frozen_string_literal: true

module Megatest
  module Selector
    class Set
      def initialize(selectors)
        @selectors = selectors
      end

      def paths
        @selectors.map(&:path).uniq
      end

      def select(registry)
        @selectors.sum([]) { |s| s.select(registry) }
      end
    end

    class PathSelector
      singleton_class.alias_method(:parse, :new)

      attr_reader :path

      def initialize(path)
        @directory = File.directory?(path)
        @path = File.expand_path(path)
        if @directory
          @path = File.join(@path, "/")
        end
      end

      def select(registry)
        if @directory
          registry.test_cases.select do |test_case|
            test_case.source_file.start_with?(@path)
          end
        else
          registry.test_cases_by_path[@path] || []
        end
      end

      def match?(test_case)
        if @directory
          test_case.source_file.start_with?(@path)
        else
          path == test_case.source_file
        end
      end
    end

    class ExactLineSelector
      class << self
        def parse(arg)
          if match = arg.match(/\A([^:]*):(\d+)\z/)
            new(match[1], Integer(match[2]))
          end
        end
      end

      attr_reader :path

      def initialize(path, line)
        @path = File.expand_path(path)
        @line = line
      end

      def select(registry)
        test_cases = registry.test_cases_by_path[@path]
        return [] unless test_cases

        sorted_cases = test_cases.sort { |a, b| b.source_line <=> a.source_line }
        start_index = test_cases.bsearch_index { |t| t.source_line > @line }

        # Line not found, fallback to run the whole file?
        return test_cases if start_index.nil? || start_index.zero?

        actual_line = test_cases[start_index - 1].source_line

        # We might be able to be smarter and not scan the whole array here
        sorted_cases.select { |t| t.source_line == actual_line }
      end

      def match?(test_case)
        path == test_case.source_file &&
          @line == test_case.line
      end
    end

    class NameMatchSelector
      class << self
        def parse(arg)
          if match = arg.match(%r{\A([^:]*):/(.+)\z})
            new(match[1], match[2])
          end
        end
      end

      attr_reader :path

      def initialize(path, pattern)
        @path = File.expand_path(path)
        @pattern = Regexp.new(pattern)
      end

      def select(registry)
        test_cases = registry.test_cases_by_path[@path]
        return [] unless test_cases

        test_cases.select do |t|
          @pattern.match?(t.name) || @pattern.match?(t.id)
        end
      end

      def match?(test_case)
        @pattern.match?(test_case.name) || @pattern.match?(test_case.id)
      end
    end

    class NameSelector
      class << self
        def parse(arg)
          if match = arg.match(/\A([^:]*):(.+)\z/)
            new(match[1], match[2])
          end
        end
      end

      attr_reader :path

      def initialize(path, name)
        @path = File.expand_path(path)
        @name = name
      end

      def select(registry)
        test_cases = registry.test_cases_by_path[@path]
        return [] unless test_cases

        test_cases.select do |t|
          @name == t.name || @name == t.id
        end
      end

      def match?(test_case)
        @name == test_case.name || @name == test_case.id
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
        argv = argv.dup
        selectors = []

        until argv.empty?
          argument = argv.shift
          case argument
          when "-n"
            if name = argv.shift
              selectors << NameSelector.new(name)
            else
              raise "Missing -n argument"
            end
          else
            ALL.each do |selector_class|
              if selector = selector_class.parse(argument)
                selectors << selector
                break
              end
            end
          end
        end

        Set.new(selectors)
      end
    end
  end
end
