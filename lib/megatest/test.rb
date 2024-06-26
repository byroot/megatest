# frozen_string_literal: true

require "megatest/assertions"

# Megatest::Test is meant to be subclassed by users, as such it's written in an
# adversarial way, we expose as little methods, instance variable and constants
# as possible, and always reference our own constants with their fully qualified name.
module Megatest
  class Test
    class << self
      def inherited(subclass)
        super
        ::Megatest.registry.add_test_suite(subclass)
      end

      def test(name, &block)
        @__mega.register_test_case(self, -name, block)
      end
    end

    include Assertions

    def initialize(mega_state)
      @__mega = mega_state
    end
  end
end
