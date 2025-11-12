# frozen_string_literal: true

$VERBOSE = true
module RaiseWarnings
  def warn(message, *)
    return if message.include?("Ractor is experimental")

    super

    raise RuntimeError, message, caller(1)
  end
  ruby2_keywords :warn if respond_to?(:ruby2_keywords, true)
end
Warning.singleton_class.prepend(RaiseWarnings)

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "megatest"
require "megatest/cli"
require "megatest/redis_queue"
require "megatest/multi_process"

require "stringio"

class MegaTestCase < Megatest::Test
  DEFAULT_CONFIG = Megatest::Config.new({}).freeze
  FIXTURES_PATH = File.expand_path("../../fixtures", __FILE__)

  setup do
    @registry = Megatest::Registry.new
    @config = DEFAULT_CONFIG.dup
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

  def build_skip(test_case)
    build_result(test_case) do
      raise Megatest::Skip, "Nah..."
    end
  end

  def build_error(test_case)
    build_result(test_case) do
      backtrace = [
        File.join(Megatest::PWD, "app/my_app.rb:35:in `block in some_method'"),
        File.join(Megatest::PWD, "test/my_app_test.rb:42:in `block in <class:MyAppTest>'"),
        "",
        "",
        "#{__FILE__}:#{FAILURE_YIELD_LINE}",
      ]
      raise RuntimeError, "oops", backtrace
    end
  end

  def build_failure(test_case)
    build_result(test_case) do
      backtrace = [
        File.join(Megatest::PWD, "test/my_app_test.rb:42:in `block in <class:MyAppTest>'"),
        "",
        "",
        "#{__FILE__}:#{FAILURE_YIELD_LINE}",
      ]
      raise Megatest::Assertion, "2 + 2 != 5", backtrace
    end
  end

  FAILURE_YIELD_LINE = __LINE__ + 5 # runtime.record_failures do
  def build_result(test_case)
    result = Megatest::TestCaseResult.new(test_case)
    runtime = Megatest::Runtime.new(@config || Megatest::Config.new({}), test_case, result)
    result.record_time do
      runtime.record_failures do
        yield runtime
      end
    end
    result.instance_variable_set(:@duration, 0.42)
    result
  end

  def setup_redis
    db = @__m.config.job_index.to_i + 1
    redis_url = ENV.fetch("REDIS_URL", "redis://127.0.0.1")
    @config.queue_url = @redis_url = "#{redis_url}/#{db}"
    @redis = RedisClient.new(url: @redis_url)
    @redis.call("flushdb", "async")
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
      Megatest.singleton_class.alias_method(:now, :now)
      Megatest.define_singleton_method(:now) do
        original_method.bind(Megatest).call + diff
      end
      yield
    ensure
      Megatest.singleton_class.alias_method(:now, :now)
      Megatest.define_singleton_method(:now, original_method)
    end
  end
end
