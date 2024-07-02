# frozen_string_literal: true

require "test_helper"

module Megatest
  class SelectorTest < MegaTestCase
    def test_directory_path
      selector = Selector.parse(["fixtures/simple"])
      assert_equal [fixture("simple/")], selector.paths

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
      selector = Selector.parse(["fixtures/simple/simple_test.rb"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths

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
      selector = Selector.parse(["fixtures/simple/simple_test.rb:12"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_file_path_line_and_index
      selector = Selector.parse(["fixtures/large/large_test.rb:12~777", "fixtures/large/large_test.rb:12~888"])
      assert_equal [fixture("large/large_test.rb")], selector.paths

      load_fixture("large/large_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        LargeTest#large 777
        LargeTest#large 888
      CLASSES
    end

    def test_name
      selector = Selector.parse(["fixtures/simple/simple_test.rb:the truth"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_full_name
      selector = Selector.parse(["fixtures/simple/simple_test.rb:TestedApp::TruthTest#the truth"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).sort.join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_name_match
      selector = Selector.parse(["fixtures/simple/simple_test.rb:/the [tl]"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths

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
