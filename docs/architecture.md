# Fauxhai Architecture

This document maps the conceptual architecture of Fauxhai to actual file paths in the repository and illustrates the primary data flows.

## Module Map

```mermaid
graph TD
    subgraph "Entry Points"
        CLI["CLI Executable<br/><code>bin/fauxhai</code>"]
        API["Library API<br/><code>lib/fauxhai.rb</code>"]
    end

    subgraph "Core Modules"
        Mocker["Mocker<br/><code>lib/fauxhai/mocker.rb</code>"]
        Fetcher["Fetcher<br/><code>lib/fauxhai/fetcher.rb</code>"]
        Runner["Runner<br/><code>lib/fauxhai/runner.rb</code>"]
        Exception["Exception<br/><code>lib/fauxhai/exception.rb</code>"]
        Version["VERSION<br/><code>lib/fauxhai/version.rb</code>"]
    end

    subgraph "Platform Runners"
        DefaultRunner["Default Runner<br/><code>lib/fauxhai/platforms/runner/default.rb</code>"]
        WindowsRunner["Windows Runner<br/><code>lib/fauxhai/platforms/runner/windows.rb</code>"]
    end

    subgraph "Data Sources"
        PlatformJSON["Platform JSON Files<br/><code>lib/fauxhai/platforms/{os}/{ver}.json</code>"]
        SSHKeys["SSH Keys<br/><code>lib/fauxhai/keys/</code>"]
        GitHubRaw["GitHub Raw Content<br/>github.com/chef/fauxhai"]
    end

    subgraph "Consumers"
        ChefSpec["ChefSpec / RSpec Tests"]
        STDOUT["STDOUT (JSON)"]
    end

    API -->|"Fauxhai.mock()"| Mocker
    API -->|"Fauxhai.fetch()"| Fetcher
    CLI --> Runner

    Mocker --> PlatformJSON
    Mocker -->|"fallback fetch"| GitHubRaw
    Mocker --> Exception

    Fetcher -->|"net/ssh"| RemoteHost["Remote Host"]
    Fetcher -->|"cache to"| Cache["tmp/{sha2_hash}"]

    Runner --> DefaultRunner
    Runner --> WindowsRunner
    DefaultRunner --> SSHKeys
    WindowsRunner -.->|"includes"| DefaultRunner

    Mocker --> ChefSpec
    Fetcher --> ChefSpec
    Runner --> STDOUT
```

## Data Flow 1 — Mock Data Loading (ChefSpec)

The most common flow: a ChefSpec test loads simulated Ohai data for a specific platform and version.

```mermaid
sequenceDiagram
    participant Test as ChefSpec Test
    participant API as lib/fauxhai.rb
    participant M as lib/fauxhai/mocker.rb
    participant FS as lib/fauxhai/platforms/
    participant GH as GitHub Raw

    Test->>API: Fauxhai.mock(platform: "ubuntu", version: "20.04")
    API->>M: Mocker.new(options)
    M->>M: Resolve version ("20" → "20.04")
    M->>FS: Read ubuntu/20.04.json
    alt File found locally
        FS-->>M: JSON content
    else File not found locally
        M->>GH: HTTP GET raw JSON from main branch
        GH-->>M: JSON content
    end
    M->>M: Parse JSON into Hash
    M-->>Test: Return Ohai data Hash
    Note over Test: Node attributes populated<br/>for cookbook testing
```

## Data Flow 2 — CLI Mock Generation

The `bin/fauxhai` CLI generates fresh Ohai mock data by running Ohai locally and merging with mock attributes.

