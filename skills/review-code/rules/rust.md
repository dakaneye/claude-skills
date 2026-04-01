---
globs: "*.rs"
---

# Rust Quality Rules (BORROWS)

## Checklist

### B - Borrowing & Ownership
- `[BLOCKER]` No `.clone()` to silence borrow checker — restructure ownership
- `[BLOCKER]` No `Rc<RefCell<T>>` when simpler ownership restructuring works
- `[MAJOR]` Accept `&str` not `&String`, `&[T]` not `&Vec<T>`
- `[MAJOR]` Prefer borrowing over ownership when callee doesn't need to own
- `[MINOR]` Use `Cow<'_, str>` when allocation is sometimes needed

### O - Output (Errors)
- `[BLOCKER]` No `unwrap()`/`expect()` in library code — use `?` operator
- `[BLOCKER]` No `panic!` for recoverable errors
- `[MAJOR]` Libraries: `thiserror` enums; Applications: `anyhow` with `.context()`
- `[MAJOR]` Error types are enums representing distinct failure modes, not `Box<dyn Error>`
- `[MINOR]` Doc tests use `?` not `unwrap`

### R - Resources (Unsafe, Drop, RAII)
- `[BLOCKER]` `// SAFETY:` comment on every `unsafe` block explaining invariants
- `[BLOCKER]` `# Safety` doc section on every `unsafe fn` listing caller requirements
- `[BLOCKER]` Sound APIs — no safe wrapper that can trigger undefined behavior
- `[MAJOR]` Wrap unsafe in safe abstractions; minimize surface area
- `[MAJOR]` Pass Miri testing for all unsafe code paths

### R - Robustness (Testing)
- `[BLOCKER]` Error paths tested explicitly (`Ok` and `Err`)
- `[MAJOR]` Doc tests on all public items using `?` not `unwrap`
- `[MAJOR]` Property-based tests for parsers/serializers (proptest)
- `[MAJOR]` `#[should_panic(expected = "...")]` for panic behavior tests
- `[MAJOR]` Miri testing for unsafe code

### O - Optimization (Clippy, Performance)
- `[BLOCKER]` `cargo clippy` passes with `-D warnings` in CI
- `[BLOCKER]` `cargo fmt --check` passes
- `[MAJOR]` `clippy::pedantic` enabled project-wide
- `[MAJOR]` `clippy::unwrap_used` and `clippy::expect_used` enabled
- `[MAJOR]` `cargo deny check` for license/advisory compliance

### W - Wrappers (Traits, Generics, Types)
- `[BLOCKER]` No Deref polymorphism — `Deref` is for smart pointers only
- `[MAJOR]` Eagerly implement `Debug`, `Clone`, `PartialEq`, `Default`
- `[MAJOR]` Newtypes for type-safe distinctions (user ID vs order ID)
- `[MAJOR]` Generics over trait objects when types known at compile time
- `[MAJOR]` Types are `Send` and `Sync` where possible

### S - Safety (Concurrency, Async)
- `[BLOCKER]` No blocking I/O in async tasks — use `spawn_blocking`
- `[BLOCKER]` No `std::sync::Mutex` across `.await` points — use `tokio::sync::Mutex`
- `[BLOCKER]` No `block_on` inside async context
- `[MAJOR]` Bounded concurrency (semaphores, `buffer_unordered`)
- `[MAJOR]` Cancellation handling at `.await` points
- `[MAJOR]` Timeouts on all external calls (`tokio::time::timeout`)

## AI Detection Signals

| Signal | Severity | What to Look For |
|--------|----------|------------------|
| `.clone()` to silence borrow checker | BLOCKER | Cloning inside loops or hot paths; clone where a reference suffices |
| `Rc<RefCell<T>>` everywhere | BLOCKER | Fighting ownership with interior mutability instead of restructuring |
| `unwrap()` in library code | BLOCKER | Panics in non-test code; no `?` operator usage |
| Missing `// SAFETY:` comments | BLOCKER | `unsafe` blocks without invariant documentation |
| Blocking in async context | BLOCKER | `std::fs::read`, `std::thread::sleep` in async fn |
| `static mut` usage | BLOCKER | Global mutable state — use `OnceLock`, `Mutex`, or atomics |
| `&String` or `&Vec<T>` parameters | MAJOR | Should be `&str` or `&[T]` for flexibility |
| C-style `for i in 0..vec.len()` loops | MAJOR | Should use `.iter()` with combinators |
| `Box<dyn Error>` as error type | MAJOR | Stringly-typed errors — use `thiserror` enum |
| `dyn Trait` when generics work | MAJOR | Unnecessary dynamic dispatch; known concrete types |
| Reimplementing `std` functionality | MAJOR | Hand-rolled flatten, custom string splitting, etc. |
| `String` where `&str` works | MAJOR | Unnecessary allocation; function only reads the string |
| `Deref` for inheritance-like behavior | MAJOR | Misusing Deref trait for field delegation / polymorphism |
| Excessive `pub` visibility | MAJOR | Everything marked `pub` when module-private suffices |
| Missing `#[must_use]` on Result fns | MINOR | Caller can silently ignore errors |
| Over-commenting obvious code | MINOR | `// increment counter` on `counter += 1` |

## Top 3 Anti-Pattern Examples

### Clone to silence the borrow checker
```rust
// BAD — unnecessary clone, hides ownership issue
fn process(data: &mut Vec<String>) {
    let snapshot = data.clone();
    for item in &snapshot {
        if item.starts_with("x") {
            data.push(format!("processed_{item}"));
        }
    }
}

// GOOD — restructure to avoid simultaneous borrow
fn process(data: &mut Vec<String>) {
    let additions: Vec<String> = data.iter()
        .filter(|item| item.starts_with("x"))
        .map(|item| format!("processed_{item}"))
        .collect();
    data.extend(additions);
}
```

### Unwrap in library code
```rust
// BAD — panics on invalid input
pub fn parse_config(path: &str) -> Config {
    let content = std::fs::read_to_string(path).unwrap();
    serde_json::from_str(&content).unwrap()
}

// GOOD — propagate errors with context
pub fn parse_config(path: &str) -> anyhow::Result<Config> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("read config from {path}"))?;
    let config = serde_json::from_str(&content)
        .context("parse config JSON")?;
    Ok(config)
}
```

### Stringly-typed API instead of leveraging the type system
```rust
// BAD — no compile-time safety
fn set_log_level(level: &str) { /* matches "debug", "info", ... */ }
fn transfer(amount: f64, from: &str, to: &str) { /* which is account ID? */ }

// GOOD — enums for fixed sets, newtypes for distinct values
#[derive(Debug, Clone, Copy)]
pub enum LogLevel { Debug, Info, Warn, Error }
fn set_log_level(level: LogLevel) { /* exhaustive match */ }

pub struct AccountId(String);
pub struct Amount(f64);
fn transfer(amount: Amount, from: AccountId, to: AccountId) { /* type-safe */ }
```

## Deep Dives
See `~/.claude/skills/dakaneye-review-code/rust-*.md` for focused files on ownership, errors, traits, unsafe, concurrency, async, testing, iterators, and AI anti-patterns.
