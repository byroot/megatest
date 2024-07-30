# frozen_string_literal: true

gem "redis-client", ">= 0.22"
require "redis-client"
require "rbconfig"

# :stopdoc:

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
  # - "worker:<@worker_id>:running": Set, tests ids currently held by a worker.
  #
  # - "worker:<@worker_id>:failures": List, all the ids of failed tests processed by a worker.
  #     Used as the base for a new queue when retrying a job. May contain duplicates.
  #
  # - "results": List, inside are serialized TestCaseResult instances. Append only.
  #
  # - "requeues-count": Hash, keys are test ids, values are the number of time that particular test
  #    was retried. There is also the special "___total___" key.
  class RedisQueue < AbstractQueue
    class ExternalHeartbeatMonitor
      def initialize(queue)
        @queue = queue
      end
    end

    class << self
      def build(config)
        queue = new(config)
        if queue.retrying?
          queue = RetryQueue.build(config, queue)
        end
        queue
      end
    end

    attr_reader :summary

    def initialize(config, ttl: 24 * 60 * 60)
      super(config)

      @summary = Queue::Summary.new
      @redis = RedisClient.new(
        url: config.queue_url,
        # We retry quite aggressively in case the network
        # is spotty, we'd rather wait a bit than to crash
        # a worker.
        reconnect_attempts: [0, 0, 0.1, 0.5, 1, 3, 5],
      )
      @ttl = ttl
      @load_timeout = 30 # TODO: configurable
      @worker_id = config.worker_id
      @build_id = config.build_id
      @success = true
      @leader = nil
      @script_cache = {}
      @leader = nil
    end

    def retrying?
      @worker_id && !@redis.call("llen", key("worker", worker_id, "failures")).zero?
    end

    def failed_test_ids
      test_ids = @redis.call("lrange", key("worker", worker_id, "failures"), 0, -1)&.uniq
      test_ids.reverse!
      test_ids
    end

    def cleanup
      if @success
        if @worker_id
          @redis.call(
            "del",
            key("worker", worker_id, "running"),
            key("worker", worker_id, "failures"),
          )
        else
          @redis.call(
            "del",
            key("leader-status"),
            key("queue"),
            key("running"),
            key("processed"),
            key("owners"),
            key("results"),
            key("requeue-counts"),
          )
        end
      end
    rescue RedisClient::ConnectionError
      false # Cleanup is best effort
    end

    HEARTBEAT = <<~'LUA'
      local running_key = KEYS[1]
      local processed_key = KEYS[2]
      local owners_key = KEYS[3]
      local worker_running_key = KEYS[4]

      local worker_id = ARGV[1]
      local current_time = ARGV[2]

      local count = 0

      local tests = redis.call('smembers', worker_running_key)
      for index = 1, #tests do
        local test = tests[index]

        -- # already processed, we do not need to bump the timestamp
        if redis.call('sismember', processed_key, test) == 0 then
          -- # we're still the owner of the test, we can bump the timestamp
          local owner_id = redis.call('hget', owners_key, test)
          if owner_id == worker_id then
            redis.call('zadd', running_key, current_time, test)
            count = count + 1
          end
        end
      end

      return count
    LUA

    def heartbeat
      eval_script(
        HEARTBEAT,
        keys: [
          key("running"),
          key("processed"),
          key("owners"),
          key("worker", worker_id, "running"),
        ],
        argv: [
          worker_id,
          Megatest.now,
        ],
      )
      true
    rescue RedisClient::ConnectionError
      false # Heartbeat is best effort
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
      local owners_key = KEYS[4]
      local worker_running_key = KEYS[5]

      local worker_id = ARGV[1]
      local current_time = ARGV[2]
      local timeout = ARGV[3]

      -- # First we requeue all timed out tests
      local lost_tests = redis.call('zrangebyscore', running_key, 0, current_time - timeout)
      for _, test in ipairs(lost_tests) do
        if redis.call('sismember', processed_key, test) == 0 then
          local test = redis.call('rpush', queue_key, test)
        end
      end

      local test = redis.call('rpop', queue_key)
      if test then
        redis.call('zadd', running_key, current_time, test)
        redis.call('sadd', worker_running_key, test)
        redis.call('hset', owners_key, test, worker_id)
        return test
      end

      return nil
    LUA

    def reserve
      load_script(RESERVE)
      test_id, = eval_script(
        RESERVE,
        keys: [
          key("queue"),
          key("running"),
          key("processed"),
          key("owners"),
          key("worker", worker_id, "running"),
        ],
        argv: [
          worker_id,
          Megatest.now,
          @config.heartbeat_frequency * 2,
        ],
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
      local worker_running_key = KEYS[4]

      local test = ARGV[1]

      redis.call('zrem', running_key, test)
      redis.call('srem', worker_running_key, test)
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
          pipeline.call("rpush", key("results"), result.dump)
          pipeline.call("expire", key("results"), @ttl)
        end
      else
        load_script(ACKNOWLEDGE)
        @redis.pipelined do |pipeline|
          eval_script(
            ACKNOWLEDGE,
            keys: [
              key("running"),
              key("processed"),
              key("owners"),
              key("worker", worker_id, "running"),
            ],
            argv: [result.test_id],
            redis: pipeline,
          )
          if result.failed?
            pipeline.call("rpush", key("worker", worker_id, "failures"), result.test_id)
            pipeline.call("expire", key("worker", worker_id, "failures"), @ttl)
          elsif result.success?
            pipeline.call("lrem", key("worker", worker_id, "failures"), 0, result.test_id)
          end
          pipeline.call("rpush", key("results"), result.dump)
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
      local owners_key = KEYS[5]

      local worker_id = ARGV[1]
      local max_requeues = tonumber(ARGV[2])
      local global_max_requeues = tonumber(ARGV[3])
      local test = ARGV[4]
      local index = ARGV[5]

      if redis.call('hget', owners_key, test) == worker_id then
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

      index = @config.random.rand(0..@redis.call("llen", key("queue")))
      load_script(REQUEUE)
      eval_script(
        REQUEUE,
        keys: [
          key("processed"),
          key("requeues-count"),
          key("queue"),
          key("running"),
          key("owners"),
        ],
        argv: [
          worker_id,
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

    def worker_id
      @worker_id or raise Error, "RedisQueue not configued with a worker id"
    end

    class RetryQueue < Queue
      def initialize(config, global_queue)
        super(config)
        @global_queue = global_queue
      end

      def populate(test_cases)
        super
        failed_test_ids = @global_queue.failed_test_ids
        @size = failed_test_ids.size
        @queue = failed_test_ids.map { |id| @test_cases_index.fetch(id) }
      end

      def record_result(original_result)
        result = super
        if result.success?
          @global_queue.record_result(result)
        end
      end
    end
  end
end