```mermaid
sequenceDiagram
    participant User as User / CI
    participant CLI as bin/fauxhai
    participant R as lib/fauxhai/runner.rb
    participant Ohai as Ohai::System
    participant DR as platforms/runner/default.rb
    participant WR as platforms/runner/windows.rb
    participant Keys as lib/fauxhai/keys/

    User->>CLI: $ fauxhai
    CLI->>R: Runner.new(ARGV)
    R->>Ohai: Initialize & load plugins
    Ohai-->>R: Real Ohai data
    R->>R: Detect platform (Windows?)
    alt Unix / Linux / macOS
        R->>DR: Include Default module
        DR->>Keys: Read SSH key files
        Keys-->>DR: Key content
        DR-->>R: Mock attributes (hostname, network, etc.)
    else Windows
        R->>WR: Include Windows module
        WR->>DR: Include Default (mixin)
        WR-->>R: Mock attributes (Windows network overrides)
    end
    R->>R: Whitelist real Ohai attrs + merge mocks
    R-->>CLI: JSON.pretty_generate(result)
    CLI-->>User: JSON to STDOUT
```

## Data Flow 3 — Remote Ohai Fetch via SSH

Fetch real Ohai data from a remote host over SSH, with local caching.

```mermaid
sequenceDiagram
    participant Caller as Test / Script
    participant API as lib/fauxhai.rb
    participant F as lib/fauxhai/fetcher.rb
    participant Cache as tmp/{sha2_hash}
    participant Remote as Remote Host (SSH)

    Caller->>API: Fauxhai.fetch(host: "node.example.com", user: "chef")
    API->>F: Fetcher.new(options)
    F->>F: Compute cache key = SHA256(user@host)
    F->>Cache: Check tmp/{cache_key}
    alt Cached & not force_cache_miss
        Cache-->>F: Return cached JSON
    else Not cached or force refresh
        F->>Remote: Net::SSH.start → run 'ohai'
        Remote-->>F: Raw JSON output
        F->>Cache: Write to tmp/{cache_key}
    end
    F->>F: Parse JSON into Hash
    F-->>Caller: Return Ohai data Hash
```

## Dependency Graph

```mermaid
graph LR
    subgraph "Runtime Dependencies"
        NetSSH["net-ssh"]
        OhaiGem["ohai ≥ 13.0"]
    end

    subgraph "Dev Dependencies"
        Chef["chef ≥ 13.0"]
        Rake["rake"]
        RSpec["rspec ~3.7"]
        RSpecIts["rspec-its ~1.2"]
    end

    Fauxhai["fauxhai-chef<br/><code>fauxhai-chef.gemspec</code>"]

    Fauxhai --> NetSSH
    Fauxhai --> OhaiGem
    Fauxhai -.-> Chef
    Fauxhai -.-> Rake
    Fauxhai -.-> RSpec
    Fauxhai -.-> RSpecIts
```

## Key File Reference

| Concept | File Path | Purpose |
|---------|-----------|---------|
| Library entry point | `lib/fauxhai.rb` | Autoloads modules, exposes `mock()` and `fetch()` |
| CLI entry point | `bin/fauxhai` | Command-line mock data generator |
| Mock data loader | `lib/fauxhai/mocker.rb` | Loads platform JSON locally or from GitHub |
| SSH fetcher | `lib/fauxhai/fetcher.rb` | Fetches real Ohai data via SSH with caching |
| CLI runner | `lib/fauxhai/runner.rb` | Orchestrates Ohai + mock attribute merging |
| Default runner | `lib/fauxhai/platforms/runner/default.rb` | Unix/Linux/macOS mock attributes |
| Windows runner | `lib/fauxhai/platforms/runner/windows.rb` | Windows-specific mock overrides |
| Exceptions | `lib/fauxhai/exception.rb` | `InvalidPlatform`, `InvalidVersion` |
| Version | `lib/fauxhai/version.rb` | `Fauxhai::VERSION` constant |
| Platform data | `lib/fauxhai/platforms/{os}/{ver}.json` | Ohai mock data per platform |
| SSH keys | `lib/fauxhai/keys/` | Mock SSH keys used by runners |
| Gem spec | `fauxhai-chef.gemspec` | Gem metadata, dependencies |
| Build tasks | `Rakefile` | JSON validation, test, doc generation |
| Tests | `spec/` | RSpec unit tests |
| CI | `.github/workflows/ci.yml` | GitHub Actions test pipeline |
