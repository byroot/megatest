# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "megatest"
require "megatest/cli"

require "minitest/autorun"

class MegaTestCase < Minitest::Test
  FIXTURES_PATH = File.expand_path("../../fixtures", __FILE__)

  def before_setup
    @registry = Megatest.registry = Megatest::Registry.new
  end

  def after_teardown
    Object.send(:remove_const, :TestedApp) if defined?(::TestedApp)
    $LOADED_FEATURES.reject! { |f| f.start_with?(FIXTURES_PATH) }
  end

  private

  def load_fixture(path)
    Kernel.require(fixture(path))
  end

  def fixture(path)
    File.join(FIXTURES_PATH, path)
  end
end
