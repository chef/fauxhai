# Subsystem Backlog: Data-Loading Pipeline

**Subsystem scope:** `Mocker` → `VersionResolver` → `Retrier` → `Fetcher`
**Files:** `lib/fauxhai/mocker.rb`, `lib/fauxhai/fetcher.rb`,
`lib/fauxhai/retrier.rb`, `lib/fauxhai/version_resolver.rb`, `lib/fauxhai.rb`

**Current state (2026-05-27):**
- 330 examples, 0 failures, 36 pending
- Line coverage: 86.71% (124/143)
- Branch coverage: 67.39% (31/46)
- Fetcher: 0% test coverage
- Runner: 0% test coverage

---

## Issue 1: Remove unused `require "digest/sha1"` in Fetcher ★ Good First Task

**Priority:** Low · **Difficulty:** Trivial · **Delegation:** Agent-ready

### Problem

[lib/fauxhai/fetcher.rb line 3](../lib/fauxhai/fetcher.rb) imports
`digest/sha1` but the code actually uses `Digest::SHA2` (line 51). The
unused import is misleading and triggers security-review noise (SHA1 is
considered weak).

### Code path

```ruby
# lib/fauxhai/fetcher.rb:3
require "digest/sha1"   # ← unused

# lib/fauxhai/fetcher.rb:51
Digest::SHA2.hexdigest("#{user}@#{host}")  # ← actual usage
```

### Acceptance Criteria

- [ ] `require "digest/sha1"` replaced with `require "digest/sha2"`
- [ ] `Digest::SHA2.hexdigest` still works correctly
- [ ] No test regressions (`bundle exec rspec`)
- [ ] RuboCop strict passes (`bundle exec rubocop -c .rubocop-strict.yml`)

### Delegation: Simulated Patch Plan

This is the simplest possible change — a single-line fix — ideal for
delegation to an agent or a first-time contributor.

**Step-by-step execution plan:**

1. **Read** the file to confirm current state:
   ```
   read_file lib/fauxhai/fetcher.rb lines 1-5
   ```
   Expected: line 3 is `require "digest/sha1"`

2. **Edit** line 3:
   ```ruby
   # Before:
   require "digest/sha1"
   # After:
   require "digest/sha2"
   ```

3. **Validate** — run both checks:
   ```bash
   bundle exec rspec                              # 330 examples, 0 failures
   bundle exec rubocop -c .rubocop-strict.yml     # no offenses
   ```

4. **Commit** with sign-off:
   ```bash
   git add lib/fauxhai/fetcher.rb
   git commit --signoff -m "Fix unused digest/sha1 import in Fetcher

   Fetcher uses Digest::SHA2 for cache keys but imported digest/sha1.
   Replace with the correct import to eliminate misleading dependency."
   ```

**Risk:** None. `Digest::SHA2` auto-loads when `digest/sha2` is required.
The existing `Digest::SHA2.hexdigest` call is unchanged.

**Rollback:** Revert the single line back to `require "digest/sha1"`.

---

## Issue 2: Add unit tests for Fetcher class ★ Good First Task

**Priority:** High · **Difficulty:** Medium · **Delegation:** Agent-ready

### Problem

`Fetcher` ([lib/fauxhai/fetcher.rb](../lib/fauxhai/fetcher.rb)) has **zero
test coverage**. It handles SSH connections, JSON parsing, file-based
caching, and ChefSpec integration — all critical paths that rely solely on
integration testing today. This is the single largest coverage gap in the
project: loading all lib files drops line coverage from 86.71% to ~63%.

### Code paths to cover

| Method | Lines | What it does |
|--------|-------|-------------|
| `initialize` | 8–34 | SSH vs cache branch, ChefSpec integration |
| `cache` | 36–38 | Read and parse cached JSON |
| `cached?` | 40–42 | Check cache file existence |
| `cache_key` | 44–46 | SHA2 hex digest of `user@host` |
| `cache_file` | 48–50 | Expand path to tmp dir |
| `force_cache_miss?` | 52–54 | Option parsing with memoization |
| `host` | 72–78 | Required option extraction |
| `user` | 80–82 | ENV fallback chain |

### Acceptance Criteria

- [ ] `spec/fetcher_spec.rb` created with at least 10 tests
- [ ] `Net::SSH` calls stubbed — no real network I/O
- [ ] File I/O stubbed for cache read/write paths
- [ ] Tests cover: successful fetch, cache hit, cache miss, force cache
      miss, missing host error, ChefSpec integration, `to_hash`, `to_s`
- [ ] Line coverage for `fetcher.rb` ≥ 80%
- [ ] No test regressions in full suite

### Delegation notes

Agent can scaffold the spec file using the existing
[spec/mocker_spec.rb](../spec/mocker_spec.rb) as a pattern reference. All
external dependencies (Net::SSH, File) must be stubbed.

---

## Issue 3: Thread-safety for Mocker class-level cache

**Priority:** Medium · **Difficulty:** Medium

### Problem

`Mocker.json_cache` is a plain `Hash` shared across all instances via a
class instance variable ([lib/fauxhai/mocker.rb line 18](../lib/fauxhai/mocker.rb)).
In threaded test runners (e.g., `parallel_tests`, concurrent RSpec), multiple
threads can read/write `@json_cache` simultaneously, risking data corruption
or lost writes.

### Code path

