# frozen_string_literal: true

module TestedApp
  class_eval <<~RUBY, "app.rb"
    module App
      class << self
        def foo
          bar
        end

        def bar
          baz
        end

        def baz
          oops
        end

        def oops
          1 + nil
        end
      end
    end
  RUBY

  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class ErrorTest < TestCase
    test "boom" do
      assert_equal 2, App.foo
    end

    def test_legacy_boom
      assert_equal 2, App.foo
    end

    test "throw" do
      assert_throws :test do
        1 + nil
      end
    end
  end

  class SetupCallbackTest < TestCase
    setup do
      1 + nil
    end

    test "ok" do
      assert true
    end
  end

  class BeforeSetupTest < TestCase
    def before_setup
      1 + nil
    end

    test "ok" do
      assert true
    end
  end

  class TeardownCallbackTest < TestCase
    teardown do
      1 + nil
    end

    test "ok" do
      assert true
    end
  end

  class BeforeTeardownTest < TestCase
    def before_teardown
      1 + true
    end

    test "ok" do
      assert true
    end
  end

  class DefTeardownTest < TestCase
    def teardown
      1 + true
    end

    test "ok" do
      assert true
    end
  end
end
