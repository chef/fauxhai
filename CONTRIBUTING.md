# Contributing to a Progress Chef Workstation Project

Thank you for your interest in contributing to this project! It is part of the larger Progress Chef Workstation project. Contribution guidelines can be found at [Contributing to Progress Chef Workstation](https://chef.github.io/chef-oss-practices/projects/workstation/contributing/).

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