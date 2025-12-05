# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Reporters
    class JUnitReporter < AbstractReporter
      def summary(executor, _queue, summary)
        @depth = 0
        @out.puts(%{<?xml version="1.0" encoding="UTF-8"?>})

        results_by_suite = summary.results.map { |r| r.test_id.split("#", 2) << r }.group_by(&:first)

        tag(:testsuites, { time: executor.wall_time }) do
          results_by_suite.each do |testsuite, named_results|
            render_test_suite(testsuite, named_results)
          end
        end
      end

      private

      def attr_escape(string)
        if string.include?('"')
          string.gsub('"', "&quot;")
        else
          string
        end
      end

      def cdata(string)
        string = string.gsub("]]>", "] ]>") if string.include?("]]>")
        "<![CDATA[#{string}]]>"
      end

      using Compat::Tally unless Enumerable.method_defined?(:tally)

      def render_test_suite(testsuite, named_results)
        results = named_results.map(&:last)
        statuses = results.map(&:status).tally

        attributes = {
          name: testsuite,
          filepath: Megatest.relative_path(results.first.test_location.split(":", 2).first),
          tests: results.size,
          assertions: results.sum(&:assertions_count),
          time: results.sum { |r| r.duration || 0.0 },
          failures: statuses.fetch(:failure, 0),
          errors: statuses.fetch(:error, 0),
          skipped: statuses.fetch(:skipped, 0) + statuses.fetch(:retried, 0),
        }

        tag(:testsuite, attributes) do
          named_results.each do |(_, testcase, result)|
            render_test_case(testsuite, testcase, result)
          end
        end
      end

      def render_test_case(testsuite, testcase, result)
        file, line = result.test_location.split(":", 2)
        line.sub!(/~.*/, "")
        file = Megatest.relative_path(file)

        attributes = {
          name: testcase,
          classname: testsuite,
          file: file,
          line: line,
          assertions: result.assertions_count,
          time: result.duration || 0.0,
          "run-command": run_command(result: result),
        }

        if result.success?
          tag(:test_case, attributes)
        elsif result.skipped? || result.retried?
          tag(:test_case, attributes) do
            tag(:skipped, { message: result.failure.message })
          end
        else
          tag(:test_case, attributes) do
            if result.error?
              tag_name = :error
              message = result.failure.message
            else
              tag_name = :failure
              message = "Assertion Failure"
            end
            tag(tag_name, { type: result.failure.name, message: message }, text: cdata(render_failure(result: result, show_command: false)))
          end
        end
      end

      def tag(name, attrs, text: nil)
        indent

        @out << "<#{name}"
        attrs&.each do |attr, value|
          unless value.nil?
            @out << %{ #{attr}="#{attr_escape(value.to_s)}"}
          end
        end

        if block_given?
          @out.puts(">")
          @depth += 1
          yield
          @depth -= 1
          indent
          @out.puts("</#{name}>")
        elsif text
          @out.print(">")
          @out.print(text)
          @out.puts("</#{name}>")
        else
          @out.puts("/>")
        end
      end

      def indent
        @depth.times { @out << "  " }
      end
    end
  end
end
