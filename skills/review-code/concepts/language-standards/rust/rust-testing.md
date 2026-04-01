# Rust Testing Patterns

> Idiomatic Rust testing across unit, integration, doc, and property-based tests. Load when reviewing test code.

## Activation Triggers

Load this document when:
- Reviewing `#[test]` or `#[cfg(test)]` blocks
- Reviewing files in `tests/` directory
- Reviewing `#[should_panic]`, `assert_eq!`, `assert!` macros
- Reviewing doc test blocks (` ```rust ` in doc comments)
- File uses `proptest` or `#[tokio::test]`
- Writing or reviewing test coverage

## Unit Tests (In-Module)

Tests live in the same file as the code inside a `#[cfg(test)]` module. This gives access to private functions. The module is compiled only when running `cargo test`.

```rust
// BAD: Tests in a separate file without access to private internals
// BAD: No cfg(test) gate — test code ships in release binary

// GOOD: Standard in-module test pattern
pub fn validate_email(email: &str) -> bool {
    email.contains('@') && email.len() > 3
}

fn normalize_domain(email: &str) -> String {
    email.split('@').last().unwrap_or("").to_lowercase()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validate_email_accepts_valid_address() {
        assert!(validate_email("user@example.com"));
    }

    #[test]
    fn validate_email_rejects_missing_at() {
        assert!(!validate_email("userexample.com"));
    }

    #[test]
    fn normalize_domain_lowercases_domain() {
        // Can test private function because of use super::*
        assert_eq!(normalize_domain("user@EXAMPLE.COM"), "example.com");
    }
}
```

## Integration Tests

Files in `tests/` are separate crates that can only use the public API. Each file compiles as its own test binary. Use `tests/common/mod.rs` for shared utilities.

```
my_crate/
  src/
    lib.rs
  tests/
    common/
      mod.rs        # Shared test helpers (NOT tests/common.rs)
    parse_config.rs  # Integration test binary
    validate.rs      # Integration test binary
```

```rust
// BAD: tests/common.rs — compiled as its own test binary, shows as empty suite
// GOOD: tests/common/mod.rs — imported as module, not a test binary

// tests/common/mod.rs
pub fn sample_config() -> String {
    r#"{ "name": "test", "port": 8080 }"#.to_string()
}

// tests/parse_config.rs
use my_crate::Config;

mod common;

#[test]
fn parse_valid_config_returns_config() {
    let input = common::sample_config();
    let config = Config::parse(&input).unwrap();
    assert_eq!(config.name, "test");
    assert_eq!(config.port, 8080);
}
```

## Doc Tests

Code blocks in doc comments are compiled and run as tests. They serve as documentation AND regression tests. Per Rust API Guidelines: all public items should have doc examples (C-EXAMPLE), and doc tests should use `?` not `unwrap` (C-QUESTION-MARK).

```rust
// BAD: No doc test on public function
pub fn parse_port(s: &str) -> Result<u16, ParseError> { ... }

// BAD: Doc test uses unwrap
/// ```
/// let port = my_crate::parse_port("8080").unwrap();
/// ```

// GOOD: Doc test with ? and hidden main wrapper
/// Parses a port number from a string.
///
/// # Examples
///
/// ```
/// # fn main() -> Result<(), Box<dyn std::error::Error>> {
/// let port = my_crate::parse_port("8080")?;
/// assert_eq!(port, 8080);
/// # Ok(())
/// # }
/// ```
///
/// Returns an error for invalid input:
///
/// ```
/// # fn main() -> Result<(), Box<dyn std::error::Error>> {
/// assert!(my_crate::parse_port("not_a_number").is_err());
/// assert!(my_crate::parse_port("99999").is_err());
/// # Ok(())
/// # }
/// ```
pub fn parse_port(s: &str) -> Result<u16, ParseError> {
    let port: u16 = s.parse().map_err(|_| ParseError::InvalidPort)?;
    if port == 0 {
        return Err(ParseError::InvalidPort);
    }
    Ok(port)
}
```

Lines prefixed with `#` are hidden in rendered docs but still compiled and executed.

## Testing Error Paths

Test both Ok and Err paths explicitly. Use `unwrap_err()` to assert errors. Use `#[should_panic(expected = "...")]` for panic tests.

```rust
// BAD: Only testing the happy path
#[test]
fn parse_config_works() {
    let config = parse_config("valid.toml").unwrap();
    assert_eq!(config.name, "app");
}

// GOOD: Both Ok and Err paths covered
#[test]
fn parse_config_valid_input_returns_config() {
    let config = parse_config("valid.toml").unwrap();
    assert_eq!(config.name, "app");
    assert_eq!(config.port, 3000);
}

#[test]
fn parse_config_missing_file_returns_io_error() {
    let err = parse_config("nonexistent.toml").unwrap_err();
    assert!(matches!(err, ConfigError::Io(_)));
}

#[test]
fn parse_config_invalid_toml_returns_parse_error() {
    let err = parse_config("malformed.toml").unwrap_err();
    assert!(matches!(err, ConfigError::Parse(_)));
}

// GOOD: Panic test with expected substring
#[test]
#[should_panic(expected = "index out of bounds")]
fn get_unchecked_panics_on_invalid_index() {
    let v = vec![1, 2, 3];
    let _ = v[10];
}
```

**Prefer `assert!(matches!(...))` over `if let` chains** for concise error variant checks.

## Async Tests

Use `#[tokio::test]` for async test functions. Each test gets its own runtime and runs in isolation.

```rust
// BAD: Manually building a runtime
#[test]
fn fetch_data_works() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let data = fetch_data("https://example.com").await.unwrap();
        assert!(!data.is_empty());
    });
}

// GOOD: Use #[tokio::test]
#[tokio::test]
async fn fetch_data_returns_nonempty_response() {
    let data = fetch_data("https://example.com").await.unwrap();
    assert!(!data.is_empty());
}

#[tokio::test]
async fn fetch_data_invalid_url_returns_error() {
    let err = fetch_data("not-a-url").await.unwrap_err();
    assert!(matches!(err, FetchError::InvalidUrl(_)));
}
```

For multi-threaded runtime: `#[tokio::test(flavor = "multi_thread", worker_threads = 2)]`.

## Property-Based Testing (proptest)

Generate random inputs and check that invariants hold. Proptest provides input shrinking to find the minimal failing case. Especially useful for parsers, serializers, and mathematical properties.

```rust
// BAD: Only testing a few handpicked examples
#[test]
fn roundtrip_json() {
    let original = Config { name: "test".into(), port: 8080 };
    let json = serde_json::to_string(&original).unwrap();
    let decoded: Config = serde_json::from_str(&json).unwrap();
    assert_eq!(original, decoded);
}

// GOOD: Property-based roundtrip test covers edge cases
use proptest::prelude::*;

proptest! {
    #[test]
    fn json_roundtrip_preserves_data(
        name in "[a-zA-Z0-9_]{1,64}",
        port in 1u16..=65535u16,
    ) {
        let original = Config { name, port };
        let json = serde_json::to_string(&original).unwrap();
        let decoded: Config = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(original, decoded);
    }

    #[test]
    fn parse_port_roundtrip(port in 1u16..=65535u16) {
        let s = port.to_string();
        let parsed = parse_port(&s).unwrap();
        prop_assert_eq!(port, parsed);
    }
}
```

## Miri for Unsafe Code

`cargo miri test` runs tests under an interpreter that detects undefined behavior. Essential for any crate with `unsafe` code. Miri catches: use-after-free, out-of-bounds access, invalid pointer dereference, data races.

```yaml
# CI step for Miri
- name: Run Miri
  run: |
    rustup component add miri
    cargo miri test
  env:
    MIRIFLAGS: "-Zmiri-strict-provenance"
```

Add Miri to CI for any crate containing `unsafe` blocks. Note: Miri cannot run tests that perform I/O or call FFI, so isolate pure logic tests for Miri coverage.

## Test Organization Tips

- Name tests descriptively: `parse_valid_input_returns_config`, `parse_missing_file_returns_io_error`
- Use `assert_eq!` over `assert!` for better failure messages (shows both values)
- Use `assert!(matches!(value, Pattern))` for enum variant checks
- Group related tests in nested modules within `#[cfg(test)]`
- Use `#[ignore]` for slow tests, run with `cargo test -- --ignored`
- Use `#[test]` not `#[bench]` for unit tests (benchmarks use `criterion` crate)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    mod parse {
        use super::*;

        #[test]
        fn parse_valid_input_returns_value() { /* ... */ }

        #[test]
        fn parse_empty_input_returns_error() { /* ... */ }
    }

    mod validate {
        use super::*;

        #[test]
        fn validate_rejects_negative() { /* ... */ }
    }
}
```

## Review Checklist

- [ ] **[BLOCKER]** Error paths tested explicitly (Ok and Err)
- [ ] **[MAJOR]** Doc tests on all public items using `?` not `unwrap`
- [ ] **[MAJOR]** Property-based tests for parsers/serializers
- [ ] **[MAJOR]** Miri testing for unsafe code in CI
- [ ] **[MAJOR]** Integration tests for public API contract
- [ ] **[MAJOR]** `#[should_panic(expected = "...")]` includes expected substring
- [ ] **[MINOR]** Descriptive test names following `verb_condition_result` pattern

## Related Documents

- `rust-errors.md` - Error types and Result handling
- `rust-unsafe.md` - Unsafe code patterns (pair with Miri)
