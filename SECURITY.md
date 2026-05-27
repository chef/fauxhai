# Security Policy

## Reporting a Vulnerability

See https://chef.io/security for our security policy and how to report a vulnerability.

## Security Considerations

### Input Validation

Platform and version identifiers are validated against a strict allowlist
(`/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/`). This prevents path traversal and URI
injection when these values are interpolated into filesystem paths or GitHub
raw URLs.

### Path Handling

The `:path` option in `Fauxhai::Mocker` uses `File.expand_path` to resolve
the user-supplied path. This option is intended for trusted local fixture
files only — do not pass untrusted input.

### SSH Credential Handling

`Fauxhai::Fetcher` passes the options hash directly to `Net::SSH.start`.
Do not log, persist, or expose the options hash, as it may contain
`:password` or `:key_data` values.

### ChefSpec Monkey-Patching

When ChefSpec is loaded, `Fetcher` injects a `fake_ohai` method into
`ChefSpec::Runner` at runtime. This is global state and can leak between
test examples. Be aware of this when running concurrent test suites.

### String Immutability

All library files use `# frozen_string_literal: true` to prevent accidental
string mutation at runtime.
