# frozen_string_literal: true

require "test_helper"

class MegatestTest < MegaTestCase
  def test_that_it_has_a_version_number
    refute_nil ::Megatest::VERSION
  end

  def test_loading
    load_fixture("simple/simple_test.rb")
    suite = @registry.test_suites.last

    assert_equal TestedApp::TruthTest, suite.klass
    assert_equal 3, suite.test_cases.size

    first_test = suite.test_cases.first
    assert_equal "the truth", first_test.name
    assert_equal TestedApp::TruthTest, first_test.klass
    assert_equal fixture("simple/simple_test.rb"), first_test.source_file
    assert_equal 9, first_test.source_line

    assert_equal 3, @registry.test_cases.size
  end

  def test_inheritance
    load_fixture("inheritance/inheritance_test.rb")
    cases = @registry.test_cases.sort.map do |test_case|
      "#{test_case.id.ljust(40)} | #{Megatest.relative_path(test_case.source_file)}:#{test_case.source_line}"
    end

    assert_equal <<~CLASSES.strip, cases.join("\n")
      TestedApp::ConcreteATest#concrete A      | fixtures/inheritance/inheritance_test.rb:23
      TestedApp::ConcreteATest#overridable     | fixtures/inheritance/inheritance_test.rb:22
      TestedApp::ConcreteATest#predefined      | fixtures/inheritance/inheritance_test.rb:22
      TestedApp::ConcreteATest#reopened        | fixtures/inheritance/inheritance_test.rb:22
      TestedApp::ConcreteBTest#concrete B      | fixtures/inheritance/inheritance_test.rb:33
      TestedApp::ConcreteBTest#overridable     | fixtures/inheritance/inheritance_test.rb:32
      TestedApp::ConcreteBTest#predefined      | fixtures/inheritance/inheritance_test.rb:32
      TestedApp::ConcreteBTest#reopened        | fixtures/inheritance/inheritance_test.rb:32
    CLASSES
  end

  def test_already_defined
    load_fixture("simple/simple_test.rb")

    assert_raises Megatest::AlreadyDefinedError do
      TestedApp::TruthTest.test "the truth" do
        # noop
      end
    end
  end

  def test_def_style_compatibility
    load_fixture("compat/compat_test.rb")
    assert_equal <<~CLASSES.strip, @registry.test_cases.map(&:id).sort.join("\n")
      TestedApp::CompatTest#test_the_lie
      TestedApp::CompatTest#test_the_truth
      TestedApp::CompatTest#test_the_unexpected
    CLASSES

    first_test = @registry.test_cases.min
    assert_equal "test_the_lie", first_test.name
    result = first_test.run

    assert_equal 1, result.assertions_count
    assert_predicate result, :failed?
  end

  def test_successful_run
    load_fixture("simple/simple_test.rb")

    first_test = @registry.test_cases.first
    assert_equal "the truth", first_test.name
    result = first_test.run

    assert_equal 1, result.assertions_count
    refute_predicate result, :failed?
  end

  def test_failing_run
    load_fixture("simple/simple_test.rb")

    first_test = @registry.test_cases[1]
    assert_equal "the lie", first_test.name
    result = first_test.run

    assert_equal 1, result.assertions_count
    assert_predicate result, :failed?
  end
end
