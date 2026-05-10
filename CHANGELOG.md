## [Unreleased]

- Allow to forward `MEGATEST_PWD` for monorepos.

## [0.10.0] - 2026-05-09

- Improve reporting when running in Buildkite.

## [0.9.1] - 2026-05-09

- `Config#seed=` noop if argument is `nil`.

## [0.9.0] - 2026-05-09

- Implement `capture_subprocess_io`.
- Change setup/teadown callbacks order to be more consistent with `ActiveSupport::TestCase`.
- Don't consider skips as failure when running with `--fail-fast`.
- `assert_equal` now use `==` instead of `!=` to compare objects
- `assert_operator` now calls `assert_predicate` if there no third argument (mimick Minitest).
- Support `assert_difference("expr" => 1)` like `ActiveSupport::TestCase`

## [0.8.0] - 2026-05-08

- Improve rendering of retried failures so they're actionable.

## [0.7.0] - 2026-03-21

- Automatic parallelization using cgroups or nprocs.
- Don't output escape codes when output is not a TTY.
- Don't retry skipped tests.
- Improve help message.

## [0.6.0] - 2026-01-17

- Allow defining setup and teardown with method names.
- Allow multiple `setup`, `around` and `teardown` blocks in the same test suite.

## [0.5.0] - 2026-01-17

- Adds `megatest/autorun`
- Adds `assert_nothing_raised`.
- Adds `assert_difference`.
- Adds `assert_changes`.
- Adds `assert_not_*` aliases.
- Adds `match:` argument to `assert_raises`.

## [0.4.0] - 2025-11-12

- Allow configuring the test glob via `config.test_globs`.

## [0.3.0] - 2025-06-20

- Added missing MIT license.
- Add bisection support.
- List slowest tests on success.

## [0.2.0] - 2024-08-26

- Make the VerboseReporter work with concurrent executors.
- Fix isolated tests on forkless platforms when the config contains procs.
- Add a `job_teardown callback` to to stand off for at_exit.
- Add `stub`, `stub_const` and `stub_any_instance_of`.
- Add support for `-I` in the CLI.

## [0.1.1] - 2024-08-20

- Fix `$PATH` prefix detection.

## [0.1.0] - 2024-08-20

- Initial release
