# frozen_string_literal: true

module Megatest
  class Stubber < Module
    DEFAULT = ->(*) {}
    DEFAULT.ruby2_keywords if DEFAULT.respond_to?(:ruby2_keywords)

    class << self
      def for(object)
        for_class(class << object; self; end)
      end

      def for_class(klass)
        unless stubber = klass.included_modules.find { |m| Stubber === m }
          stubber = Stubber.new
          klass.prepend(stubber)
        end
        stubber
      end
    end

    def stub_method(method, proc)
      proc ||= DEFAULT

      if method_defined?(method, false) # Already stubbed that method
        old_method = instance_method(method)
        alias_method(method, method) # Silence redefinition warnings
        define_method(method, &proc)
        -> { define_method(method, old_method) }
      else
        define_method(method, &proc)
        -> { remove_method(method) }
      end
    end
  end

  module Stubs
    def stub(object, method, proc = nil)
      stubber = ::Megatest::Stubber.for(object)
      teardown = stubber.stub_method(method, proc)

      if block_given?
        begin
          yield
        ensure
          teardown.call
        end
      else
        @__m.on_teardown << teardown
      end
    end

    def stub_any_instance_of(klass, method, proc = nil)
      raise ArgumentError, "stub_any_instance_of expects a Module or Class" unless Module === klass

      stubber = ::Megatest::Stubber.for_class(klass)
      teardown = stubber.stub_method(method, proc)

      if block_given?
        begin
          yield
        ensure
          teardown.call
        end
      else
        @__m.on_teardown << teardown
      end
    end

    def stub_const(mod, constant, new_value, exists: true)
      if exists
        old_value = mod.const_get(constant, false)
        teardown = -> do
          mod.send(:remove_const, constant) if mod.const_defined?(constant, false)
          mod.const_set(constant, old_value)
        end
      else
        if mod.const_defined?(constant)
          raise NameError, "already defined constant #{constant} in #{mod.name || mod.inspect}"
        end

        teardown = -> do
          mod.send(:remove_const, constant) if mod.const_defined?(constant, false)
        end
      end

      apply = -> do
        mod.send(:remove_const, constant) if exists
        mod.const_set(constant, new_value)
      end

      if block_given?
        begin
          apply.call
          yield
        ensure
          teardown.call
        end
      else
        begin
          apply.call
        rescue
          teardown.call
          raise
        end
        @__m.on_teardown << teardown
      end
    end
  end
end
