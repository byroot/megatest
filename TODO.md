### Wants

- RSpec style pending?

- Distributed queue (ci-queue style).
  - Other?

- Test leak bisect
  - `test_order.log` first?

- Improve assertion errors
  - Better pretty print
  - Better multi-line

- `-j` for forkless environments (Windows / JRuby / TruffleRuby)

- `minitest/mocks`
  - I'm not very fond of those, but could be worth offering it as a side gem or something, for completeness sake.

### Maybes

- `minitest/spec` syntax?
  - Used by Arel test suite
  - Not really convinced about the usefulness.

- Depend on Zeitwerk?
  - If we enforced that all test files are loadable by Zeitwerk, then running a test by name becomes trivial.
  - Allow to unload/reload tests
  - Downside is that it makes minitest compat harder.

- Add multi-threading?
  - Not convinced of the usefulness, except maybe for alternative rubies.
  - Also breaks most mocking libaries
