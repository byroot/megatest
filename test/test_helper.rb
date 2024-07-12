# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "megatest"
require "megatest/cli"
require "megatest/redis_queue"
require "megatest/multi_process"

require "stringio"

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

  def build_success(test_case)
    build_result(test_case) do |runtime|
      4.times { runtime.assert { nil } }
    end
  end

  def build_error(test_case)
    build_result(test_case) do
      raise "oops"
    end
  end

  def build_failure(test_case)
    build_result(test_case) do
      raise Megatest::Assertion, "2 + 2 != 5"
    end
  end

  def build_result(test_case)
    result = Megatest::TestCaseResult.new(test_case)
    runtime = Megatest::Runtime.new(@config || Megatest::Config.new({}), result)
    result.record_time do
      runtime.record_failures do
        yield runtime
      end
    end
    result
  end

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

  def stub_time(diff)
    original_method = Megatest.singleton_class.instance_method(:now)
    begin
      Megatest.define_singleton_method(:now) do
        original_method.bind(Megatest).call + diff
      end
      yield
    ensure
      Megatest.define_singleton_method(:now, original_method)
    end
  end
end
