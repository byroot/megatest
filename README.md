# Megatest

Megatest is a test-unit like framework with a focus on usability, and designed with continuous integration in mind.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add megatest

## Usage

### Writing Tests

Test suites are Ruby classes that inherit from `Megatest::Test`.

Test cases are be defined with the `test` macro, or for compatibility with existing test suites,
by defining a method starting with `test_`.

All the classic `test-unit` and `minitest` assertion methods are available:

```ruby
# test/some_test.rb

class SomeTest < MyApp::Test
  setup do
    @user = User.new("George")
  end

  test "the truth" do
    assert_equal true, Some.truth
  end

  def test_it_works
    assert_predicate 2, :even?
  end
end
```

By convention, all the `test_helper.rb` files are automatically loaded,
which allows to centralize dependencies and define some helpers.

```ruby
# test/test_helper.rb

require "some_dependency"

module MyApp
  class Test < Megatest::Test

    def some_helper(arg)
    end
  end
end
```

It also allow to define test inside `context` blocks, to make it easier to group
related tests together and have them share a common name prefix.

```ruby
class SomeTest < MyApp::Test
  context "when on earth" do
    test "1 is odd" do
      App.location = "earth"
      assert_predicate 1, :odd?
    end

    test "2 is even" do
      App.location = "earth"
      assert_predicate 2, :even?
    end
  end
end
```

Note however that context blocks aren't test suites, they don't have their own setup or teardown
blocks, nor their own namespaces.

### Command Line

Contrary to many alternatives, `megatest` provide a convenient CLI interface to easily run specific tests.

Run all tests in a directory:

```bash
$ megatest # Run all tests in `test/`
$ megatest test/integration
```

Runs tests using 8 processes:

```bash
$ megatest -j 8
```

Run a test at the specific line:

```bash
$ megatest test/some_test.rb:42 test/other_test.rb:24
```

Run all tests matching a pattern:

```bash
$ megatest test/some_test.rb:/matching
```

For more detailed usage, run `megatest --help`.

### CI Parallelization

Megatest offer multiple feature to allow running test suites in parallel across
many CI jobs.

#### Sharding

The simplest way is sharding. Each worker will run its share of the test cases.

Many CI systems provide a way to run the same command on multiple nodes,
and will generally expose environment variables to help split the workload.

```yaml
- label: "Run Unit Tests"
  run: megatest --workers-count $CI_NODE_INDEX --worker-id $CI_NODE_TOTAL
  parallel: 8
```

Note that Megatest makes no effort at balancing the shards as it has no
information about how long each individual test case is expected to take.
However it does shard test cases individually, so it avoids the most common issue which is
very large test suites containing lots of slow test cases being sharded as one unit.

If you are using CircleCI, Buildkite or HerokuCI, the workers count and worker id
will be automatically inferred from the environment.

### Redis Distribution

A more efficient way to parallelize tests on CI is to use a Redis server to act as a queue.

This allow to efficiently and dynamically ensure a near perfect test case balance across all
the workers. And if for some reason one of the worker is lost or crashes, no test is lost,
which for builds with hundreds of parallel jobs, is essential for stability.

```yaml
- label: "Run Unit Tests"
  run: megatest --queue redis://redis-ci.example.com --build-id $CI_BUILD_ID --worker-id $CI_JOB_ID
  parallel: 128
  soft_fail: true # Doesn't matter if they fail or crash, only the "Results" job status matters

- label: "Unit Test Results"
  run: megatest report --queue redis://redis-ci.example.com --build-id $CI_BUILD_ID
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/byroot/megatest.
