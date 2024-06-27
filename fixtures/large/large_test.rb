# frozen_string_literal: true

class LargeTest < Megatest::Test
  # 1k tests, 10ms each -> 10s
  1_000.times do |i|
    test "large #{i}" do
      sleep 0.01
      assert true
    end
  end
end
