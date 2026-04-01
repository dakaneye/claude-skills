# Rust Error Handling Patterns

> Detailed patterns for idiomatic Rust error handling. Load when reviewing Result, ?, thiserror, or anyhow code.

## Activation Triggers

Load this document when:
- Code uses `Result<T, E>`, `?` operator, or custom error types
- File imports `thiserror` or `anyhow`
- Code contains `.unwrap()`, `.expect()`, or `Box<dyn Error>`
- Reviewing error propagation or context chaining patterns

## thiserror vs anyhow Decision Matrix

| Criteria | thiserror | anyhow |
|----------|-----------|--------|
| **Use when** | Writing a library or reusable module | Writing a binary/application |
| **Caller needs** | To match on specific error variants | To log/report errors only |
| **Error type** | Custom enum with `#[derive(Error)]` | `anyhow::Error` (type-erased) |
| **Context** | Via `#[error]` display strings | Via `.context()` / `.with_context()` |
| **Downcast** | `errors::Is` / pattern match on enum | `anyhow::Error::downcast_ref` |

Many projects use both: `thiserror` in internal library modules where callers match on variants, `anyhow` at the binary boundary where errors are reported to the user.

## thiserror Error Enum Design

```rust
// BAD: Single catch-all variant hides failure modes
#[derive(Debug, thiserror::Error)]
enum AppError {
    #[error("{0}")]
    General(String),  // Caller can't distinguish IO from parse from validation
}

// GOOD: Distinct variants per failure mode
#[derive(Debug, thiserror::Error)]
enum ConfigError {
    #[error("read config file {path}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("parse config")]
    Parse(#[from] toml::de::Error),

    #[error("missing required field {field}")]
    MissingField { field: &'static str },

    #[error("invalid port {port}: must be 1-65535")]
    InvalidPort { port: u32 },
}
```

**Why**: Distinct variants let callers handle each failure mode differently. `#[from]` enables automatic conversion via `?`. `#[source]` preserves the error chain for debugging.

## anyhow Context Chaining

```rust
use anyhow::{Context, Result};

// BAD: Bare ? loses context — caller sees "No such file" with no clue what file
fn load_config(path: &Path) -> Result<Config> {
    let contents = std::fs::read_to_string(path)?;
    let config: Config = toml::from_str(&contents)?;
    Ok(config)
}

// GOOD: .context() adds human-readable breadcrumbs
fn load_config(path: &Path) -> Result<Config> {
    let contents = std::fs::read_to_string(path)
        .with_context(|| format!("read config file {}", path.display()))?;
    let config: Config = toml::from_str(&contents)
        .context("parse config")?;
    Ok(config)
}
// Error chain reads: "parse config: expected string, found integer at line 3"
```

Use `.with_context(|| ...)` when the message requires allocation (format strings). Use `.context("static str")` for static messages.

## The ? Operator

The `?` operator calls `From::from` on the error type and returns early. It replaces verbose manual matching.

```rust
// BAD: Manual match obscures the happy path
fn read_username(path: &Path) -> Result<String, io::Error> {
    let contents = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(e) => return Err(e),
    };
    match contents.lines().next() {
        Some(name) => Ok(name.to_string()),
        None => Err(io::Error::new(io::ErrorKind::InvalidData, "empty file")),
    }
}

// GOOD: ? keeps the happy path front and center
fn read_username(path: &Path) -> Result<String, io::Error> {
    let contents = std::fs::read_to_string(path)?;
    contents
        .lines()
        .next()
        .map(String::from)
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "empty file"))
}
```

Note: Using `?` in `main` requires `fn main() -> Result<()>` (with anyhow) or `fn main() -> Result<(), Box<dyn Error>>`.

## When unwrap/expect Are Acceptable

Reserve `.unwrap()` and `.expect()` for cases where failure is a programmer bug, not a runtime condition.

```rust
// ACCEPTABLE: Tests — panicking is the correct behavior
#[test]
fn test_parse_config() {
    let config = Config::from_str(VALID_TOML).unwrap();
    assert_eq!(config.port, 8080);
}

// ACCEPTABLE: Hardcoded value proven at compile time
let re = Regex::new(r"^\d{4}-\d{2}-\d{2}$").expect("date regex is valid");

// ACCEPTABLE: Invariant guaranteed by prior check
let items = vec![1, 2, 3];
assert!(!items.is_empty());
let first = items.first().expect("checked non-empty above");

// BAD: User input or external data — can fail at runtime
let port: u16 = env::var("PORT").unwrap().parse().unwrap();

// GOOD: Propagate the error
let port: u16 = env::var("PORT")
    .context("PORT env var not set")?
    .parse()
    .context("PORT is not a valid u16")?;
```

**Rule**: Always document the invariant with `.expect("reason this can't fail")`. Bare `.unwrap()` signals "I didn't think about this" to reviewers.

## Error Message Style

Match the Dave Cheney convention: state the action directly, no "Failed to" prefix.

```rust
// BAD: "Failed to" prefix creates stutter in chains
.context("Failed to read config file")?;
// Chain: "Failed to read config file: Failed to open: permission denied"

// GOOD: State the action
.context("read config file")?;
// Chain: "read config file: permission denied"

// BAD: Redundant "error" in the message
#[error("error parsing TOML")]
Parse(#[from] toml::de::Error),

// GOOD: Direct action
#[error("parse config")]
Parse(#[from] toml::de::Error),
```

Error chains should read naturally when printed: `"load user preferences: read config file: permission denied"`.

## Box<dyn Error> Anti-Pattern

```rust
// BAD: Caller can't match on error type, no structured info
fn process(input: &str) -> Result<Output, Box<dyn std::error::Error>> {
    // ...
}
// Caller is stuck with .to_string() and prayer

// GOOD (library): thiserror enum — caller can match variants
fn process(input: &str) -> Result<Output, ProcessError> {
    // ...
}

// GOOD (application): anyhow — rich context, backtraces
fn process(input: &str) -> anyhow::Result<Output> {
    // ...
}
```

**Why `Box<dyn Error>` is bad**: It erases the concrete type. Callers cannot use `match` or `if let` to handle specific errors. It provides no structured fields for programmatic inspection. Both `thiserror` and `anyhow` solve this — use them.

## Review Checklist

- [ ] **[BLOCKER]** No `.unwrap()` / `.expect()` in library code (outside tests)
- [ ] **[BLOCKER]** No `panic!` for recoverable errors
- [ ] **[MAJOR]** Libraries use `thiserror`; applications use `anyhow`
- [ ] **[MAJOR]** `?` operator paired with `.context()` for meaningful error chains
- [ ] **[MAJOR]** Error enums have distinct variants per failure mode (no catch-all `String`)
- [ ] **[MINOR]** Error messages state action directly, no "failed to" prefix

## Related Documents

- `rust-ai-antipatterns.md` - AI-generated Rust anti-patterns
- `rust-testing.md` - Testing error conditions in Rust
