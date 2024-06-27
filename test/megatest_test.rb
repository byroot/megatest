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
