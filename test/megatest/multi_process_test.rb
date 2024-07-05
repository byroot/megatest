# frozen_string_literal: true

require "test_helper"

module Megatest
  class MultiProcessTest < MegaTestCase
    def test_client_queue
      child, parent = MultiProcess.socketpair
      child << :first << :second
      assert_equal :first, parent.read
      assert_equal :second, parent.read

      parent << :first << :second
      assert_equal :first, child.read
      assert_equal :second, child.read

      parent.close
      assert_nil child.read

      child << :void
    end
  end
end
