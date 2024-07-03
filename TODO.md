### Wants

- setup and teardown support

- A proper "setup worker" hook.
  - Right now global setup like fixtures insertion is done in the first test setup, rather than being its own step.
  - Maybe: a per suite global setup? Executed before running the first test of the suite?

- Minitest compatibility layer:
  - `def setup`, etc

- Polish multi-processing.

- Distributed queue (ci-queue style).
  - Requeues & Retries

- Test leak bisect
  - `test_order.log` first?

- Automatically add `-Itest` for compat with Minitest.
  - Automatically require `test/test_helper.rb` ?

- Fail tests if nothing was asserted.

- Fail or warn if some tests are purely abstract?
  - e.g. defined in a class that doesn't end with `Test`, and isn't inherited.

### Maybes

- Depend on Zeitwerk?
  - If we enforced that all test files are loadable by Zeitwerk, then running a test by name becomes trivial.
  - Allow to unload/reload tests
  - Downside is that it makes minitest compat harder.

- Add multi-threading?
  - Not convinced of the usefulness, except maybe for alternative rubies.
  - Also breaks most mocking libaries
