# Contributing to Fauxhai

Thank you for your interest in contributing to this project! It is part of the larger Progress Chef Workstation project. Contribution guidelines can be found at [Contributing to Progress Chef Workstation](https://chef.github.io/chef-oss-practices/projects/workstation/contributing/).

## Walk Workflow

This project follows a **plan-first, evidence-backed** development workflow called "Walk". Every change — feature, bug fix, refactor, or docs update — goes through four phases with explicit approval gates between them.

### Phase 1: Analysis & Planning

1. Understand the task (read the Jira ticket, issue, or request).
2. Explore the codebase to identify which files need to change.
3. Write a short plan listing the files, the reason for each change, and expected impact.
4. **Approval gate:** get confirmation before writing any code.

### Phase 2: Implementation

1. Create a feature branch (see [Branching Strategy](#branching-strategy) below).
2. Implement changes file-by-file, reviewing each diff.
3. **Approval gate:** get confirmation that diffs look correct before testing.

### Phase 3: Testing & Evidence

1. Run the full test suite: `bundle exec rspec`
2. Confirm all tests pass and coverage is >80%.
3. Capture test output and coverage percentage — these go into the PR description.
4. **Approval gate:** get confirmation that test results are acceptable.

### Phase 4: PR & Merge

1. Commit with DCO sign-off (see [DCO](#dco-sign-off) below).
2. Push the branch and open a PR using the [PR template](.github/PULL_REQUEST_TEMPLATE.md).
3. Include the refactor/implementation plan and test evidence in the PR body.
4. **Approval gate:** get confirmation before submitting the PR.

### Using GitHub Copilot with the Walk Workflow

Copilot is configured (via `.github/copilot-instructions.md`) to follow the Walk workflow automatically. When working with Copilot Chat:

- Copilot will propose a plan and wait for your approval before coding.
- Copilot will show diffs for review before moving to tests.
- Copilot will run tests and include coverage output in the PR description.
- You can paste the [onboarding prompt](docs/onboarding-walk.md) into Copilot Chat to get oriented on a new task.

## Branching Strategy

| Change type | Branch name pattern | Example |
|-------------|-------------------|---------|
| Jira ticket | `<JIRA_ID>` | `PROJ-123` |
| Feature | `add_<description>` | `add_ubuntu_24_04` |
| Bug fix | `fix/<description>` | `fix/version-resolver-nil` |
| Refactor | `refactor/<description>` | `refactor/extract-version-resolver` |
| Docs only | `docs/<description>` | `docs/walk-workflow` |

## PR Expectations

Every pull request must include:

1. **Description** — what changed and why.
2. **Plan** — the implementation plan (files changed, reasons, impact).
3. **Test evidence** — `bundle exec rspec` output with pass/fail count.
4. **Coverage percentage** — line and branch coverage from SimpleCov.
5. **DCO sign-off** — every commit must be signed (see below).

Use the [PR template](.github/PULL_REQUEST_TEMPLATE.md) which includes placeholders for all of the above.

## DCO Sign-Off

**All commits must include a DCO sign-off.** Builds will fail without it.

```bash
git commit --signoff -m "description of change"

# To fix a commit that was not signed:
git commit --amend --signoff --no-edit
```

## Running Tests

Run the full test suite with:

```bash
bundle exec rspec
```

## Code Coverage

This project uses [SimpleCov](https://github.com/simplecov-ruby/simplecov) for code coverage reporting. Coverage is collected automatically every time RSpec runs.

### Running coverage locally

```bash
bundle install
bundle exec rspec
```

After the run completes, the coverage summary is printed to the terminal:

```
Coverage report generated for RSpec to /path/to/fauxhai/coverage.
Line Coverage: 77.03% (57 / 74)
Branch Coverage: 60.71% (17 / 28)
```

An HTML report is also generated at `coverage/index.html`. Open it with:

```bash
open coverage/index.html   # macOS
xdg-open coverage/index.html # Linux
```

### Coverage requirements

- **All pull requests should target >80% line coverage.** This is a project-level requirement.
- Include the total coverage percentage in your PR description (see the PR template below).
- If your changes lower coverage, add tests to bring it back above the threshold.

### Coverage in CI

The CI pipeline includes a **"Coverage summary (advisory)"** job that:

1. Runs `bundle exec rspec` with SimpleCov on Ruby 3.4.
2. Parses line and branch coverage percentages from the output.
3. Posts a formatted summary table to the **GitHub Actions Job Summary**
   (visible on the PR's "Checks" tab → click the job → "Summary").

**This job is advisory only** — it uses `continue-on-error: true` and will
never block a merge, even if coverage is below the 80% target. Its purpose is
to give reviewers quick visibility into coverage without requiring local runs.

To view the coverage summary:
1. Open the PR on GitHub.
2. Click the "Checks" tab (or the status check details).
3. Click the **"Coverage summary (advisory)"** job.
4. The summary table appears at the top of the job page.

## Instrumentation / Logging

Fauxhai includes optional structured logging for `Mocker#data` — the primary
data-loading path. When enabled, each platform load emits:

- `platform` / `version` — which platform was loaded
- `source` — `disk` (first file read), `cache` (in-memory raw string hit),
  `github` (HTTP fetch), or `path` (user-specified file)
- `elapsed_ms` — wall-clock time for the load
- `[DEPRECATED]` — flag if the platform data is marked deprecated

### Enabling logging

**Via environment variable** (recommended for CI/debugging):

```bash
FAUXHAI_LOG=1 bundle exec rspec
```

**Programmatically:**

```ruby
require "logger"
Fauxhai.logger = Logger.new($stdout)
```

### Example output

```
I, [2026-05-27T13:40:57]  INFO -- fauxhai: platform_load: platform=ubuntu version=24.04 source=disk elapsed_ms=0.69
I, [2026-05-27T13:40:57]  INFO -- fauxhai: platform_load: platform=ubuntu version=24.04 source=cache elapsed_ms=0.27
I, [2026-05-27T13:40:57]  INFO -- fauxhai: platform_load: platform=centos version=7.7.1908 source=disk elapsed_ms=0.48 [DEPRECATED]
```

### Viewing in production/staging

In CI, set `FAUXHAI_LOG=1` as an environment variable in your workflow to see
platform load logs in the job output. In staging/production Chef environments,
set `Fauxhai.logger` to your application logger to route platform load events
into your existing log aggregation (ELK, Datadog, Splunk, etc.).

## Platform JSON Contract Tests

Every non-deprecated platform JSON file is validated against a golden schema
at `spec/fixtures/platform_schema.json`. The contract test
(`spec/platform_contract_spec.rb`) checks that each file contains the required
top-level keys with the correct types (string, numeric, or hash).

These tests run automatically as part of `bundle exec rspec` and in CI.

### Updating the contract

If a platform legitimately adds or removes a required top-level key:

1. Edit `spec/fixtures/platform_schema.json` — add/remove the key from the
   appropriate array (`required_string_keys`, `required_numeric_keys`, or
   `required_hash_keys`).
2. Run `bundle exec rspec spec/platform_contract_spec.rb` to verify all
   non-deprecated platforms still pass.
3. Note the schema change in your PR description explaining **why** the
   contract changed.

## Expeditor Labels

| Scenario | Labels |
|----------|--------|
| Docs only | `documentation`, `Expeditor: Skip All` |
| Feature | `enhancement`, `Expeditor: Bump Version Minor` |
| Bug fix | `bug` |
| Test only | `Expeditor: Skip Version Bump` |

## Files You Should Not Edit Manually

- `VERSION` — updated by release automation
- `platforms.json` — generated by `rake update_json_list`
- `PLATFORMS.md` — generated by `rake documentation:update_platforms`