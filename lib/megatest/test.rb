# frozen_string_literal: true

require "megatest/assertions"

module Megatest
  ##
  # Subclass Test to define a test suite
  #
  # See Megatest::Assertions and Megatest::DSL
  class Test
    # :stopdoc:
    # Megatest::Test is meant to be subclassed by users, as such it's written in an
    # adversarial way, we expose as little methods, instance variable and constants
    # as possible, and always reference our own constants with their fully qualified name.

    class << self
      if respond_to?(:const_source_location)
        def inherited(subclass)
          super
          const_source_location = if subclass.name
            ::Object.const_source_location(subclass.name)
          else
            location = caller_locations.find { |l| l.base_label != "inherited" && !l.path.start_with?("<internal:") }
            [location.path, location.lineno]
          end
          ::Megatest.registry.register_suite(subclass, const_source_location)
        end
      else
        def inherited(subclass)
          super
          location = caller_locations.find { |l| l.base_label != "inherited" && !l.path.start_with?("<internal:") }
          const_source_location = [location.path, location.lineno]
          ::Megatest.registry.register_suite(subclass, const_source_location)
        end
      end

      if Thread.respond_to?(:each_caller_location)
        def include(*modules)
          super

          location = Thread.each_caller_location do |l|
            break l if l.base_label != "include" && !l.path.start_with?("<internal:")
          end
          include_location = [location.path, location.lineno]

          modules.each do |mod|
            if mod.is_a?(::Megatest::DSL) || mod.instance_methods.any? { |m| m.start_with?("test_") }
              ::Megatest.registry.shared_suite(mod).included_by(self, include_location)
            end
          end
        end
      else
        using Compat::StartWith unless Symbol.method_defined?(:start_with?)

        def include(*modules)
          super

          location = caller_locations.find do |l|
            l if l.base_label != "include"
          end
          include_location = [location.path, location.lineno]

          modules.each do |mod|
            if mod.is_a?(::Megatest::DSL) || mod.instance_methods.any? { |m| m.start_with?("test_") }
              ::Megatest.registry.shared_suite(mod).included_by(self, include_location)
            end
          end
        end
      end
    end

    def initialize(runtime)
      @__m = runtime
    end

    def before_setup
    end

    # For Minitest compatibility
    def name
      @__m.test_case.name
    end

    def setup
    end

    def after_setup
    end

    def before_teardown
    end

    def teardown
    end

    def after_teardown
    end

    # :startdoc:
    extend DSL
    include Assertions

    # Returns the current Megatest::State::TestCase instance
    # Can be used for self introspection
    def __test__
      @__m.test_case
    end
  end
end
