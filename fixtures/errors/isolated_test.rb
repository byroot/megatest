# frozen_string_literal: true

module TestedApp
  class TestCase < Megatest::Test
    # base test class where to put helpers and such
  end

  class IsolatedTest < TestCase
    INITIAL_PID = Integer(ENV["_MEGATEST_PID"] ||= Process.pid.to_s)

    tag isolated: true

    test "runs in subprocess" do
      refute_equal INITIAL_PID, Process.pid
    end

    test "override", isolated: false do
      assert_equal INITIAL_PID, Process.pid
    end

    test "crash" do
      Process.exit!(1)
    end
  end
end
