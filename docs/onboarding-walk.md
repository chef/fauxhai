# Onboarding: Walk Workflow for Fauxhai

> **How to use this file:** Paste the contents below into GitHub Copilot Chat
> at the start of a new task. It gives Copilot the context it needs to guide
> you through the plan-first Walk workflow.

---

## Prompt — paste into Copilot Chat

```
I'm working on the chef/fauxhai repository and following the Walk workflow.
Here is the context you need:

## Project
Fauxhai provides mock Ohai data for ChefSpec testing. The core code lives
in lib/fauxhai/ with modules: Mocker (loads platform JSON), Fetcher (SSH),
Runner (CLI), VersionResolver (version matching), and Exception.

## Key files
- lib/fauxhai.rb          — entrypoint with autoloads
- lib/fauxhai/mocker.rb   — loads and validates platform JSON
- lib/fauxhai/fetcher.rb  — fetches Ohai data over SSH
- lib/fauxhai/version_resolver.rb — resolves platform versions
- spec/                   — RSpec tests (SimpleCov enabled, >80% target)
- Rakefile                — validate:json, spec, documentation tasks
- .github/copilot-instructions.md — full Copilot config

## Walk workflow phases
1. **Analysis** — understand the task, explore code, write a plan. Stop for approval.
2. **Implementation** — create branch, make changes file-by-file. Stop for approval.
3. **Testing** — run `bundle exec rspec`, capture coverage. Stop for approval.
4. **PR** — commit with `--signoff`, push, open PR with plan + evidence.

## Rules
- All commits must use `git commit --signoff`
- Coverage must be >80% line coverage
- Never edit VERSION, platforms.json, or PLATFORMS.md manually
- Use the PR template at .github/PULL_REQUEST_TEMPLATE.md
- Include test output and coverage percentage in every PR

## My task
[Describe your task here, e.g. "Add support for Rocky Linux 10" or
"Refactor the Fetcher class to extract caching logic"]

Please start with Phase 1: analyze the codebase, identify the files to
change, and propose a plan. Wait for my approval before coding.
```

---

## What happens next

After pasting the prompt, Copilot will:

1. **Explore** the repo and list the files relevant to your task.
2. **Propose a plan** with files to change, reasons, and expected impact.
3. **Wait for your "yes"** before writing any code.
4. Walk you through implementation, testing, and PR creation one phase at a time.

## Quick-reference commands

| Action | Command |
|--------|---------|
| Install deps | `bundle install` |
| Run tests | `bundle exec rspec` |
| View coverage | `open coverage/index.html` |
| Validate JSON | `bundle exec rake validate:json` |
| Commit (signed) | `git commit --signoff -m "message"` |

## Further reading

- [CONTRIBUTING.md](../CONTRIBUTING.md) — full contribution guide with Walk workflow details
- [.github/copilot-instructions.md](../.github/copilot-instructions.md) — Copilot configuration
- [.github/PULL_REQUEST_TEMPLATE.md](../.github/PULL_REQUEST_TEMPLATE.md) — PR template
