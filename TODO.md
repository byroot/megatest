### Wants

- Make verbose reporter work with multi-processing.

- Test leak bisect
  - See ci-queue bisect.

- List slow tests
  - Not just X slowest test, but up to X tests that are significantly slower than average.
  - Exclude them with `:slow` tag.

- `-j` for forkless environments (Windows / JRuby / TruffleRuby)

- `minitest/mocks`
  - I'm not very fond of those, but could be worth offering it as a side gem or something, for easier transition.

### Maybe

- RSpec style pending?
