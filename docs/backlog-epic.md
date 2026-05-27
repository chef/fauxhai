# Epic: Fauxhai Quality & Maintainability Improvements

**Epic owner:** TBD
**Priority:** Medium
**Estimated scope:** 5 issues across testing, security, observability, and code quality

## Epic Description

During the Walk workflow exercises, several improvement opportunities were
identified but fell outside the scope of incremental changes. This epic
captures them as actionable backlog items with clear acceptance criteria,
code path references, and dependency notes.

### Current State (as of 2026-05-27)

- **Line coverage:** 83.61% (102/122 in spec-loaded files; 62.96% when all
  lib files are loaded including Runner/Fetcher)
- **Branch coverage:** 63.89% (23/36)
- **Untested modules:** `Fetcher`, `Runner`, `Runner::Default`, `Runner::Windows`
- **CI:** Tests, JSON validation, Mermaid diagrams, gitleaks, advisory coverage

---

## Issue 1: Add unit tests for Fetcher class

**Priority:** High
**Labels:** `enhancement`, `Expeditor: Skip Version Bump`
**Depends on:** None

### Problem

`Fetcher` ([lib/fauxhai/fetcher.rb](../lib/fauxhai/fetcher.rb)) has **zero
test coverage**. It handles SSH connections, caching, and ChefSpec integration
— all critical paths that currently rely entirely on integration testing.

### Code paths to cover

- `Fetcher#initialize` — SSH connection flow (lines 6–33)
- `Fetcher#cache` / `#cached?` / `#cache_file` — file-based caching (lines 36–52)
- `Fetcher#force_cache_miss?` — option parsing (lines 54–56)
- `Fetcher#host` / `#user` — input validation (lines 73–82)
- ChefSpec integration block (lines 23–30)

### Acceptance Criteria

- [ ] At least 8 unit tests in `spec/fetcher_spec.rb`
- [ ] SSH calls stubbed with `Net::SSH` mocks (no real network)
- [ ] File I/O stubbed for cache read/write
- [ ] Cover: successful fetch, cache hit, cache miss, force cache miss,
      missing host error, ChefSpec integration
- [ ] Line coverage for `fetcher.rb` ≥ 80%

---

## Issue 2: Raise branch coverage above 80%

**Priority:** Medium
**Labels:** `enhancement`, `Expeditor: Skip Version Bump`
**Depends on:** Issue 1 (Fetcher tests will contribute significantly)

### Problem

Branch coverage is currently **63.89%** (23/36). Key uncovered branches:

- `Mocker#data` — GitHub fetching path (HTTP success, HTTP error, network
  error) at [lib/fauxhai/mocker.rb lines 64–86](../lib/fauxhai/mocker.rb)
- `Mocker#parse_and_validate` — deprecated platform warning branch
  ([lib/fauxhai/mocker.rb line 112](../lib/fauxhai/mocker.rb))
- `Mocker#platform` — missing-platform fallback
  ([lib/fauxhai/mocker.rb line 118](../lib/fauxhai/mocker.rb))
- `VersionResolver#resolve` — all three return paths
  ([lib/fauxhai/version_resolver.rb lines 22–31](../lib/fauxhai/version_resolver.rb))

### Acceptance Criteria

- [ ] Branch coverage ≥ 80% (currently 63.89%)
- [ ] Tests added for GitHub fetch success path (mock HTTP 200)
- [ ] Tests added for deprecated platform warning (verify STDERR output)
- [ ] Tests added for missing-platform fallback to "chefspec"
- [ ] No regressions in existing tests

---

## Issue 3: Remove unused fixture private keys

**Priority:** Medium
**Labels:** `enhancement`, `bug`
**Depends on:** None

### Problem

`lib/fauxhai/keys/` contains both private keys (`id_rsa`, `id_dsa`) and
public keys (`id_rsa.pub`, `id_dsa.pub`). The code only reads the **public
keys** — see [lib/fauxhai/runner/default.rb lines 215–216](../lib/fauxhai/runner/default.rb).

