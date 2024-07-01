# frozen_string_literal: true

gem "redis-client", ">= 0.22"
require "redis-client"

module Megatest
  class RedisQueue < Queue
    attr_reader :size, :assertions_count, :runs_count, :failures_count, :errors_count, :skips_count, :total_time

    def initialize(build:, worker:, url:, ttl: 24 * 60 * 60)
      super()

      @redis = RedisClient.new(url: url)
      @ttl = ttl
      @load_timeout = 30 # TODO: configurable
      @worker_id = worker
      @build_id = build
      @success = true
      @failures = []
      @runs_count = @assertions_count = @failures_count = @errors_count = @skips_count = 0
      @total_time = 0.0
      @leader = nil
      @script_cache = {}
      @leader = nil
    end

    def leader?
      @leader
    end

    RESERVE = <<~'LUA'
      local queue_key = KEYS[1]
      local running_key = KEYS[2]
      local processed_key = KEYS[3]
      local worker_queue_key = KEYS[4]
      local owners_key = KEYS[5]

      local current_time = ARGV[1]

      local test = redis.call('rpop', queue_key)
      if test then
        redis.call('zadd', running_key, current_time, test)
        redis.call('lpush', worker_queue_key, test)
        redis.call('hset', owners_key, test, worker_queue_key)
        return test
      else
        return nil
      end
    LUA

    def reserve
      eval_script(
        RESERVE,
        keys: [
          key("queue"),
          key("running"),
          key("processed"),
          key("worker", @worker_id, "queue"),
          key("owners"),
        ],
        argv: [Megatest.now],
      )
    end

    def populate(test_cases)
      @test_cases = test_cases.to_h { |t| [t.id, t] }

      leader_key_set, = @redis.pipelined do |pipeline|
        pipeline.call("setnx", key("leader-status"), "setup")
        pipeline.call("expire", key("leader-status"), @ttl)
        pipeline.call("sadd", key("workers"), @worker_id)
        pipeline.call("expire", key("workers"), @ttl)
      end
      @leader = leader_key_set == 1

      if @leader
        @redis.multi do |transaction|
          transaction.call("lpush", key("queue"), test_cases.map(&:id)) unless test_cases.empty?
          transaction.call("expire", key("queue"), @ttl)
          transaction.call("set", key("size"), test_cases.size, ex: @ttl)
          transaction.call("set", key("leader-status"), "ready")
        end
      else
        (@load_timeout * 10).times do
          if @redis.call("get", key("leader-status")) == "ready"
            break
          else
            sleep 0.1
          end
        end
      end
    end

    def success?
      @success
    end

    def pop_test
      if test_id = reserve
        @test_cases.fetch(test_id)
      end
    end

    ACKNOWLEDGE = <<~'LUA'
      local queue_key = KEYS[1]
      local processed_key = KEYS[2]
      local owners_key = KEYS[3]

      local test = ARGV[1]

      redis.call('zrem', queue_key, test)
      redis.call('hdel', owners_key, test) -- # Doesn't matter if it was reclaimed by another workers
      return redis.call('sadd', processed_key, test)
    LUA

    def record_result(result)
      super

      load_script(ACKNOWLEDGE)
      _ack, = @redis.pipelined do |_pipeline|
        eval_script(
          ACKNOWLEDGE,
          keys: [key("running"), key("processed"), key("owners")],
          argv: [result.test_id],
        )
        @redis.call("hincrby", key("stats"), "assertions-count", result.assertions_count)
        @redis.call("hincrby", key("stats"), "runs-count", 1)
        @redis.call("hincrby", key("stats"), "total-time-us", (result.duration * 1_000_000).to_i)
        @redis.call("expire", key("stats"), @ttl)
      end

      result
    end

    private

    def eval_script(script, keys: [], argv: [])
      @redis.call("evalsha", load_script(script), keys.size, keys, argv)
    end

    def load_script(script)
      @scripts_cache ||= {}
      @scripts_cache[script] ||= @redis.call("script", "load", script)
    end

    def key(*args)
      ["build", @build_id, *args].join(":")
    end
  end
end
