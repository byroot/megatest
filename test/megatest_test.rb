# frozen_string_literal: true

require "test_helper"

class MegatestTest < MegaTestCase
  def test_that_it_has_a_version_number
    refute_nil ::Megatest::VERSION
  end

  def test_loading
    load_fixture("simple.rb")
    suite = @registry.test_suites.last

    assert_equal TestedApp::TruthTest, suite.klass
    assert_equal 2, suite.test_cases.size

    first_test = suite.test_cases.first
    assert_equal "the truth", first_test.name
    assert_equal TestedApp::TruthTest, first_test.klass
    assert_equal fixture("simple.rb"), first_test.source_file
    assert_equal 9, first_test.source_line

    assert_equal 2, @registry.test_cases.size
  end
end
