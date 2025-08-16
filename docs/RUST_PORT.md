# `watchdom` - Detailed Rust Porting Specification
**Version 1.0**

## 1. Introduction & Core Principles

This document provides a detailed blueprint for porting the `watchdom` Bash script to a native Rust application. The goal is to create a more reliable, performant, and maintainable tool while preserving the user-friendly, script-like feel of the original.

### 1.1. Core Technical Choices
- **WHOIS Protocol:** A native Rust `whois` crate (e.g., `whois-rust`) will be used to eliminate the external `whois` command dependency.
- **CLI Parsing:** The `clap` crate (v4+) with its "derive" feature will be used for robust argument and command parsing.
- **Async Runtime:** `tokio` will be used as the async runtime to handle network I/O and prepare for future concurrency features.
- **Styling:** The `colored` crate will be used to replicate the color-coded output of the original script.

### 1.2. Code Style Philosophy
Per user request, the application will favor a "flat, string-based approach". This means:
- Public function APIs will primarily accept and return simple types like `&str`, `String`, `i32`, etc.
- We will use simple, self-contained structs for configuration, but avoid complex type hierarchies and trait-based polymorphism where simpler approaches suffice.
- The module structure will be flat to make the codebase easy to navigate.

## 2. Detailed Architecture & Design

### 2.1. Module & File Structure
The project will use a file-per-module structure, declared in `src/main.rs`.

```
watchdom-rust/
├── Cargo.toml
└── src/
    ├── main.rs     # Entry point, `tokio` runtime, top-level error handling, command dispatch
    ├── cli.rs      # `clap` struct definitions for the entire CLI
    ├── config.rs   # Logic for loading and managing TLD configs
    ├── tld.rs      # TLD-specific logic and data structures
    └── watch.rs    # Core polling loop, countdown logic, one-time query
    └── error.rs    # Custom error type for the application
```

### 2.2. CLI Specification (`cli.rs`)
The CLI will be defined declaratively using `clap`.

```rust
// src/cli.rs
use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,

    // Global flags, mirroring the BashFX standard
    #[arg(short, long, help = "Enable debug messages")]
    pub debug: bool,
    #[arg(short, long, help = "Enable verbose trace messages")]
    pub trace: bool,
    #[arg(short = 'y', long, help = "Automatically answer 'yes' to all prompts")]
    pub yes: bool,
    // etc...
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Monitor a domain's availability
    Watch {
        /// The domain name to watch
        domain: String,

        #[arg(short, long, help = "Base poll interval in seconds")]
        interval: Option<u64>,
        #[arg(long, help = "Target time for dynamic interval ramping")]
        until: Option<String>,
        #[arg(short, long, help = "Stop after N checks if domain is not found")]
        max_checks: Option<u32>,
    },

    /// Add or update a custom TLD configuration
    AddTld {
        tld: String,
        server: String,
        pattern: String,
    },

    // ... other subcommands like `ListTlds`, `TestTld`, `Time`, `Install` ...
}
```

### 2.3. Configuration Management (`config.rs`)
A `Config` struct will hold TLD definitions. We will use a simple, custom parser for the `~/.watchdomrc` file to maintain the `|`-delimited format.

```rust
// src/config.rs
use std::collections::HashMap;

// Represents a single TLD's configuration
#[derive(Debug, Clone)]
pub struct TldConfig {
    pub server: String,
    pub pattern: String,
}

// The main config struct holds all TLD definitions
#[derive(Debug, Default)]
pub struct Config {
    pub tlds: HashMap<String, TldConfig>,
}

impl Config {
    // Loads built-in defaults, then merges user config from ~/.watchdomrc
    pub fn load() -> Result<Self, AppError> {
        // ... implementation ...
    }
}
```

### 2.4. Error Handling (`error.rs`)
A custom `AppError` enum will provide clear, context-rich errors, replacing the simple exit codes of the Bash script.

```rust
// src/error.rs
#[derive(Debug)]
pub enum AppError {
    Io(std::io::Error),
    ConfigParseError(String),
    WhoisError(String),
    RateLimitDetected,
    TldNotFound(String),
}

// Implement the std::error::Error trait and From traits for easy error conversion.
```

