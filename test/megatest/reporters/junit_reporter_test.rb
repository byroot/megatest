# frozen_string_literal: true

module Megatest
  module Reporters
    class JUnitReporterTest < MegaTestCase
      setup do
        @out = @io = StringIO.new
        @config.colors = false
        @reporter = JUnitReporter.new(@config, @out)
        @executor = Struct.new(:wall_time).new(4.2)

        load_fixture("simple/simple_test.rb")
        @test_cases = @registry.test_cases
      end

      test "render empty results" do
        summary = Queue::Summary.new([])
        @reporter.summary(@executor, :__unused_queue__, summary)
        assert_equal <<~XML, @io.string
          <?xml version="1.0" encoding="UTF-8"?>
          <testsuites time="4.2">
          </testsuites>
        XML
      end

      test "render success" do
        summary = Queue::Summary.new([
          build_success(@test_cases[0]),
          build_success(@test_cases[1]),
        ])
        @reporter.summary(@executor, :__unused_queue__, summary)
        assert_equal <<~XML, @io.string
          <?xml version="1.0" encoding="UTF-8"?>
          <testsuites time="4.2">
            <testsuite name="TestedApp::TruthTest" filepath="fixtures/simple/simple_test.rb" tests="2" assertions="8" time="0.84" failures="0" errors="0" skipped="0">
              <test_case name="the truth" classname="TestedApp::TruthTest" file="fixtures/simple/simple_test.rb" line="9" assertions="4" time="0.42" run-command="megatest fixtures/simple/simple_test.rb:9"/>
              <test_case name="the lie" classname="TestedApp::TruthTest" file="fixtures/simple/simple_test.rb" line="13" assertions="4" time="0.42" run-command="megatest fixtures/simple/simple_test.rb:13"/>
            </testsuite>
          </testsuites>
        XML
      end

      test "render failure" do
        summary = Queue::Summary.new([
          build_failure(@test_cases.first),
        ])
        @reporter.summary(@executor, :__unused_queue__, summary)
        assert_equal <<~XML, @io.string
          <?xml version="1.0" encoding="UTF-8"?>
          <testsuites time="4.2">
            <testsuite name="TestedApp::TruthTest" filepath="fixtures/simple/simple_test.rb" tests="1" assertions="0" time="0.42" failures="1" errors="0" skipped="0">
              <test_case name="the truth" classname="TestedApp::TruthTest" file="fixtures/simple/simple_test.rb" line="9" assertions="0" time="0.42" run-command="megatest fixtures/simple/simple_test.rb:9">
                <failure type="Megatest::Assertion" message="Assertion Failure"><![CDATA[Failure: TestedApp::TruthTest#the truth

            2 + 2 != 5

            test/my_app_test.rb:42:in `block in <class:MyAppTest>'
          ]]></failure>
              </test_case>
            </testsuite>
          </testsuites>
        XML
      end

      test "render error" do
        summary = Queue::Summary.new([
          build_error(@test_cases.first),
        ])
        @reporter.summary(@executor, :__unused_queue__, summary)
        assert_equal <<~XML, @io.string
          <?xml version="1.0" encoding="UTF-8"?>
          <testsuites time="4.2">
            <testsuite name="TestedApp::TruthTest" filepath="fixtures/simple/simple_test.rb" tests="1" assertions="0" time="0.42" failures="0" errors="1" skipped="0">
              <test_case name="the truth" classname="TestedApp::TruthTest" file="fixtures/simple/simple_test.rb" line="9" assertions="0" time="0.42" run-command="megatest fixtures/simple/simple_test.rb:9">
                <error type="Megatest::UnexpectedError" message="Unexpected exception"><![CDATA[Error: TestedApp::TruthTest#the truth

            RuntimeError: oops

            app/my_app.rb:35:in `block in some_method'
            test/my_app_test.rb:42:in `block in <class:MyAppTest>'
          ]]></error>
              </test_case>
            </testsuite>
          </testsuites>
        XML
      end

      test "render skip" do
        summary = Queue::Summary.new([
          build_skip(@test_cases.first),
        ])
        @reporter.summary(@executor, :__unused_queue__, summary)
        assert_equal <<~XML, @io.string
          <?xml version="1.0" encoding="UTF-8"?>
          <testsuites time="4.2">
            <testsuite name="TestedApp::TruthTest" filepath="fixtures/simple/simple_test.rb" tests="1" assertions="0" time="0.42" failures="0" errors="0" skipped="1">
              <test_case name="the truth" classname="TestedApp::TruthTest" file="fixtures/simple/simple_test.rb" line="9" assertions="0" time="0.42" run-command="megatest fixtures/simple/simple_test.rb:9">
                <skipped message="Nah..."/>
              </test_case>
            </testsuite>
          </testsuites>
        XML
      end
    end
  end
end
