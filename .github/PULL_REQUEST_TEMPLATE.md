## Description

<!-- Brief summary of the change -->

## Jira Ticket

<!-- Link to the Jira ticket, if applicable -->

## Changes

- 

## Review Focus

<!--
  List 3-5 specific areas the reviewer should pay attention to.
  Explain *what* to look at and *why* it matters.

  Example:
  1. **lib/fauxhai/mocker.rb — cached_read method** — Verify the cache
     returns independent hashes (callers may mutate the data).
  2. **spec/version_resolver_spec.rb** — Confirm edge cases cover
     nil, blank, and non-matching version inputs.
-->

1. 
2. 
3. 

## Verification Steps

<!--
  Exact commands a reviewer can copy-paste to verify the change locally.
  Include expected output where helpful.
-->

```bash
# 1. Set up
bundle install

# 2. Run the full test suite
bundle exec rspec

# 3. Check coverage (should be >80%)
open coverage/index.html

# 4. (Optional) Additional verification
# <add specific commands for your change>
```

**Expected result:** All tests pass, no new warnings, coverage ≥80%.

## Testing

- [ ] All existing tests pass (`bundle exec rspec`)
- [ ] New tests added for changed code
- [ ] Coverage verified locally

### Coverage Results

<!-- Paste the SimpleCov output from `bundle exec rspec` -->

```
Line Coverage:   __% ( / )
Branch Coverage: __% ( / )
```

**Total line coverage: ___%**

> Target: >80% line coverage. See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

## Rollback Plan

<!--
  Describe how to revert this change if something goes wrong after merge.
  Include the exact command or steps.
-->

```bash
git revert <merge-commit-sha>
```

<!-- For dependency changes, also include the pin-back command:
  e.g. Change gemspec back to: gem "rspec-its", "~> 1.2"
  Then: bundle update rspec-its
-->

## DCO

- [ ] All commits are signed off (`git commit --signoff`)