## 3. Function & Logic Breakdown

| Module (`.rs`) | Function Signature | Description |
|---|---|---|
| `main` | `async fn main() -> Result<(), AppError>` | Main entry point. Initializes config, parses args, dispatches command. |
| `config`| `pub fn load() -> Result<Config, AppError>` | Loads TLD configs from file. |
| `tld` | `pub fn get_tld<'a>(config: &'a Config, domain: &str) -> Result<&'a TldConfig, AppError>` | Finds the correct TLD config for a domain. |
| `watch` | `pub async fn one_time_query(domain: &str, tld_config: &TldConfig) -> Result<(), AppError>` | Implements the simple, non-polling query. |
| `watch` | `pub async fn start_polling_watch(args: &WatchArgs, config: &Config) -> Result<(), AppError>` | The main polling loop. |
| `watch` | `fn calculate_interval(...) -> Duration` | Calculates the sleep duration based on phase. |

## 4. Phased Implementation Plan

This detailed, step-by-step plan ensures a logical progression from a basic tool to a feature-complete port.

### Phase 1: Core CLI & One-Time Query
- [ ] `cargo new watchdom-rust`
- [ ] Add `clap`, `tokio`, `whois-rust`, `colored` to `Cargo.toml`.
- [ ] Implement `src/cli.rs` with the `watch` subcommand and `domain` argument only.
- [ ] Implement `src/error.rs` with basic error types.
- [ ] In `main.rs`, parse the args and call a placeholder `one_time_query` function.
- [ ] Implement the real `one_time_query` in `watch.rs` to perform a real WHOIS lookup for `.com` domains and print the raw result to the console.

### Phase 2: TLD & Configuration
- [ ] Implement the `Config` and `TldConfig` structs in `config.rs`.
- [ ] Write the `load()` function to parse `~/.watchdomrc` and load built-in defaults.
- [ ] Implement `get_tld_config` in `tld.rs`.
- [ ] Update `one_time_query` to use the loaded config to check for domain availability based on the correct pattern, and return a meaningful exit code (`Ok` or `Err`).
- [ ] Implement the `add_tld` and `list_tlds` commands.

### Phase 3: Polling Logic
- [ ] Implement the `start_polling_watch` function skeleton in `watch.rs`.
- [ ] Add the `-i` and `-n` flags to the `Watch` command in `cli.rs`.
- [ ] Create the main `while` loop, calling the WHOIS query logic from Phase 2.
- [ ] Implement the countdown timer display using `std::thread::sleep`.

### Phase 4: Advanced Features & Polish
- [ ] Implement phase-aware polling by adding the `--until` flag and the `calculate_interval` logic.
- [ ] Add the `-y` flag and integrate it into any interactive prompts (like a future `_ensure_dependency` equivalent).
- [ ] Add robust error handling to the WHOIS query to detect patterns that suggest rate-limiting.
- [ ] Implement all remaining commands (`time`, `status`, `install`, etc.).

## 5. User-Facing Files

The Rust port will respect the same user-facing files as the original script:

-   **`~/.watchdomrc`**: For user-defined TLD configurations. The format `TLD|SERVER|PATTERN` will be maintained for compatibility.
-   **`~/.local/bin/fx/watchdom`**: The location of the installed binary (via symlink).
-   **`~/.local/lib/fx/watchdom`**: The location where the actual binary is copied by the `install` command.

## 6. Future Roadmap Considerations

The Rust architecture provides a solid foundation for future growth.

-   **Configuring TLD Providers:** The `Config` struct can be made generic over a `ConfigSource` trait, allowing TLDs to be loaded from files, remote URLs, or databases by implementing the trait.
-   **Concurrency (Footnote):** A key advantage of the Rust port is the ease of implementing concurrency. The "Multi-Domain Watching" feature could be built by spawning a separate asynchronous task (`tokio::spawn`) for each domain, allowing `watchdom` to monitor hundreds of domains simultaneously with minimal overhead, a task that would be extremely difficult and fragile in Bash.
