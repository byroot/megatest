# frozen_string_literal: true

module Megatest
  class FailureTest < MegaTestCase
    def test_shows_did_you_mean
      # GitHub Actions ruby 2.6 is weird
      skip if ENV["CI"] && RUBY_VERSION < "2.7"
      begin
        [].empty
      rescue => exception
      end
      failure = Failure.new(exception)
      assert_includes failure.message, "Did you mean?"
    end
  end
end
