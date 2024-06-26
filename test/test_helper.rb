# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "megatest"

require "minitest/autorun"

class MegaTestCase < Minitest::Test
  def teardown
    Object.send(:remove_const, :TestedApp) if defined?(::TestedApp)
  end

  private

  def load_fixture(path)
    Kernel.load(fixture(path))
  end

  def fixture(path)
    File.join(File.expand_path("../fixtures", __FILE__), path)
  end
end
