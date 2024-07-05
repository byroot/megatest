# frozen_string_literal: true

module TestedApp
  class LargeTest < Megatest::Test
    test "before" do
      assert true
    end

    # 1k tests, 10ms each -> 10s
    ENV.fetch("TEST_COUNT", 1_000).to_i.times do |i|
      test "large #{i}" do
        sleep 0.01
        assert i.odd?
      end
    end

    test "after" do
      assert true
    end
  end
end
