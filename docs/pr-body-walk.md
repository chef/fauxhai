## Description

Comprehensive Walk workflow improvements across the fauxhai codebase:
coverage reporting, refactoring, contract tests, performance, dependency
hygiene, security scanning, observability, and CI enhancements.

## Changes

- **Coverage:** Enable SimpleCov with branch coverage; add PR template
- **Refactor:** Extract `VersionResolver` from `Mocker#version` (4 files)
- **Docs:** Walk workflow in CONTRIBUTING.md; onboarding prompt for Copilot Chat
- **Contract tests:** Golden schema for platform JSON files (289 examples)
- **Performance:** Class-level raw string cache in `Mocker#data` (31% faster)
- **Dependency:** Upgrade `rspec-its` 1.3.1 → 2.0.0
- **Security:** Add gitleaks secret scanning to CI with allowlisted fixtures
- **Observability:** Structured logging for `Mocker#data` (source/timing/deprecated)
- **CI:** Advisory coverage summary job posting to GitHub Actions Job Summary
- **PR template:** Add Review Focus, Verification Steps, and Rollback sections

## Review Focus

1. **lib/fauxhai/mocker.rb — `cached_read` and `log_data_load`** — Verify the
   raw-string cache returns independent hashes (callers mutate data in
   override blocks). Confirm logging is no-op when `Fauxhai.logger` is nil.

2. **lib/fauxhai/version_resolver.rb — `highest_version` heuristic** — This
   was extracted as-is from `Mocker#version`. Verify the regex split handles
   mixed alphanumeric versions like `2012R2` and `4.8-RELEASE` correctly by
   checking the spec edge cases.

3. **spec/fixtures/platform_schema.json — contract completeness** — Confirm
   the required key lists match what ChefSpec consumers actually depend on.
   If a key is missing, contract tests will fail for all 63 non-deprecated
   platforms.

4. **.github/workflows/ci.yml — `coverage-summary` job** — Verify
   `continue-on-error: true` is set so this job never blocks merges. Check
   the `$GITHUB_STEP_SUMMARY` heredoc renders valid Markdown.

5. **.gitleaks.toml — allowlist paths** — Confirm the regex patterns match
   only the intended test fixture files and don't accidentally suppress real
   secret findings in other directories.

## Verification Steps

```bash
# 1. Set up
bundle install

# 2. Run the full test suite (318 examples expected)
bundle exec rspec
# Expected: 318 examples, 0 failures, 36 pending

# 3. Check coverage (should be >80%)
open coverage/index.html
# Expected: Line Coverage 83.61%, Branch Coverage 63.89%

# 4. Verify the refactored VersionResolver independently
bundle exec rspec spec/version_resolver_spec.rb
# Expected: 10 examples, 0 failures

# 5. Verify contract tests
bundle exec rspec spec/platform_contract_spec.rb
# Expected: 289 examples, 0 failures, 36 pending (deprecated)

# 6. Run gitleaks locally
brew install gitleaks  # if not installed
gitleaks detect --config .gitleaks.toml --verbose --no-git
# Expected: "no leaks found"

# 7. Test instrumentation logging
FAUXHAI_LOG=1 ruby -I lib -e '
  require "fauxhai"
  Fauxhai::Mocker.new(platform: "ubuntu", version: "24.04", github_fetching: false).data
'
# Expected: INFO log line with platform=ubuntu source=disk elapsed_ms=...

# 8. Validate JSON (part of default rake)
bundle exec rake validate:json
# Expected: "JSON files validated"
```

**Expected result:** All tests pass, no new warnings, coverage ≥80%.

## Testing

- [x] All existing tests pass (`bundle exec rspec`)
- [x] New tests added for changed code
- [x] Coverage verified locally

### Coverage Results

```
Line Coverage:   83.61% (102 / 122)
Branch Coverage: 63.89% (23 / 36)
```

**Total line coverage: 83.61%**

> Target: >80% line coverage. See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

## Rollback Plan

This PR contains 9 independent commits. To revert the entire PR:

```bash
git revert --no-commit <merge-commit-sha>
git commit --signoff -m "Revert: Walk workflow improvements"
```

To revert individual changes:

| Commit | Revert |
|--------|--------|
| SimpleCov | Remove `simplecov` from Gemfile, revert `spec_helper.rb` |
| VersionResolver | Delete `lib/fauxhai/version_resolver.rb`, restore inline `Mocker#version` |
| rspec-its upgrade | Change gemspec to `"~> 1.2"`, run `bundle update rspec-its` |
| Gitleaks | Delete `.gitleaks.toml`, remove `secret-scan` job from CI |
| Mocker cache | Remove `@json_cache`, `cached_read`; restore direct `File.read` in `#data` |
| Logging | Remove `Fauxhai.logger`, `log_data_load`; restore inline `#data` |
| Coverage CI job | Remove `coverage-summary` job from `.github/workflows/ci.yml` |

## DCO

- [x] All commits are signed off (`git commit --signoff`)