The private keys are test fixtures that were justified and allowlisted in
[.gitleaks.toml](../.gitleaks.toml), but they serve no functional purpose and
create unnecessary security noise.

### Proposed Change

1. Remove `lib/fauxhai/keys/id_rsa` and `lib/fauxhai/keys/id_dsa`.
2. Remove the corresponding allowlist entries from `.gitleaks.toml`.
3. Verify `Runner` still works by checking only `.pub` files are referenced.
4. Update [SECURITY.md](../SECURITY.md) allowlist justification table.

### Acceptance Criteria

- [ ] Private key files removed from `lib/fauxhai/keys/`
- [ ] `.gitleaks.toml` allowlist simplified (remove private key paths)
- [ ] `SECURITY.md` updated
- [ ] `gitleaks detect` still clean
- [ ] `bundle exec rake` passes

---

## Issue 4: Add Fetcher instrumentation (parity with Mocker)

**Priority:** Low
**Labels:** `enhancement`
**Depends on:** Issue 1 (Fetcher tests needed to verify instrumentation)

### Problem

`Mocker#data` has structured logging ([lib/fauxhai/mocker.rb `log_data_load`](../lib/fauxhai/mocker.rb)),
but `Fetcher` has no instrumentation. SSH fetches are slow (seconds) and
cache behavior is invisible to users debugging test suite performance.

### Proposed Change

Add log hooks to `Fetcher#initialize` covering:

- `source` — `ssh`, `cache`, or `cache_miss`
- `host` — the target host (sanitized)
- `elapsed_ms` — total SSH + parse time
- `cached` — whether the result came from disk cache

Use the same `Fauxhai.logger` interface added in the observability exercise.

### Code paths to instrument

- [lib/fauxhai/fetcher.rb lines 8–19](../lib/fauxhai/fetcher.rb) — SSH vs cache branch
- [lib/fauxhai/fetcher.rb line 18](../lib/fauxhai/fetcher.rb) — cache write

### Acceptance Criteria

- [ ] Log output emitted for SSH fetch and cache hit paths
- [ ] Uses existing `Fauxhai.logger` (no-op when nil)
- [ ] No log output by default (backwards compatible)
- [ ] At least 2 tests verifying log output
- [ ] `FAUXHAI_LOG=1` demo documented

---

## Issue 5: Enforce minimum coverage in CI (non-advisory)

**Priority:** Low
**Labels:** `enhancement`
**Depends on:** Issue 2 (branch coverage must be ≥80% first)

### Problem

The `coverage-summary` CI job ([.github/workflows/ci.yml](../.github/workflows/ci.yml))
is advisory-only (`continue-on-error: true`). Once coverage is consistently
above 80%, the project would benefit from a **required** coverage gate to
prevent regressions.

### Proposed Change

1. Re-enable `minimum_coverage 80` in SimpleCov config
   ([spec/spec_helper.rb lines 3–6](../spec/spec_helper.rb)).
2. Add a separate required CI job (not `continue-on-error`) that fails the
   build if coverage drops below 80%.
3. Keep the advisory summary job for visibility.

### Acceptance Criteria

- [ ] SimpleCov `minimum_coverage 80` enabled
- [ ] CI job fails on coverage < 80% (blocking, not advisory)
- [ ] Advisory summary job still posts to Job Summary
- [ ] Line **and** branch coverage both ≥ 80% at time of merge
- [ ] CONTRIBUTING.md updated to reflect enforced (not just recommended)
      coverage requirement

---

## Dependency Graph

```
Issue 1 (Fetcher tests)
  ├──> Issue 2 (Branch coverage) ──> Issue 5 (Enforce coverage gate)
  └──> Issue 4 (Fetcher instrumentation)

Issue 3 (Remove private keys) — independent, can be done anytime
```

## Priority Order

1. **Issue 1** — Fetcher tests (unblocks Issues 2 and 4)
2. **Issue 3** — Remove private keys (independent, low risk)
3. **Issue 2** — Branch coverage (unblocks Issue 5)
4. **Issue 4** — Fetcher instrumentation
5. **Issue 5** — Enforce coverage gate (last, needs all coverage work done)
