### Wants

- setup and teardown support

- A proper "setup worker" hook.
  - Right now global setup like fixtures insertion is done in the first test setup, rather than being its own step.
  - Maybe: a per suite global setup? Executed before running the first test of the suite?

- Run test(s) by `"id" "id"`
    - Need to think about an ID format that is both readable and shell safe.
    - Ideally allows for lazy loading: `path.rb:Klass#the name`
    - Another possibility is to follow RSpec here.
        - Test unique identifier is the `<path>:<line>` combo
        - If multiple tests defined on the same line, it's `<path>:[<line>:<index>]`
        - It's a bit ugly, but pragmatically speaking it works well.
        - Might be challenging with included modules, need to update their source line to the `include` call.

- Test sharing (include module)

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

### Maybes

- Depend on Zeitwerk?
    - If we enforced that all test files are loadable by Zeitwerk, then running a test by name becomes trivial.
    - Allow to unload/reload tests
    - Downside is that it makes minitest compat harder.

- Add multi-threading?
    - Not convinced of the usefulness, except maybe for alternative rubies.
