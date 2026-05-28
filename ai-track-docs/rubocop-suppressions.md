# Static Analysis Suppressions

This document records every RuboCop rule suppression in `.rubocop.yml`, and
the justification for each.

## Baseline → Result

| Metric | Value |
|---|---|
| **Baseline (no config, lib/ only)** | 461 offenses |
| **After config + manual fixes + autofix** | 0 offenses |
| **Scope** | `lib/`, `spec/`, `scripts/` (18 files) |
| **High-signal manual fixes** | 7 (see below) |

## Manual Fixes Applied (7 high-signal)

| # | Cop | File | Fix |
|---|---|---|---|
| 1 | `Style/ClassVars` | `lib/fauxhai.rb` | `@@root` → `@root` (class instance variable) |
| 2 | `Style/ExpandPathArguments` | `lib/fauxhai.rb` | `expand_path("../../", __FILE__)` → `expand_path("..", __dir__)` |
| 3 | `Style/RaiseArgs` | `lib/fauxhai/mocker.rb` | 7 × `raise X.new(msg)` → `raise X, msg` (exploded style) |
| 4 | `Style/GuardClause` | `lib/fauxhai/mocker.rb` | `validate_identifier!` — guard clause instead of `unless` wrapper |
| 5 | `Lint/UnusedMethodArgument` | `lib/fauxhai/runner.rb` | `args` → `_args` |
| 6 | `Lint/Void` | `lib/fauxhai/fetcher.rb` | Removed void `@data` at end of `initialize` |
| 7 | `Style/RedundantFreeze` | `lib/fauxhai/version.rb`, `mocker.rb` | Removed `.freeze` on strings (frozen_string_literal handles it) |

## Metric Suppressions (complexity/length)

| Rule | Scope | Justification |
|---|---|---|
| `Metrics/PerceivedComplexity` | `lib/fauxhai/mocker.rb`, `scripts/**/*` | `#version` and `#load_platform_data` implement multi-strategy resolution (exact match → prefix match → GitHub fetch → raise). Scripts are standalone tools. |
| `Metrics/CyclomaticComplexity` | `lib/fauxhai/mocker.rb`, `scripts/**/*` | Same as above. |
| `Metrics/MethodLength` | `lib/fauxhai/mocker.rb`, runner files, `scripts/**/*`, `spec/**/*` | Resolution methods are long but linear. Runner/scripts are CLI tools. Spec examples are naturally verbose. |
| `Metrics/ModuleLength` | `lib/fauxhai/mocker.rb`, runner files, `scripts/**/*` | Mocker is the single mock API class. Splitting would break the interface. |
| `Metrics/BlockLength` | `spec/**/*`, `Rakefile` | RSpec `describe`/`context` blocks and Rake tasks are inherently long. |
| `Metrics/AbcSize` | `lib/fauxhai/mocker.rb`, `lib/fauxhai/fetcher.rb`, `lib/fauxhai/runner.rb`, `scripts/**/*` | Complex orchestration methods where high ABC is inherent to the algorithm. |
| `Metrics/ClassLength` | `lib/fauxhai/mocker.rb`, `scripts/**/*` | Single-class modules that should not be split. |

## Style Suppressions

| Rule | Scope | Justification |
|---|---|---|
| `Style/StringLiterals` | Global: `double_quotes` | Project historically uses double quotes. Enforcing consistency avoids 349-offense churn with no semantic benefit. |
| `Style/TrailingCommaInHashLiteral` | Global: `no_comma` | Project convention: no trailing commas in hash literals. |
| `Style/NumericLiterals` | `lib/fauxhai/mocker.rb` | Numeric literals are platform version numbers (e.g., `2012`), not magic numbers needing separators. |
| `Style/Documentation` | runner files, `scripts/**/*` | CLI scaffolding and standalone scripts — top-level docs add no value. |
| `Naming/MethodParameterName` | `scripts/**/*` | Short parameter names acceptable in small script methods. |
| `Layout/LineLength` | `scripts/**/*` | Long heredoc/template lines in diagram generation scripts. |

## How to review / update

1. Run `bundle exec rubocop lib/ spec/ scripts/` or `./scripts/rubocop_autofix.sh`
2. If a suppression is no longer needed (e.g., after a refactor reduced complexity), remove it
3. If adding a new suppression, add a row to this table with a justification
4. Never suppress security-relevant cops (`Security/*`, `Lint/*`) without security review
