# Resilience: Retry, Backoff & Timeout

Fauxhai wraps external network calls (HTTP to GitHub, SSH to remote hosts)
with `Fauxhai::Retrier` — a lightweight retry-with-exponential-backoff helper.

## Protected Call Sites

| Call site | File | Default retries | Default timeout |
|-----------|------|-----------------|-----------------|
| GitHub HTTP fetch | `lib/fauxhai/mocker.rb` `fetch_from_github` | 2 | 10 s |
| SSH ohai fetch | `lib/fauxhai/fetcher.rb` `initialize` | 2 | 30 s |

## Tuning Parameters

All parameters can be overridden via environment variables or programmatically.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FAUXHAI_HTTP_RETRIES` | `2` | Max retry attempts for GitHub HTTP calls |
| `FAUXHAI_HTTP_TIMEOUT` | `10` | Per-attempt timeout (seconds) for HTTP calls |
| `FAUXHAI_SSH_RETRIES` | `2` | Max retry attempts for SSH ohai calls |
| `FAUXHAI_SSH_TIMEOUT` | `30` | Per-attempt timeout (seconds) for SSH calls |

### Programmatic (Retrier defaults)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_retries` | `2` | Number of retry attempts after first failure |
| `base_delay` | `0.5` | Initial backoff delay in seconds |
| `max_delay` | `5.0` | Maximum backoff delay ceiling in seconds |
| `timeout` | `10` | Per-attempt timeout; `nil` to disable |
| `on` | Network errors | Array of exception classes to retry on |

### Backoff Formula

```
delay = min(base_delay × 2^attempt, max_delay)
```

Example with defaults (`base_delay=0.5`, `max_delay=5.0`):

| Attempt | Delay |
|---------|-------|
| 1 | 0.5 s |
| 2 | 1.0 s |
| 3 | 2.0 s |
| 4+ | capped at 5.0 s |

### Retried Error Classes

By default, `Retrier::NETWORK_ERRORS` includes:

- `Timeout::Error`
- `Errno::ECONNREFUSED`
- `Errno::ECONNRESET`
- `Errno::EHOSTUNREACH`
- `Errno::ETIMEDOUT`
- `SocketError`
- `IOError`

The SSH call site additionally retries `Net::SSH::ConnectionTimeout` and
`Net::SSH::Disconnect`.

## Usage Examples

### Disable retries (fail fast)

```bash
FAUXHAI_HTTP_RETRIES=0 bundle exec rspec
```

### Increase timeout for slow networks

```bash
FAUXHAI_HTTP_TIMEOUT=30 FAUXHAI_SSH_TIMEOUT=60 bundle exec rspec
```

### Disable timeout entirely (programmatic)

```ruby
Fauxhai::Retrier.call(timeout: nil) { some_call }
```

### Enable logging to see retry attempts

```bash
FAUXHAI_LOG=1 FAUXHAI_HTTP_RETRIES=3 bundle exec rspec
# Output: WARN -- fauxhai: retrier: attempt=1 error=Errno::ECONNREFUSED delay=0.5s
```

## Rollback Guidance

If the resilience layer causes issues (e.g., tests hang due to retries
against an unreachable host), use these steps:

### Quick disable (no code change)

Set retries to `0` and timeout to a low value:

```bash
FAUXHAI_HTTP_RETRIES=0 FAUXHAI_HTTP_TIMEOUT=3 \
FAUXHAI_SSH_RETRIES=0 FAUXHAI_SSH_TIMEOUT=5 \
bundle exec rspec
```

This effectively bypasses all retry logic while keeping timeouts.

### Full rollback (code change)

1. In `lib/fauxhai/mocker.rb`, replace the `Fauxhai::Retrier.call(...)` block
   with the original `Net::HTTP.get_response(uri)` call.
2. In `lib/fauxhai/fetcher.rb`, replace the `Fauxhai::Retrier.call(...)` block
   with the original `Net::SSH.start(host, user, @options)` call.
3. Remove `lib/fauxhai/retrier.rb` and its autoload line in `lib/fauxhai.rb`.
4. Remove `spec/retrier_spec.rb`.
5. Run `bundle exec rspec` to confirm no regressions.

### Partial rollback

To keep timeouts but remove retries permanently, set `max_retries: 0` in
both call sites. The timeout wrapper still provides protection against
indefinite hangs.

## Test Coverage

12 failure tests in `spec/retrier_spec.rb` covering:

- First-attempt success
- Retry on matching error → recovery
- All retries exhausted → raise
- Non-matching errors not retried
- Exponential backoff delay calculation
- Max delay cap enforcement
- Timeout triggering
- Timeout + retry interaction
- Timeout disabled (nil)
- Logging on retry
- No logging when logger is nil
- Default configuration validation
