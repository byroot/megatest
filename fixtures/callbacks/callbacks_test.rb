# frozen_string_literal: true

module TestedApp
  class << self
    attr_accessor :order
  end
  @order = []

  class TestCase < Megatest::Test
    setup do
      TestedApp.order << :test_case_setup_block
    end

    def before_setup
      super
      TestedApp.order << :test_case_before_setup
    end

    def setup
      super
      TestedApp.order << :test_case_setup_method
    end

    def after_setup
      super
      TestedApp.order << :test_case_after_setup
    end

    teardown do
      TestedApp.order << :test_case_teardown_block
    end

    def before_teardown
      super
      TestedApp.order << :test_case_before_teardown
    end

    def teardown
      super
      TestedApp.order << :test_case_teardown_method
    end

    def after_teardown
      super
      TestedApp.order << :test_case_after_teardown
    end
  end

  class CallbacksTest < TestCase
    setup do
      TestedApp.order << :callbacks_test_setup_block
    end

    def before_setup
      super
      TestedApp.order << :callbacks_test_before_setup
    end

    def setup
      super
      TestedApp.order << :callbacks_test_setup_method
    end

    def after_setup
      super
      TestedApp.order << :callbacks_test_after_setup
    end

    teardown do
      TestedApp.order << :callbacks_test_teardown_block
    end

    def before_teardown
      super
      TestedApp.order << :callbacks_test_before_teardown
    end

    def teardown
      super
      TestedApp.order << :callbacks_test_teardown_method
    end

    def after_teardown
      super
      TestedApp.order << :callbacks_test_after_teardown
    end

    test "success" do
      assert true
    end

    test "skipped" do
      skip
    end

    test "error" do
      raise NotImplementedError
    end
  end
end
