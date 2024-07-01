# frozen_string_literal: true

require "test_helper"

module Megatest
  class SelectorTest < MegaTestCase
    def test_directory_path
      selectors = Selector.parse(["fixtures/simple"])
      assert_equal 1, selectors.size
      selector = selectors.first

      assert_equal fixture("simple/"), selector.path

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the truth
        TestedApp::TruthTest#the unexpected
      CLASSES
    end

    def test_file_path
      selectors = Selector.parse(["fixtures/simple/simple_test.rb"])
      assert_equal 1, selectors.size
      selector = selectors.first

      assert_equal fixture("simple/simple_test.rb"), selector.path

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the truth
        TestedApp::TruthTest#the unexpected
      CLASSES
    end

    def test_file_path_and_line
      selectors = Selector.parse(["fixtures/simple/simple_test.rb:12"])
      assert_equal 1, selectors.size
      selector = selectors.first

      assert_equal fixture("simple/simple_test.rb"), selector.path

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_name
      selectors = Selector.parse(["fixtures/simple/simple_test.rb:the truth"])
      assert_equal 1, selectors.size
      selector = selectors.first

      assert_equal fixture("simple/simple_test.rb"), selector.path

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_full_name
      selectors = Selector.parse(["fixtures/simple/simple_test.rb:TestedApp::TruthTest#the truth"])
      assert_equal 1, selectors.size
      selector = selectors.first

      assert_equal fixture("simple/simple_test.rb"), selector.path

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_name_match
      selectors = Selector.parse(["fixtures/simple/simple_test.rb:/the [tl]"])
      assert_equal 1, selectors.size
      selector = selectors.first

      assert_equal fixture("simple/simple_test.rb"), selector.path

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the truth
      CLASSES
    end
  end
end
