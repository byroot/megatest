# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "megatest"
require "megatest/cli"
require "megatest/redis_queue"
require "megatest/multi_process"

class MegaTestCase < Megatest::Test
  FIXTURES_PATH = File.expand_path("../../fixtures", __FILE__)

  setup do
    @registry = Megatest::Registry.new
  end

  teardown do
    Object.send(:remove_const, :TestedApp) if defined?(::TestedApp)
    $LOADED_FEATURES.reject! { |f| f.start_with?(FIXTURES_PATH) }
  end

  private

  def setup_redis
    @redis_url = ENV.fetch("REDIS_URL", "redis://127.0.0.1/7")
    @redis = RedisClient.new(url: @redis_url)
    @redis.call("flushdb")
  end

  def load_fixture(path)
    Megatest.with_registry(@registry) do
      Kernel.require(fixture(path))
    end
  end

  def fixture(path)
    File.join(FIXTURES_PATH, path)
  end
end
