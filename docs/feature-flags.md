# Feature Flags

This document describes all feature flags (environment variables and
configuration toggles) in Fauxhai, their lifecycle, and validation status.

---

## `FAUXHAI_LOG` — Structured logging

| Attribute        | Value                                       |
|------------------|---------------------------------------------|
| **Type**         | Environment variable                        |
| **Default**      | OFF (unset)                                 |
| **Introduced**   | Exercise 8 – Observability (2026-05)        |
| **Status**       | Active                                      |
| **Removal plan** | None – permanent opt-in diagnostic flag     |

### Purpose

Enables structured log output from `Mocker#data` to STDERR via
`Fauxhai.logger`. Useful for diagnosing slow test suites, verifying
cache behaviour, and understanding which platform files are loaded.

### Lifecycle

1. **Creation:** Added in the observability exercise. Auto-configures a
   `Logger` instance on `Fauxhai.logger` when the env var is set.
2. **Default state:** OFF. When unset, `Fauxhai.logger` is `nil` and all
   `log_data_load` calls short-circuit immediately.
3. **How to enable:**
   ```bash
   FAUXHAI_LOG=1 bundle exec rspec
   ```
   Or programmatically:
   ```ruby
   Fauxhai.logger = Logger.new($stderr, progname: "fauxhai")
   ```
4. **How to disable:**
   - Unset the environment variable (default)
   - Or set `Fauxhai.logger = nil` at runtime
5. **When to remove:** This flag is intended to remain permanently. It has
   zero runtime cost when OFF (nil-guard short-circuit) and provides
   valuable diagnostics when ON.

### Implementation

**Entry point:** [`lib/fauxhai.rb` lines 28–31](../lib/fauxhai.rb)

```ruby
if ENV["FAUXHAI_LOG"]
  self.logger = Logger.new($stderr, progname: "fauxhai")
  self.logger.level = ENV.fetch("FAUXHAI_LOG_LEVEL", "DEBUG")
end
```

**Consumer:** [`lib/fauxhai/mocker.rb` `log_data_load`](../lib/fauxhai/mocker.rb)

```ruby
def log_data_load(source, elapsed_ms, data)
  return unless Fauxhai.logger
  # ...
end
```

### Related env var: `FAUXHAI_LOG_LEVEL`

Controls the Logger severity when `FAUXHAI_LOG` is set.
Defaults to `DEBUG`. Accepts any standard Ruby Logger level string
(`DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`).

### Validation

Both ON and OFF states are validated in CI via the test matrix
(see `.github/workflows/ci.yml`). The matrix expands `fauxhai_log: ['', '1']`
across all Ruby versions, giving 6 jobs total (3 Ruby × 2 flag states).

**Local validation output:**

#### OFF (default) — 0 log lines emitted

```
$ bundle exec rspec 2>&1 | tail -5
318 examples, 0 failures, 36 pending
Line Coverage: 83.61% (102 / 122)
Branch Coverage: 63.89% (23 / 36)

$ bundle exec rspec 2>&1 | grep -c "platform_load:"
0
```

#### ON — 2 log lines emitted (1 per unique data load in logging tests)

```
$ FAUXHAI_LOG=1 bundle exec rspec 2>&1 | tail -5
318 examples, 0 failures, 36 pending
Line Coverage: 85.25% (104 / 122)
Branch Coverage: 63.89% (23 / 36)

$ FAUXHAI_LOG=1 bundle exec rspec 2>&1 | grep -c "platform_load:"
2
```

All 318 examples pass in both states. Coverage slightly increases with
the flag ON because the auto-enable code path in `fauxhai.rb` is exercised.

---

## `github_fetching` — GitHub fallback toggle

| Attribute        | Value                                       |
|------------------|---------------------------------------------|
| **Type**         | Constructor option (`Fauxhai::Mocker.new`)  |
| **Default**      | `true`                                      |
| **Introduced**   | Original codebase                           |
| **Status**       | Active                                      |
| **Removal plan** | None – core behaviour control               |

### Purpose

Controls whether `Mocker#data` falls back to fetching platform JSON from
GitHub when the file is not found locally. Setting to `false` makes Fauxhai
fully offline, raising `InvalidPlatform` for any missing platform.

### Lifecycle

1. **Creation:** Part of the original Fauxhai design.
2. **Default state:** ON (`true`). The constructor merges
   `{ github_fetching: true }` as the default.
3. **How to enable:**
   ```ruby
   Fauxhai::Mocker.new(platform: "ubuntu", version: "24.04")
   # github_fetching: true is the default
   ```
4. **How to disable:**
   ```ruby
   Fauxhai::Mocker.new(platform: "ubuntu", version: "24.04", github_fetching: false)
   ```
5. **When to remove:** This is a permanent core flag. Removing it would be
   a breaking change.

### Implementation

**Entry point:** [`lib/fauxhai/mocker.rb` lines 44–46](../lib/fauxhai/mocker.rb)

```ruby
def initialize(options = {}, &override_attributes)
  @options = { github_fetching: true }.merge(options)
```

**Branch:** [`lib/fauxhai/mocker.rb` lines 68–75](../lib/fauxhai/mocker.rb)

```ruby
result = if File.exist?(filepath)
  # ...local read...
elsif @options[:github_fetching]
  # ...fetch from GitHub...
else
  raise Fauxhai::Exception::InvalidPlatform
end
```

### Validation

The test suite exercises both states:

- **OFF:** Most tests use `github_fetching: false` to avoid network calls.
  See [`spec/mocker_spec.rb` line 7](../spec/mocker_spec.rb).
- **ON + failure path:** The "GitHub fetching fails" context mocks
  `Net::HTTP.get_response` to return a 404. See
  [`spec/mocker_spec.rb` lines 22–36](../spec/mocker_spec.rb).

No additional CI matrix dimension is needed because both states are covered
by explicit test cases within the same suite run.

---

## Adding a new flag

When introducing a new feature flag, follow this template:

1. **Document** it in this file with the table format above.
2. **Default to OFF** unless the flag controls existing behaviour.
3. **Add tests** for both ON and OFF states in `spec/`.
4. **CI matrix:** If the flag is an env var that changes load-time behaviour,
   add it to the CI matrix in `.github/workflows/ci.yml`.
5. **Set a removal date** if the flag is temporary (e.g., migration aid).
   Permanent diagnostic flags should be marked as such.
