# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class_eval <<~'RUBY', "test_helper.rb"
    class BaseCase < TestCase
      class << self
        def test_something_truthy(something)
          test "#{something.inspect} is truthy" do
            assert something
          end
        end
      end
    end
  RUBY

  class GeneratedTest < BaseCase
    test_something_truthy true
    test_something_truthy 42
    test_something_truthy "true"
    test_something_truthy nil
  end
end
