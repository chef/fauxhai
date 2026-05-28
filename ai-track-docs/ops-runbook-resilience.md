# Fauxhai Resilience — Ops Runbook

## Overview

Fauxhai uses a `Fauxhai::Resilience` helper to add timeout, retry, and
exponential backoff to all external call paths:

| Call Path | File | External Dependency | Resilience |
|---|---|---|---|
| GitHub HTTP fetch | `lib/fauxhai/mocker.rb` | `raw.githubusercontent.com` | Timeout + retry with backoff |
| SSH data collection | `lib/fauxhai/fetcher.rb` | Remote host via `Net::SSH` | Timeout + retry with backoff |
| Cache file read | `lib/fauxhai/cache_manager.rb` | Local filesystem | Retry with backoff (1 retry, 5s timeout) |

---

## Tuning Parameters

All parameters can be set globally via environment variables or per-call in code.

| Parameter | Default | Env Variable | Description |
|---|---|---|---|
| `max_retries` | 2 | `FAUXHAI_RETRY_MAX` | Max retry attempts (0 = no retries) |
| `base_delay` | 0.5s | `FAUXHAI_RETRY_BASE_DELAY` | Base delay for exponential backoff |
| `timeout` | 30s | `FAUXHAI_RETRY_TIMEOUT` | Per-attempt timeout in seconds |

### Backoff Formula

```
delay = base_delay × 2^(attempt-1) × random(0.5, 1.0)
```

Example with defaults (`base_delay=0.5`, `max_retries=2`):
- Attempt 1: immediate
- Retry 1: 0.25–0.5s delay
- Retry 2: 0.5–1.0s delay
- Total worst-case: ~31.5s (30s timeout + 1.5s backoff)

### Per-Call Overrides

CacheManager uses tighter settings since filesystem I/O should be fast:
- `max_retries: 1`, `base_delay: 0.1`, `timeout: 5`
- Retryable errors: `Errno::EINTR`, `Errno::EIO`, `IOError`

---

## Monitoring & Observability

Resilience events are logged via `Fauxhai.logger`:

| Level | Event | Message Pattern |
|---|---|---|
| WARN | Retry attempt | `Resilience: attempt N/M failed (ErrorClass: message), retrying in Xs` |
| ERROR | All retries exhausted | `Resilience: all N attempts exhausted (ErrorClass: message)` |

### Log Grep Patterns

```bash
# Find all retry events
grep "Resilience:" /path/to/log

# Find exhausted retries (failures)
grep "attempts exhausted" /path/to/log

# Count retries per time window
grep -c "retrying in" /path/to/log
```

---

## Escalation Steps

### 1. GitHub fetch failures (`mocker.rb`)

**Symptom:** `InvalidPlatform` errors with "HTTP error was encountered when
fetching from Github" after retries are exhausted.

**Diagnosis:**
```bash
# Check GitHub status
curl -s https://www.githubstatus.com/api/v2/status.json | ruby -rjson -e 'puts JSON.parse(STDIN.read)["status"]["description"]'

# Test raw endpoint directly
curl -I https://raw.githubusercontent.com/chef/fauxhai/main/PLATFORMS.md
```

**Mitigation:**
1. Increase retries: `export FAUXHAI_RETRY_MAX=5`
2. Increase timeout: `export FAUXHAI_RETRY_TIMEOUT=60`
3. Disable GitHub fetching entirely: pass `github_fetching: false` to Mocker
4. Ensure all needed platform JSONs are bundled in the gem (update gem version)

### 2. SSH fetch failures (`fetcher.rb`)

**Symptom:** SSH connection errors, timeouts, or `Errno::ECONNREFUSED` after
retries are exhausted.

**Diagnosis:**
```bash
# Test SSH connectivity
ssh -o ConnectTimeout=5 user@host echo OK

# Check if target is up
ping -c 3 host
```

**Mitigation:**
1. Increase retries: `export FAUXHAI_RETRY_MAX=5`
2. Use cached data: ensure cache in `tmp/` is populated (`force_cache_miss: false`)
3. Check SSH credentials and key permissions
4. Verify target host firewall rules

### 3. Cache read failures (`cache_manager.rb`)

**Symptom:** `IOError` or `Errno::EIO` on cache file read.

**Diagnosis:**
```bash
# Check file integrity
file tmp/<cache_key>
cat tmp/<cache_key> | python -m json.tool

# Check disk health
df -h .
```

**Mitigation:**
1. Clear corrupted cache: `rm -rf tmp/`
2. Check disk space and I/O errors in system logs
3. Verify file permissions: `ls -la tmp/`

---

## Rollback

To disable resilience and revert to pre-resilience behavior:

```ruby
# Disable retries globally (1 attempt, no backoff)
ENV["FAUXHAI_RETRY_MAX"] = "0"
```

Or per-call:
```ruby
Fauxhai::Resilience.with_retry(max_retries: 0, timeout: nil) do
  # original call without retry/timeout
end
```

No code changes or restarts required — environment variables take effect
immediately on the next call.

---

## CI Recommendations

```bash
# Fast-fail in CI (no retries, short timeout)
export FAUXHAI_RETRY_MAX=0
export FAUXHAI_RETRY_TIMEOUT=10

# Or disable GitHub fetching entirely
# Pass github_fetching: false in ChefSpec config
```

---

## Testing

```bash
# Run resilience unit + integration tests
bundle exec rspec spec/resilience_spec.rb

# Run full suite
bundle exec rspec

# Verify rubocop compliance
rubocop lib/fauxhai/resilience.rb
```
