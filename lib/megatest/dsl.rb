# frozen_string_literal: true

module Megatest
  # All the methods necessary to define test cases.
  # Can be used directly to define test cases in modules
  # for later inclusion.
  #
  # Example:
  #
  #  module SomeSharedTests
  #    extend Megatest::DSL
  #
  #    setup do
  #    end
  #
  #    test "the truth" do
  #      assert_equal 4, 2 + 2
  #    end
  #  end
  #
  #  class SomeTest < Megatest::Test
  #    include SomeSharedTests
  #  end
  #
  #  class SomeOtherTest < Megatest::Test
  #    include SomeSharedTests
  #  end
  module DSL
    # :stopdoc:
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

    def method_added(name)
      super
      if name.start_with?("test_")
        ::Megatest.registry.suite(self).register_test_case(name, instance_method(name), nil)
      end
    end

    # :startdoc:

    ##
    # Define a test case.
    #
    # Example:
    #
    #  test "the truth" do
    #    assert_equal 4, 2 + 2
    #  end
    #
    # For ease of transition from other test frameworks, any method
    # that starts by +test_+ is also considered a test:
    #
    # Example:
    #
    #  def test_the_truth
    #    assert_equal 4, 2 + 2
    #  end
    def test(name, tags = nil, &block)
      ::Megatest.registry.suite(self).register_test_case(-name, block, tags)
    end

    # Applies tags to all the test case of this suite
    #
    # Example:
    #
    #  class SomeTest < Megatest::Test
    #    tag focus: true
    #
    #    test "something" do
    #      assert_equal true, __test__.tag(:focus)
    #    end
    #
    #    test "something else", focus: false do
    #      assert_equal false, __test__.tag(:focus)
    #    end
    #  end
    def tag(**kwargs)
      ::Megatest.registry.suite(self).add_tags(kwargs)
    end

    ##
    # Creates a context block, for logically grouping test cases.
    # The context string will be prepended to all the test cases
    # defined within the block.
    #
    # Example:
    #
    #  context "maths" do
    #    test "the truth" do
    #      assert_equal 4, 2 + 2
    #    end
    #
    #    test "oddity" do
    #      refute_predicate 4, odd?
    #    end
    #  end
    #
    # Setup and teardown callbacks are not allowed withing a context blocks,
    # as it too easily lead to "write only" tests. It's only meant to help
    # group test cases together.
    #
    # If you need a common setup procedure, just define a helper method, and explictly call it.
    #
    # Example:
    #
    #  context "admin user" do
    #    def setup_admin_user
    #      # ...
    #    end
    #
    #    test "#admin?" do
    #      user = setup_admin_user
    #      assert_predicate user, :admin?
    #    end
    #
    #    test "#can?(:delete_post)" do
    #      user = setup_admin_user
    #      assert user.can?(:delete_post)
    #    end
    #  end
    def context(name, tags = nil, &block)
      ::Megatest.registry.suite(self).with_context(name, tags, &block)
    end

    # Registers a block to be invoked before every test cases.
    def setup(&block)
      ::Megatest.registry.suite(self).on_setup(block)
    end

    # Registers a block to be invoked around every test cases.
    # The block will recieve a Proc as first argument and MUST
    # call it.
    #
    # Example:
    #
    #  around do |block|
    #    do_something do
    #      block.call
    #    end
    #  end
    def around(&block)
      ::Megatest.registry.suite(self).on_around(block)
    end

    # Registers a block to be invoked after every test cases,
    # regardless of whether it passed or failed.
    def teardown(&block)
      ::Megatest.registry.suite(self).on_teardown(block)
    end
  end
end
