# frozen_string_literal: true

module TestedApp
  singleton_class.attr_accessor :config
  self.config = :default

  class LeakyTest < Megatest::Test
    test "leak cause" do
      TestedApp.config = :leak
      assert true
    end

    100.times do |i|
      test "test something #{i}" do
        assert true
      end
    end

    test "leak sensitive" do
      assert_equal :default, TestedApp.config
    end
  end
end
