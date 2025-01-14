# frozen_string_literal: true

module Megatest
  class SelectorTest < MegaTestCase
    def test_parse_empty_selector
      selector = Selector.parse([])
      assert_equal ["#{File.expand_path("test")}/"], selector.main_paths
    end

    def test_directory_path
      selector = Selector.parse(["fixtures/simple"])
      expected = [
        "fixtures/simple/assert_equal_test.rb",
        "fixtures/simple/error_test.rb",
        "fixtures/simple/simple_test.rb",
        "fixtures/simple/skip_test.rb",
      ]
      assert_equal expected, relative(selector.paths(random: nil))

      load_fixture("simple/simple_test.rb")
      load_fixture("simple/skip_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::SkipTest#the skip
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the truth
        TestedApp::TruthTest#the unexpected
        TestedApp::TruthTest#the void
      CLASSES
    end

    def test_negative_path_loading
      selector = Selector.parse(["fixtures/simple", "!", "fixtures/simple/error_test.rb"])
      expected = [
        "fixtures/simple/assert_equal_test.rb",
        "fixtures/simple/simple_test.rb",
        "fixtures/simple/skip_test.rb",
      ]
      assert_equal expected, relative(selector.paths(random: nil))

      selector = Selector.parse(["fixtures", "!", "fixtures/simple", "fixtures/simple/error_test.rb"])
      expected = [
        "fixtures/callbacks/callbacks_test.rb",
        "fixtures/compat/compat_test.rb",
        "fixtures/context/callbacks_test.rb",
        "fixtures/context/context_test.rb",
        "fixtures/crash/crash_test.rb",
        "fixtures/errors/isolated_test.rb",
        "fixtures/generated_test.rb",
        "fixtures/inheritance/inheritance_test.rb",
        "fixtures/large/large_test.rb",
        "fixtures/leak/leaky_test.rb",
        "fixtures/simple/error_test.rb",
        "fixtures/tags/tagged_test.rb",
      ]
      assert_equal expected, relative(selector.paths(random: nil))
    end

    def test_directory_path_shuffling
      selector = Selector.parse(["fixtures", "!", "fixtures/simple", "fixtures/simple/error_test.rb"])
      expected = [
        "fixtures/simple/error_test.rb",
        "fixtures/leak/leaky_test.rb",
        "fixtures/callbacks/callbacks_test.rb",
        "fixtures/large/large_test.rb",
        "fixtures/errors/isolated_test.rb",
        "fixtures/context/callbacks_test.rb",
        "fixtures/compat/compat_test.rb",
        "fixtures/tags/tagged_test.rb",
        "fixtures/crash/crash_test.rb",
        "fixtures/inheritance/inheritance_test.rb",
        "fixtures/context/context_test.rb",
        "fixtures/generated_test.rb",
      ]
      assert_equal expected, relative(selector.paths(random: Random.new(42)))
    end

    def test_file_path_no_partials
      selector = Selector.parse(["fixtures/simple/simple_test.rb"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: nil)

      load_fixture("simple/simple_test.rb")
      load_fixture("simple/skip_test.rb") # Loaded as side effect

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::SkipTest#the skip
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the truth
        TestedApp::TruthTest#the unexpected
        TestedApp::TruthTest#the void
      CLASSES
    end

    def test_file_path_with_partials
      selector = Selector.parse(["fixtures/simple/simple_test.rb", "fixtures/simple/error_test.rb:42"])
      assert_equal ["fixtures/simple/error_test.rb", "fixtures/simple/simple_test.rb"], relative(selector.paths(random: nil))

      load_fixture("simple/simple_test.rb")
      load_fixture("simple/error_test.rb")
      load_fixture("simple/skip_test.rb") # Loaded as side effect

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the truth
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the unexpected
        TestedApp::TruthTest#the void
        TestedApp::ErrorTest#throw
      CLASSES
    end

    def test_file_path_and_line
      selector = Selector.parse(["fixtures/simple/simple_test.rb:12"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: nil)

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the truth
      CLASSES

      selector = Selector.parse(["fixtures/simple/simple_test.rb:11"])
      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_negative_file_path_and_line
      selector = Selector.parse(["fixtures/simple/simple_test.rb", "!", "fixtures/simple/simple_test.rb:12"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: nil)
      assert_equal [fixture("simple/simple_test.rb")], selector.main_paths

      load_fixture("simple/simple_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the unexpected
        TestedApp::TruthTest#the void
      CLASSES
    end

    def test_file_path_line_and_index
      selector = Selector.parse(["fixtures/large/large_test.rb:12~777", "fixtures/large/large_test.rb:12~888"])
      assert_equal [fixture("large/large_test.rb")], selector.paths(random: nil)

      load_fixture("large/large_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::LargeTest#large 777
        TestedApp::LargeTest#large 888
      CLASSES
    end

    def test_name
      selector = Selector.parse(["fixtures/simple/simple_test.rb:#the truth"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: nil)

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_full_name
      selector = Selector.parse(["fixtures/simple/simple_test.rb:#TestedApp::TruthTest#the truth"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: nil)

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_name_match
      selector = Selector.parse(["fixtures/simple/simple_test.rb:/the [tl]"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: nil)

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the truth
      CLASSES
    end

    def test_tags
      selector = Selector.parse(["fixtures/simple/simple_test.rb:@focus"])
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: nil)

      load_fixture("simple/simple_test.rb")
      load_fixture("inheritance/inheritance_test.rb")

      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the unexpected
      CLASSES

      selector = Selector.parse([":@focus"])
      selected_test_cases = selector.select(@registry, random: nil)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the lie
        TestedApp::TruthTest#the unexpected
      CLASSES
    end

    def test_partial_selection_sorted
      selector = Selector.parse(
        [
          "fixtures/simple/simple_test.rb:#TestedApp::TruthTest#the truth",
          "fixtures/simple/simple_test.rb:#TestedApp::TruthTest#the void",
          "fixtures/simple/simple_test.rb:#TestedApp::TruthTest#the unexpected",
        ],
      )
      assert_equal [fixture("simple/simple_test.rb")], selector.paths(random: Random.new)

      load_fixture("simple/simple_test.rb")

      selected_test_cases = selector.select(@registry, random: Random.new)
      assert_equal <<~CLASSES.strip, selected_test_cases.map(&:id).join("\n")
        TestedApp::TruthTest#the truth
        TestedApp::TruthTest#the void
        TestedApp::TruthTest#the unexpected
      CLASSES
    end

    private

    def random
      Random.new(0)
    end

    def relative(paths)
      case paths
      when String
        Megatest.relative_path(paths)
      when Array
        paths.map { |p| Megatest.relative_path(p) }
      else
        raise TypeError, "expected array or string, got: #{paths.class}"
      end
    end
  end
end
