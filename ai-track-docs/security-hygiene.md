# Security Hygiene Report

**Repository:** chef/fauxhai  
**Date:** 2026-05-27  
**Branch:** learn/run/sanjain-ex7-security-hygiene  
**Author:** sanjain

---

## Scope

Manual security audit of all files under `lib/` plus `bin/`, `spec/`, `scripts/`,
`Gemfile`, and `fauxhai-chef.gemspec`. Focused on OWASP-relevant patterns in Ruby
(injection, path traversal, insecure deserialization, dead imports, string mutability).

## Findings & Fixes Applied

### Fix 1: Remove unused `require "digest/sha1"` (Medium)

| Attribute | Detail |
|-----------|--------|
| **File** | `lib/fauxhai/fetcher.rb` line 1 |
| **Issue** | `require "digest/sha1"` was imported but never used. The code actually uses `Digest::SHA2` (from autoload). The dead import was misleading and pulled in a weaker digest algorithm unnecessarily. |
| **Risk** | Low direct risk, but confusing to auditors and increases attack surface perception. |
| **Fix** | Removed the unused `require` line. Replaced with `# frozen_string_literal: true` pragma. |
| **Side effects** | None. `Digest::SHA2` is loaded elsewhere. |

### Fix 2: Input validation on platform/version identifiers (Medium-High)

| Attribute | Detail |
|-----------|--------|
| **Files** | `lib/fauxhai/mocker.rb` |
| **Issue** | Platform and version strings from user input were interpolated directly into filesystem paths (`File.join`) and GitHub raw URLs (`URI(...)`) without validation. Malicious inputs like `../../etc` or `foo%2F..%2Fbar` could cause path traversal or URI injection. |
| **Risk** | Medium-High in shared environments where Fauxhai options come from external config. |
| **Fix** | Added `SAFE_IDENTIFIER = /\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/` constant and `validate_identifier!` private method. Both `platform` and `version` are validated before use. |
| **Side effects** | Platforms or versions with spaces, slashes, or special characters will now raise `InvalidPlatform`. All existing platform JSON filenames match the pattern. |

### Fix 3: `frozen_string_literal: true` pragma (Low — Defense-in-Depth)

| Attribute | Detail |
|-----------|--------|
| **Files** | All 9 files under `lib/`: `fauxhai.rb`, `fauxhai/cache_manager.rb`, `fauxhai/exception.rb`, `fauxhai/fetcher.rb`, `fauxhai/mocker.rb`, `fauxhai/runner.rb`, `fauxhai/runner/default.rb`, `fauxhai/runner/windows.rb`, `fauxhai/version.rb` |
| **Issue** | None of the library files had `# frozen_string_literal: true`. Mutable strings increase the risk of accidental mutation and can be exploited in certain injection patterns. |
| **Risk** | Low. Primarily defense-in-depth and Ruby best practice. |
| **Fix** | Added `# frozen_string_literal: true` as the first line of each file. |
| **Side effects** | Any code that mutates string literals will now raise `FrozenError`. No such patterns exist in the current codebase. |

## Findings Not Fixed (Documented as Known Limitations)

| Finding | Severity | Reason Not Fixed |
|---------|----------|------------------|
| `ChefSpec::Runner` monkey-patching via `send(:define_method)` in fetcher.rb | High | Architectural — would require API redesign. Documented in SECURITY.md. |
| `:path` option allows reading arbitrary local files | Medium | By design — users must control their own inputs. Documented in SECURITY.md. |
| SSH options passed directly to `Net::SSH.start` | Medium | Changing would break the public API. Documented in SECURITY.md. |

## Validation Evidence

```
151 examples, 0 failures
rake validate:json — JSON files validated
./scripts/security_patch.sh check — 4/4 checks passed
```

## Rollback Plan

### Revert all changes at once
```bash
git revert HEAD --no-edit
```

### Revert individual fixes

**Fix 1 (digest/sha1):**
```bash
# Re-add the import
sed -i '' '1s/^# frozen_string_literal: true$/require "digest\/sha1"/' lib/fauxhai/fetcher.rb
```

**Fix 2 (input validation):**
```bash
# Remove SAFE_IDENTIFIER, validate_identifier!, and validation calls
git checkout HEAD~1 -- lib/fauxhai/mocker.rb
# Then re-apply frozen_string_literal if desired
```

**Fix 3 (frozen_string_literal):**
```bash
./scripts/security_patch.sh revert
```

## Scripted / Repeatable Approach

The `scripts/security_patch.sh` script provides:

- `check` mode — verifies all 3 patches are applied (CI-safe, exits 0/1)
- `apply` mode — idempotently applies the frozen_string_literal pragma
- `revert` mode — removes the frozen_string_literal pragma

Run in CI:
```bash
./scripts/security_patch.sh check
```

## Files Modified

| File | Change |
|------|--------|
| `lib/fauxhai.rb` | Added frozen_string_literal pragma |
| `lib/fauxhai/cache_manager.rb` | Added frozen_string_literal pragma |
| `lib/fauxhai/exception.rb` | Added frozen_string_literal pragma |
| `lib/fauxhai/fetcher.rb` | Removed unused `require "digest/sha1"`, added frozen_string_literal |
| `lib/fauxhai/mocker.rb` | Added input validation (SAFE_IDENTIFIER, validate_identifier!), added frozen_string_literal |
| `lib/fauxhai/runner.rb` | Added frozen_string_literal pragma |
| `lib/fauxhai/runner/default.rb` | Added frozen_string_literal pragma |
| `lib/fauxhai/runner/windows.rb` | Added frozen_string_literal pragma |
| `lib/fauxhai/version.rb` | Added frozen_string_literal pragma |
| `SECURITY.md` | Expanded with security considerations documentation |
| `scripts/security_patch.sh` | New — repeatable security check/apply/revert script |
| `ai-track-docs/security-hygiene.md` | New — this file |
