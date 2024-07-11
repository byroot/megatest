# frozen_string_literal: true

class MegatestTest < MegaTestCase
  def test_that_it_has_a_version_number
    refute_nil ::Megatest::VERSION
  end

  def test_loading
    load_fixture("simple/simple_test.rb")
    suite = @registry.test_suites.last

    assert_equal TestedApp::TruthTest, suite.klass
    assert_equal 4, suite.test_cases.size

    first_test = suite.test_cases.first
    assert_equal "the truth", first_test.name
    assert_equal TestedApp::TruthTest, first_test.klass
    assert_equal fixture("simple/simple_test.rb"), first_test.source_file
    assert_equal 9, first_test.source_line

    assert_equal 4, @registry.test_cases.size
  end

  def test_inheritance
    load_fixture("inheritance/inheritance_test.rb")
    cases = @registry.test_cases.sort
    padding = cases.map { |t| t.id.size }.max + 2
    cases = @registry.test_cases.sort.map do |test_case|
      "#{test_case.id.ljust(padding)} | #{Megatest.relative_path(test_case.source_file)}:#{test_case.source_line}"
    end

    file = "fixtures/inheritance/inheritance_test.rb"

    assert_equal <<~CLASSES.strip, cases.join("\n")
      TestedApp::BaseCase#overridable               | test_helper.rb:#{TestedApp::BaseCase::OVERRIDABLE_LINE}
      TestedApp::BaseCase#predefined                | test_helper.rb:#{TestedApp::BaseCase::PREDEFINED_LINE}
      TestedApp::BaseCase#reopened                  | another_test_helper.rb:#{TestedApp::BaseCase::REOPENED_LINE}
      TestedApp::ConcreteATest#concrete A           | #{file}:#{TestedApp::ConcreteATest::TEST_1_LINE}
      TestedApp::ConcreteATest#overridable          | #{file}:#{TestedApp::ConcreteATest::TEST_2_LINE}
      TestedApp::ConcreteATest#predefined           | #{file}:#{TestedApp::ConcreteATest::LINE}
      TestedApp::ConcreteATest#reopened             | #{file}:#{TestedApp::ConcreteATest::LINE}
      TestedApp::ConcreteATest#shared               | #{file}:#{TestedApp::ConcreteATest::SHARED_TESTS_LINE}
      TestedApp::ConcreteATest#test_compat_shared   | #{file}:#{TestedApp::ConcreteATest::SHARED_COMPAT_TESTS_LINE}
      TestedApp::ConcreteBTest#concrete B           | #{file}:#{TestedApp::ConcreteBTest::TEST_1_LINE}
      TestedApp::ConcreteBTest#overridable          | #{file}:#{TestedApp::ConcreteBTest::TEST_2_LINE}
      TestedApp::ConcreteBTest#predefined           | #{file}:#{TestedApp::ConcreteBTest::LINE}
      TestedApp::ConcreteBTest#reopened             | #{file}:#{TestedApp::ConcreteBTest::LINE}
    CLASSES
  end

  def test_already_defined
    load_fixture("simple/simple_test.rb")

    assert_raises Megatest::AlreadyDefinedError do
      Megatest.with_registry(@registry) do
        TestedApp::TruthTest.test "the truth" do
          # noop
        end
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
    result = first_test.run(@config)

    assert_equal 1, result.assertions_count
    assert_predicate result, :failed?
  end

  def test_successful_run
    load_fixture("simple/simple_test.rb")

    first_test = @registry.test_cases.first
    assert_equal "the truth", first_test.name
    result = first_test.run(@config)

    assert_equal 1, result.assertions_count
    refute_predicate result, :failed?
  end

  def test_failing_run
    load_fixture("simple/simple_test.rb")

    first_test = @registry.test_cases[1]
    assert_equal "the lie", first_test.name
    result = first_test.run(@config)

    assert_equal 1, result.assertions_count
    assert_predicate result, :failed?
  end

  def test_skipped_run
    load_fixture("simple/skip_test.rb")

    first_test = @registry.test_cases[0]
    assert_equal "the skip", first_test.name
    result = first_test.run(@config)

    assert_equal 0, result.assertions_count
    assert_predicate result, :skipped?
  end

  def test_callbacks
    load_fixture("callbacks/callbacks_test.rb")

    first_test = @registry.test_cases.first
    assert_equal "callbacks", first_test.name
    result = first_test.run(@config)
    assert_predicate result, :success?

    assert_equal <<~ORDER.strip, TestedApp.order.join("\n")
      test_case_before_setup
      callbacks_test_before_setup
      test_case_setup_block
      callbacks_test_setup_block
      test_case_setup_method
      callbacks_test_setup_method
      test_case_after_setup
      callbacks_test_after_setup
      test_case_before_teardown
      callbacks_test_before_teardown
      callbacks_test_teardown_block
      test_case_teardown_block
      test_case_teardown_method
      callbacks_test_teardown_method
      test_case_after_teardown
      callbacks_test_after_teardown
    ORDER
  end
end
