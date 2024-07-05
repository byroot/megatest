# frozen_string_literal: true

module TestedApp
  class CrashTest < Megatest::Test
    10.times do |i|
      test "passes #{i}" do
        assert true
      end
    end

    test "crash" do
      Process.exit
    end
  end
end
