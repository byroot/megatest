# frozen_string_literal: true

# Megatest::Test is meant to be subclassed by users, as such it's written in an
# adversarial way, we expose as little methods, instance variable and constants
# as possible, and always reference our own constants with their fully qualified name.
module Megatest
  class Test
    class << self
      def inherited(subclass)
        super
        ::Megatest.registry.add_test_case(subclass)
      end

      def test(name, &block)
        location = caller_locations(1, 1).first
        @__mega.register_test(self, -name, block, location&.path, location&.lineno)
      end
    end

    def initialize(mega_state)
      @__mega = mega_state
    end
  end
end
