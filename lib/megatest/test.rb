# frozen_string_literal: true

require "megatest/assertions"

# Megatest::Test is meant to be subclassed by users, as such it's written in an
# adversarial way, we expose as little methods, instance variable and constants
# as possible, and always reference our own constants with their fully qualified name.
module Megatest
  class Test
    class << self
      unless Symbol.method_defined?(:start_with?)
        using Module.new {
          refine Symbol do
            def start_with?(*args)
              to_s.start_with?(*args)
            end
          end
        }
      end

      if respond_to?(:const_source_location)
        def inherited(subclass)
          super
          const_source_location = if subclass.name
            ::Object.const_source_location(subclass.name)
          else
            location = caller_locations.find { |l| l.base_label != "inherited" }
            [location.path, location.lineno]
          end
          ::Megatest.registry.register_suite(subclass, const_source_location)
        end
      else
        def inherited(subclass)
          super
          location = caller_locations.find { |l| l.base_label != "inherited" }
          const_source_location = [location.path, location.lineno]
          ::Megatest.registry.register_suite(subclass, const_source_location)
        end
      end

      def test(name, &block)
        ::Megatest.registry.suite(self).register_test_case(-name, block)
      end

      def method_added(name)
        super
        if name.start_with?("test_")
          ::Megatest.registry.suite(self).register_test_case(name, instance_method(name))
        end
      end
    end

    include Assertions

    def initialize(mega_state)
      @__mega = mega_state
    end
  end
end
