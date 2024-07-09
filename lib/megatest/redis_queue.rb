# frozen_string_literal: true

gem "redis-client", ">= 0.22"
require "redis-client"

module Megatest
  # Data structures
  #
  # Note: All keys are prefixed by `build:<@build_id>:`
  #
  # - "leader-status": String, either `setup` or `ready`
  #
  # - "queue": List, contains the test ids that haven't yet been poped.
  #
  # - "running": SortedSet, members are the test ids currently being processed.
  #    Scores are the lease expiration timestamp. If the score is lower than
  #    current time, the test was lost and should be re-assigned.
  #
  # - "processed": Set, members are the ids of test that were fully processed.
  #
  # - "owners": Hash, contains a mapping of currently being processed tests and the worker they are assigned to.
  #    Keys are test ids, values are "worker:<@worker_id>:queue".
  #
  # - "worker:<@worker_id>:queue": List, config all the tests ids of tests poped by a worker.
  #     Tests are immediately inserted on pop.
  #
  # - "results": List, inside are serialized TestCaseResult instances. Append only.
  #
  # - "requeues-count": Hash, keys are test ids, values are the number of time that particular test
  #    was retried. There is also the special "___total___" key.
  class RedisQueue < AbstractQueue
    attr_reader :summary

    def initialize(config, ttl: 24 * 60 * 60)
      super(config)

      @summary = Queue::Summary.new
      @redis = RedisClient.new(url: config.queue_url)
      @ttl = ttl
      @load_timeout = 30 # TODO: configurable
      @worker_id = config.worker_id
      @build_id = config.build_id
      @success = true
      @failures = []
      @runs_count = @assertions_count = @failures_count = @errors_count = @skips_count = 0
      @total_time = 0.0
      @leader = nil
      @script_cache = {}
      @leader = nil
    end

    def distributed?
      true
    end

    def populated?
      @redis.call("get", key("leader-status")) == "ready"
    end

    def leader?
      @leader
    end

    def remaining_size
      @redis.multi do |transaction|
        transaction.call("llen", key("queue"))
        transaction.call("zcard", key("running"))
      end.inject(:+)
    end

    def empty?
      remaining_size.zero?
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
      load_script(RESERVE)
      test_id, = eval_script(
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
      test_id
    end

    def populate(test_cases)
      super

      leader_key_set, = @redis.pipelined do |pipeline|
        pipeline.call("setnx", key("leader-status"), "setup")
        pipeline.call("expire", key("leader-status"), @ttl)
      end
      @leader = leader_key_set == 1

      if @leader
        @redis.multi do |transaction|
          transaction.call("lpush", key("queue"), test_cases.map(&:id)) unless test_cases.empty?
          transaction.call("expire", key("queue"), @ttl)
          transaction.call("set", key("leader-status"), "ready")
        end
      else
        (@load_timeout * 10).times do
          if populated?
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
        test_cases_index.fetch(test_id)
      end
    end

    ACKNOWLEDGE = <<~'LUA'
      local running_key = KEYS[1]
      local processed_key = KEYS[2]
      local owners_key = KEYS[3]

      local test = ARGV[1]

      redis.call('zrem', running_key, test)
      redis.call('hdel', owners_key, test) -- # Doesn't matter if it was reclaimed by another workers
      return redis.call('sadd', processed_key, test)
    LUA

    def record_result(original_result)
      result = original_result
      if result.failed?
        if attempt_to_retry(result)
          result = result.retry
        else
          @success = false
        end
      end
      @summary.record_result(result)

      if result.retried?
        @redis.pipelined do |pipeline|
          pipeline.call("lpush", key("results"), result.dump)
          pipeline.call("expire", key("results"), @ttl)
        end
      else
        load_script(ACKNOWLEDGE)
        _ack, = @redis.pipelined do |pipeline|
          eval_script(
            ACKNOWLEDGE,
            keys: [key("running"), key("processed"), key("owners")],
            argv: [result.test_id],
            redis: pipeline,
          )
          pipeline.call("lpush", key("results"), result.dump)
          pipeline.call("expire", key("results"), @ttl)
        end
      end

      result
    end

    def global_summary
      if payloads = @redis.call("lrange", key("results"), 0, -1)
        Queue::Summary.new(payloads.map { |p| TestCaseResult.load(p) })
      else
        Queue::Summary.new
      end
    end

    private

    REQUEUE = <<~'LUA'
      local processed_key = KEYS[1]
      local requeues_count_key = KEYS[2]
      local queue_key = KEYS[3]
      local running_key = KEYS[4]
      local worker_queue_key = KEYS[5]
      local owners_key = KEYS[6]

      local max_requeues = tonumber(ARGV[1])
      local global_max_requeues = tonumber(ARGV[2])
      local test = ARGV[3]
      local index = ARGV[4]

      if redis.call('hget', owners_key, test) == worker_queue_key then
         redis.call('hdel', owners_key, test)
      end

      if redis.call('sismember', processed_key, test) == 1 then
        return false
      end

      local global_requeues = tonumber(redis.call('hget', requeues_count_key, '___total___'))
      if global_requeues and global_requeues >= tonumber(global_max_requeues) then
        return false
      end

      local requeues = tonumber(redis.call('hget', requeues_count_key, test))
      if requeues and requeues >= max_requeues then
        return false
      end

      redis.call('hincrby', requeues_count_key, '___total___', 1)
      redis.call('hincrby', requeues_count_key, test, 1)

      local pivot = redis.call('lrange', queue_key, -1 - index, 0 - index)[1]
      if pivot then
        redis.call('linsert', queue_key, 'BEFORE', pivot, test)
      else
        redis.call('lpush', queue_key, test)
      end

      redis.call('zrem', running_key, test)

      return true
    LUA

    def attempt_to_retry(result)
      return false unless @config.retries?

      index = Megatest.seed.rand(0..@redis.call("llen", key("queue")))
      load_script(REQUEUE)
      eval_script(
        REQUEUE,
        keys: [
          key("processed"),
          key("requeues-count"),
          key("queue"),
          key("running"),
          key("worker", @worker_id, "queue"),
          key("owners"),
        ],
        argv: [
          @config.max_retries,
          @config.total_max_retries(@size),
          result.test_id,
          index,
        ],
      ) == 1
    end

    def eval_script(script, keys: [], argv: [], redis: @redis)
      script_id = load_script(script)
      result, = pipelined(redis) do |pipeline|
        pipeline.call("evalsha", script_id, keys.size, keys, argv)
        keys.each do |key|
          pipeline.call("expire", key, @ttl)
        end
      end
      result
    end

    def pipelined(redis, &block)
      if redis.respond_to?(:pipelined)
        redis.pipelined(&block)
      else
        yield redis
      end
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
