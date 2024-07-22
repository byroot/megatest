# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class CallbacksTest < TestCase
    context "some context" do
      setup do
        # illegal
      end
    end
  end
end
