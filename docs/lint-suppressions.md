# RuboCop Suppressions

This document tracks all inline RuboCop suppressions (`rubocop:disable`) in
the strict-lint scope (`lib/fauxhai/` core module). Each suppression includes
the cop name, file location, and justification.

Strict config: [`.rubocop-strict.yml`](../.rubocop-strict.yml)
CI job: `lint-strict` in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

---

## Active Suppressions

### 1. `Style/ClassVars` — `lib/fauxhai.rb`

**Location:** [`lib/fauxhai.rb` line 33](../lib/fauxhai.rb)

```ruby
# rubocop:disable Style/ClassVars
@@root ||= File.expand_path("..", __dir__)
# rubocop:enable Style/ClassVars
```

**Justification:** `@@root` is the established public API (`Fauxhai.root`)
used by `Mocker`, `Fetcher`, and downstream consumers. Converting to a class
instance variable (`@root`) would change inheritance semantics and could break
any subclass that relies on `Fauxhai.root`. This is a low-risk, well-tested
code path.

**Removal condition:** If the project adopts a `Configuration` object or
removes subclass dependency on `root`.

---

### 2. `Layout/LineLength` — `lib/fauxhai/mocker.rb`

**Location:** [`lib/fauxhai/mocker.rb` line 143](../lib/fauxhai/mocker.rb)

```ruby
# rubocop:disable Layout/LineLength
warn "WARNING: you must specify a 'platform'..."
# rubocop:enable Layout/LineLength
```

**Justification:** This is a user-facing deprecation warning. Splitting it
across multiple lines would complicate the string interpolation and make the
warning message harder to grep for in user output. The line is 220 characters
(limit: 200).

**Removal condition:** When the deprecation period ends and the warning is
replaced with a hard error (shorter message).

---

### 3. `Metrics/AbcSize`, `Metrics/MethodLength` — `lib/fauxhai/runner.rb`

**Location:** [`lib/fauxhai/runner.rb` line 8](../lib/fauxhai/runner.rb)

```ruby
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
def initialize(_args)
  # ...33 lines, ABC=41.2...
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
```

**Justification:** `Runner#initialize` is a data-assembly method that builds
a sanitized Ohai hash by calling ~20 mixin methods. It is tightly coupled to
the Ohai data model and splitting it would create artificial abstractions with
no clear benefit. The method has **zero test coverage** today; refactoring it
is tracked in [backlog Issue 2](../docs/backlog-epic.md) (branch coverage).

**Removal condition:** When Runner is refactored and test coverage is added
(backlog Issue 2).

---

### 4. `Metrics/MethodLength` — `lib/fauxhai/mocker.rb` `fetch_from_github`

**Location:** [`lib/fauxhai/mocker.rb` line 94](../lib/fauxhai/mocker.rb)

```ruby
# rubocop:disable Metrics/MethodLength
def fetch_from_github(filepath)
  # ...26 lines (limit: 25)...
end
# rubocop:enable Metrics/MethodLength
```

**Justification:** `fetch_from_github` wraps an HTTP call with
`Fauxhai::Retrier`, validates the response, writes to cache, and calls
`parse_and_validate`. The extra line comes from the resilience wrapping.
Splitting the method would obscure the fetch→validate→cache flow.

**Removal condition:** If the method is refactored to extract the cache-write
step or the Metrics/MethodLength max is raised to 26.

---

## Resolved Findings (auto-corrected)

The following high-signal findings were **fixed** by RuboCop auto-correction:

| Cop | Count | Files |
|-----|-------|-------|
| `Style/FrozenStringLiteralComment` | 7 | All 7 files |
| `Style/RaiseArgs` | 4 | mocker.rb |
| `Lint/UnusedMethodArgument` | 3 | fetcher.rb, mocker.rb, runner.rb |
| `Lint/UnusedBlockArgument` | 1 | runner.rb |
| `Lint/Void` | 1 | fetcher.rb |
| `Style/FileWrite` | 2 | fetcher.rb, mocker.rb |
| `Style/StderrPuts` / `Style/GlobalStdStream` | 4 | mocker.rb |
| `Style/TrivialAccessors` | 1 | fauxhai.rb |
| `Style/ExpandPathArguments` | 1 | fauxhai.rb |
| `Style/ArgumentsForwarding` | 4 | fauxhai.rb |
| `Naming/BlockForwarding` | 4 | fauxhai.rb, fetcher.rb, mocker.rb |
| `Style/FetchEnvVar` | 1 | fetcher.rb |
| `Style/RedundantSelf` | 1 | fauxhai.rb |
| `Layout/*` (alignment, indentation) | 6 | mocker.rb |
| `Style/SelectByRegexp` | 1 | version_resolver.rb |
| `Style/IfUnlessModifier` | 1 | mocker.rb |
| `Style/GuardClause` | 1 | mocker.rb |
| `Naming/MemoizedInstanceVariableName` | 1 | mocker.rb |
| `Style/StringLiteralsInInterpolation` | 2 | mocker.rb |

**Total: 53 findings auto-corrected, 4 suppressed with justification.**
