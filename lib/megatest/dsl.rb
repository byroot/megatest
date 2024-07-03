# frozen_string_literal: true

module Megatest
  module DSL
    class << self
      def extended(mod)
        super
        if mod.is_a?(Class)
          unless mod == ::Megatest::Test
            raise ArgumentError, "Megatest::DSL should only be extended in modules"
          end
        else
          ::Megatest.registry.shared_suite(mod)
        end
      end
    end

    using Compat::StartWith unless Symbol.method_defined?(:start_with?)

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
end
