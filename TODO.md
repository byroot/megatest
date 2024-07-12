### Wants

- around callbacks?

- RSpec style pending?

- context blocks
  - As a simple prefix for test name
  - No scoped setup/teardown, need to explicitly reject that.

- Distributed queue (ci-queue style).
  - Other?

- Test leak bisect
  - `test_order.log` first?

- Implement missing assertions

### Maybes

- Depend on Zeitwerk?
  - If we enforced that all test files are loadable by Zeitwerk, then running a test by name becomes trivial.
  - Allow to unload/reload tests
  - Downside is that it makes minitest compat harder.

- Add multi-threading?
  - Not convinced of the usefulness, except maybe for alternative rubies.
  - Also breaks most mocking libaries
