# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Reporters
    class AbstractReporter
      undef_method :puts, :print

      def initialize(config, out)
        @config = config
        @out = Output.new(out, colors: config.colors)
      end

      def start(_executor, _queue)
      end

      def before_test_case(_queue, _test_case)
      end

      def after_test_case(_queue, _test_case, _result)
      end

      def summary(_executor, _queue, _summary)
      end

      private

      LABELS = {
        retried: "Retried",
        error: "Error",
        failure: "Failure",
        skipped: "Skipped",
      }.freeze

      def render_failure(result, command: true)
        str = "#{LABELS.fetch(result.status)}: #{result.test_id}\n"
        str = if result.retried? || result.skipped?
          @out.yellow(str)
        else
          @out.red(str)
        end
        str = +str
        str << "\n"

        if result.error?
          str << @out.indent("#{result.failure.cause.name}: #{@out.colored(result.failure.cause.message)}\n")
        elsif result.failed?
          str << @out.indent(@out.colored(result.failure.message.to_s))
        end
        str << "\n" unless str.end_with?("\n")
        str << "\n"

        @config.backtrace.clean(result.failure.backtrace)&.each do |frame|
          str << "  #{@out.cyan(frame)}\n"
        end

        if command
          str << "\n"
          str << @out.yellow(run_command(result))
        end

        str
      end

      def run_command(result)
        "#{@config.program_name} #{Megatest.relative_path(result.test_location)}"
      end
    end

    class SimpleReporter < AbstractReporter
      def start(_executor, queue)
        @out.puts("Running #{queue.size} test cases with --seed #{@config.seed}")
        @out.puts
      end

      def after_test_case(_queue, _test_case, result)
        if result.skipped?
          @out.print(@out.yellow("S"))
        elsif result.retried?
          @out.print(@out.yellow("R"))
        elsif result.error?
          @out.print(@out.red("E"))
        elsif result.failed?
          @out.print(@out.red("F"))
        else
          @out.print(@out.green("."))
        end
      end

      def summary(executor, queue, summary)
        @out.puts
        @out.puts

        failures = summary.failures.reject(&:skipped?)
        unless failures.empty?
          failures = failures.sort_by(&:test_id)
          failures.each_with_index do |result, index|
            @out.print "  #{index + 1}) "
            @out.puts render_failure(result)
            @out.puts
          end
        end

        # In case of failure we'd rather not print slow tests
        # as it would blur the output.
        if queue.success? && !summary.results.empty?
          sorted_results = summary.results.sort_by(&:duration)
          size = sorted_results.size
          average = sorted_results.sum(&:duration) / size
          median = sorted_results[size / 2].duration
          p90 = sorted_results[(size * 0.9).to_i].duration
          p99 = sorted_results[(size * 0.99).to_i].duration

          @out.puts "Finished in #{s(executor.wall_time.to_f)}, average: #{ms(average)}, median: #{ms(median)}, p90: #{ms(p90)}, p99: #{ms(p99)}"
          cutoff = p90 * 10
          slowest_tests = sorted_results.last(5).select { |r| r.duration > cutoff }
          unless slowest_tests.empty?
            @out.puts "Slowest tests:"
            slowest_tests.reverse_each do |result|
              duration_string = ms(result.duration).rjust(10, " ")
              @out.puts " - #{duration_string} #{@out.yellow(result.test_id)} @ #{@out.cyan(Megatest.relative_path(result.test_location))}"
            end
            @out.puts ""
          end
        end

        @out.puts format(
          "Ran %d cases, %d assertions, %d failures, %d errors, %d retries, %d skips",
          summary.runs_count,
          summary.assertions_count,
          summary.failures_count,
          summary.errors_count,
          summary.retries_count,
          summary.skips_count,
        )
      end

      def s(duration)
        format("%.2fs", duration)
      end

      def ms(duration)
        format("%.1fms", duration * 1000.0)
      end
    end

    class VerboseReporter < SimpleReporter
      def start(executor, _queue)
        @concurrent = executor.concurrent?
      end

      def before_test_case(_queue, test_case)
        unless @concurrent
          @out.print("#{test_case.id} = ")
        end
      end

      def after_test_case(_queue, test_case, result)
        if @concurrent
          @out.print("#{test_case.id} = ")
        end

        if result.skipped?
          @out.print(@out.yellow("SKIPPED"))
        elsif result.retried?
          @out.print(@out.yellow("RETRIED"))
        elsif result.error?
          @out.print(@out.red("ERROR"))
        elsif result.failed?
          @out.print(@out.red("FAILED"))
        else
          @out.print(@out.green("SUCCESS"))
        end

        if result.duration
          @out.print " (in #{result.duration.round(3)}s)"
        end

        @out.puts
        if result.bad?
          @out.puts @out.colored(render_failure(result))
        end
      end
    end

    class OrderReporter < AbstractReporter
      def before_test_case(_queue, test_case)
        @out.puts(test_case.id)
      end
    end

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
          "run-command": run_command(result),
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
            tag(tag_name, { type: result.failure.name, message: message }, text: cdata(render_failure(result, command: false)))
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
