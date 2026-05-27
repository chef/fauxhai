# Security Policy

## Reporting a Vulnerability

See https://chef.io/security for our security policy and how to report a vulnerability.

## Secret Scanning

This repository uses [gitleaks](https://github.com/gitleaks/gitleaks) for
automated secret detection. Scanning runs:

- **In CI** — as the `secret-scan` job in `.github/workflows/ci.yml` on every
  push and pull request.
- **Locally** — developers can run it before committing:

  ```bash
  # Install (macOS)
  brew install gitleaks

  # Scan working directory
  gitleaks detect --config .gitleaks.toml --verbose --no-git

  # Scan full git history
  gitleaks detect --config .gitleaks.toml --verbose
  ```

### Configuration

The gitleaks configuration lives at `.gitleaks.toml`. It includes an allowlist
for known test fixture files that are expected to contain key-like data.

### Known Allowlisted Items

| Path | Justification |
|------|--------------|
| `lib/fauxhai/keys/id_rsa` | Test fixture SSH private key — deliberately committed for mock Ohai data generation. Not a real credential. Only the `.pub` counterpart is read by code (`Runner#keys`). |
| `lib/fauxhai/keys/id_dsa` | Same as above (DSA variant). |
| `lib/fauxhai/keys/*.pub` | Public key fixtures — not secrets. |
| `lib/fauxhai/platforms/*.json` | Platform mock data may contain sanitized SSH public keys in Ohai output. |

### Updating the Allowlist

If you add new test fixtures that contain key material:

1. Add the path pattern to `.gitleaks.toml` under `[allowlist] paths`.
2. Run `gitleaks detect --config .gitleaks.toml --no-git` to verify no
   unintended leaks are masked.
3. Document the justification in this file.
