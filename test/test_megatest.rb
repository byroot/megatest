# frozen_string_literal: true

require "test_helper"

class TestMegatest < Minitest::Test
  def teardown
    Object.send(:remove_const, :TestedApp) if defined?(::TestedApp)
  end

  def test_that_it_has_a_version_number
    refute_nil ::Megatest::VERSION
  end

  def test_loading
    Kernel.load(fixture("simple.rb"))
    state = TestedApp::TruthTest.__mega_state

    assert_equal 2, state.tests.size

    first_test = state.tests.first
    assert_equal "the truth", first_test.name
    assert_equal TestedApp::TruthTest, first_test.klass
    assert_equal fixture("simple.rb"), first_test.source_file
    assert_equal 9, first_test.source_line
  end

  private

  def fixture(path)
    File.join(File.expand_path("../fixtures", __FILE__), path)
  end
end
