# Megatest

Megatest is a test-unit like framework with a focus on usability, and designed with continuous integration in mind.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add megatest

## Usage

### Writing Tests

Test suites are Ruby classes that inherit from `Megatest::Test`.

Test cases can be defined with the `test` macro, or by defining a method starting with `test_`.

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

  context "when using old style" do
    def test_it_works
      assert_predicate 2, :even?
    end
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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/byroot/megatest.