```ruby
# lib/fauxhai/mocker.rb:18
@json_cache = {}

# lib/fauxhai/mocker.rb:134 (cached_read)
raw = self.class.json_cache[filepath] ||= File.read(filepath)
```

The `||=` operation on a Hash is not atomic. Two threads checking the same
key simultaneously could both trigger `File.read`, wasting I/O and —
depending on Ruby implementation — potentially corrupting the Hash.

### Proposed Solution

Use `Monitor` or `Mutex` to synchronize cache access:

```ruby
@json_cache = {}
@cache_mutex = Mutex.new

def self.cached_read_raw(filepath)
  @cache_mutex.synchronize do
    @json_cache[filepath] ||= File.read(filepath)
  end
end
```

### Acceptance Criteria

- [ ] Cache access synchronized with Mutex or Monitor
- [ ] Thread-safety test added (spawn 4 threads loading the same platform)
- [ ] No measurable performance regression for single-threaded case
      (benchmark before/after with `Benchmark.ips`)
- [ ] `clear_cache!` also acquires the lock
- [ ] Documentation note added to class-level comment

---

## Issue 4: Retrier should support `on_retry` callback

**Priority:** Low · **Difficulty:** Low · **Delegation:** Agent-ready

### Problem

`Retrier` currently logs retry attempts via `Fauxhai.logger` hardcoded at
[lib/fauxhai/retrier.rb line 71](../lib/fauxhai/retrier.rb). Downstream
consumers who need custom retry telemetry (metrics, alerting) have no
hook — they can only parse log output.

### Code path

```ruby
# lib/fauxhai/retrier.rb:71
Fauxhai.logger&.warn { "retrier: attempt=#{attempts} error=#{e.class} delay=#{delay}s" }
```

### Proposed Solution

Add an optional `on_retry` callback parameter:

```ruby
DEFAULT_OPTIONS = {
  # ...existing keys...
  on_retry: nil     # Proc or nil
}

# In call():
if @config[:on_retry]
  @config[:on_retry].call(attempts, e, delay)
end
Fauxhai.logger&.warn { ... }
```

### Acceptance Criteria

- [ ] `on_retry` option added to `DEFAULT_OPTIONS` (default: `nil`)
- [ ] Callback receives `(attempt_number, exception, delay_seconds)`
- [ ] Existing logger behavior unchanged when `on_retry` is nil
- [ ] 3 tests: callback invoked, callback receives correct args, nil
      callback does not error
- [ ] `docs/resilience.md` updated with callback example

---

## Issue 5: Fetcher cache expiry / TTL

**Priority:** Medium · **Difficulty:** Medium

### Problem

`Fetcher` caches SSH-fetched Ohai data indefinitely to `tmp/<sha2>` files
([lib/fauxhai/fetcher.rb line 27](../lib/fauxhai/fetcher.rb)). Stale cache
files are never invalidated unless the user passes `force_cache_miss: true`.
In long-lived CI environments, cached data can drift from the real host.

### Code paths

```ruby
# lib/fauxhai/fetcher.rb:11
if !force_cache_miss? && cached?
  @data = cache                # Always trusts cache if file exists

# lib/fauxhai/fetcher.rb:40-42
def cached?
  File.exist?(cache_file)      # No age check
end
```

### Proposed Solution

Add a `cache_ttl` option (default: `nil` = no expiry, preserving current
behavior). When set, check `File.mtime` against `Time.now`:

```ruby
def cached?
  return false unless File.exist?(cache_file)
  return true unless @cache_ttl

  (Time.now - File.mtime(cache_file)) < @cache_ttl
end
```

### Acceptance Criteria

- [ ] `cache_ttl` option added (default: `nil`)
- [ ] Env var `FAUXHAI_CACHE_TTL` for seconds-based override
- [ ] Cache file age checked when TTL is set
- [ ] Expired cache triggers re-fetch via SSH
- [ ] 4 tests: nil TTL (no expiry), fresh cache (within TTL), expired
      cache (triggers re-fetch), env var override
- [ ] `docs/resilience.md` updated with TTL section
- [ ] Backward compatible — no behavior change without explicit TTL

---

## Priority Matrix

| # | Issue | Priority | Difficulty | Agent-ready? |
|---|-------|----------|------------|--------------|
| 1 | Fix unused digest/sha1 import | Low | Trivial | ★ Yes |
| 2 | Add Fetcher unit tests | High | Medium | ★ Yes |
| 3 | Thread-safety for Mocker cache | Medium | Medium | No |
| 4 | Retrier `on_retry` callback | Low | Low | ★ Yes |
| 5 | Fetcher cache TTL / expiry | Medium | Medium | No |

## Dependency Graph

```
Issue 1 (fix import) — independent, do first
Issue 2 (Fetcher tests) — independent, unblocks confidence for Issues 3 & 5
Issue 3 (thread-safety) — benefits from Issue 2 tests existing
Issue 4 (on_retry callback) — independent
Issue 5 (cache TTL) — benefits from Issue 2 tests existing
```

## Recommended Execution Order

1. **Issue 1** — trivial fix, immediate merge
2. **Issue 2** — Fetcher tests (largest coverage gap)
3. **Issue 4** — on_retry callback (small, independent)
4. **Issue 3** — thread-safety (needs careful benchmarking)
5. **Issue 5** — cache TTL (needs Issue 2 tests for validation)
