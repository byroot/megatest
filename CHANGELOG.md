## [Unreleased]

- Allow multiple `setup`, `around` and `teardown` blocks in the same test suite.

## [0.5.0] - 2025-01-17

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
