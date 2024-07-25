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

    def test(name, tags = nil, &block)
      ::Megatest.registry.suite(self).register_test_case(-name, block, tags)
    end

    def tag(**kwargs)
      ::Megatest.registry.suite(self).add_tags(kwargs)
    end

    def context(name, tags = nil, &block)
      ::Megatest.registry.suite(self).with_context(name, tags, &block)
    end

    def method_added(name)
      super
      if name.start_with?("test_")
        ::Megatest.registry.suite(self).register_test_case(name, instance_method(name), nil)
      end
    end

    def setup(&block)
      ::Megatest.registry.suite(self).on_setup(block)
    end

    def around(&block)
      ::Megatest.registry.suite(self).on_around(block)
    end

    def teardown(&block)
      ::Megatest.registry.suite(self).on_teardown(block)
    end
  end
end
