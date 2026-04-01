# Rust BORROWS Checklist — Quick Reference

> Flattened master checklist for Rust code review. Load for fast pass over any .rs file.

## Activation Triggers

Load this document when:
- Starting a Rust code review and need a single-page reference
- Running a quick quality pass before merging
- Reviewing AI-generated Rust code

## B — Borrowing & Ownership

- [ ] `[BLOCKER]` No `.clone()` to silence borrow checker — restructure ownership
- [ ] `[BLOCKER]` No `Rc<RefCell<T>>` when simpler ownership restructuring works
- [ ] `[MAJOR]` Accept `&str` not `&String`, `&[T]` not `&Vec<T>`
- [ ] `[MAJOR]` Prefer borrowing over ownership when callee doesn't need to own
- [ ] `[MINOR]` Use `Cow<'_, str>` when allocation is sometimes needed

> Deep dive: `rust-ownership.md`

## O — Output (Errors)

- [ ] `[BLOCKER]` No `unwrap()`/`expect()` in library code — use `?` operator
- [ ] `[BLOCKER]` No `panic!` for recoverable errors
- [ ] `[MAJOR]` Libraries: `thiserror` enums; Applications: `anyhow` with `.context()`
- [ ] `[MAJOR]` Error types are enums with distinct variants, not `Box<dyn Error>`
- [ ] `[MAJOR]` Error messages state action directly — no "failed to" prefix
- [ ] `[MINOR]` Doc tests use `?` not `unwrap`

> Deep dive: `rust-errors.md`

## R — Resources (Unsafe, Drop, RAII)

- [ ] `[BLOCKER]` `// SAFETY:` comment on every `unsafe` block
- [ ] `[BLOCKER]` `# Safety` doc section on every `unsafe fn`
- [ ] `[BLOCKER]` Sound APIs — no safe wrapper that can trigger UB
- [ ] `[BLOCKER]` No `static mut` — use `AtomicU32`, `OnceLock`, or `Mutex`
- [ ] `[MAJOR]` Wrap unsafe in safe abstractions; minimize surface area
- [ ] `[MAJOR]` Pass Miri testing for unsafe code paths

> Deep dive: `rust-unsafe.md`

## R — Robustness (Testing)

- [ ] `[BLOCKER]` Error paths tested explicitly (`Ok` and `Err`)
- [ ] `[MAJOR]` Doc tests on all public items using `?` not `unwrap`
- [ ] `[MAJOR]` Property-based tests for parsers/serializers (proptest)
- [ ] `[MAJOR]` `#[should_panic(expected = "...")]` for panic behavior tests
- [ ] `[MAJOR]` Miri testing for unsafe code in CI
- [ ] `[MAJOR]` Integration tests in `tests/` for public API contract

> Deep dive: `rust-testing.md`

## O — Optimization (Clippy, Performance)

- [ ] `[BLOCKER]` `cargo clippy -- -D warnings` passes
- [ ] `[BLOCKER]` `cargo fmt --check` passes
- [ ] `[MAJOR]` `clippy::pedantic` enabled project-wide
- [ ] `[MAJOR]` `clippy::unwrap_used` and `clippy::expect_used` enabled
- [ ] `[MAJOR]` `cargo deny check` for license/advisory compliance
- [ ] `[MAJOR]` `cargo audit` clean — no known vulnerabilities

> Deep dive: `rust-ai-antipatterns.md` (for clippy-adjacent AI patterns)

## W — Wrappers (Traits, Generics, Types)

- [ ] `[BLOCKER]` No Deref polymorphism — `Deref` is for smart pointers only
- [ ] `[MAJOR]` Eagerly derive `Debug`, `Clone`, `PartialEq`, `Default`
- [ ] `[MAJOR]` Newtypes for type-safe distinctions (`UserId` vs bare `i64`)
- [ ] `[MAJOR]` Generics over trait objects when types known at compile time
- [ ] `[MAJOR]` Types are `Send` and `Sync` where possible
- [ ] `[MAJOR]` Conversion methods follow `as_`/`to_`/`into_` naming
- [ ] `[MINOR]` No `get_` prefix on getters — just use the field name

> Deep dive: `rust-traits.md`

## S — Safety (Concurrency, Async)

- [ ] `[BLOCKER]` No blocking I/O in async tasks — use `spawn_blocking`
- [ ] `[BLOCKER]` No `std::sync::Mutex` across `.await` points — use `tokio::sync::Mutex`
- [ ] `[BLOCKER]` No `block_on` inside async context
- [ ] `[MAJOR]` Bounded concurrency (semaphores, `buffer_unordered`)
- [ ] `[MAJOR]` Cancellation handling at `.await` points — design for idempotency
- [ ] `[MAJOR]` Timeouts on all external calls (`tokio::time::timeout`)
- [ ] `[MAJOR]` `Arc<Mutex<T>>` for shared mutation; `Arc<RwLock<T>>` when reads dominate
- [ ] `[MAJOR]` JoinHandles awaited or aborted on shutdown

> Deep dives: `rust-concurrency.md`, `rust-async.md`

## AI Detection Quick Scan

| Signal | Severity | Action |
|--------|----------|--------|
| `.clone()` in loop body | BLOCKER | Restructure with iterators + collect |
| `.unwrap()` outside tests | BLOCKER | Replace with `?` + context |
| `Rc<RefCell<T>>` pattern | BLOCKER | Restructure ownership |
| `unsafe` without `// SAFETY:` | BLOCKER | Document or remove unsafe |
| `std::fs` / `std::thread::sleep` in async | BLOCKER | Use tokio equivalents |
| `static mut` | BLOCKER | Use atomics or OnceLock |
| `&String` / `&Vec<T>` params | MAJOR | Change to `&str` / `&[T]` |
| `for i in 0..len` index loop | MAJOR | Use `.iter()` combinators |
| `Box<dyn Error>` return | MAJOR | Use thiserror or anyhow |
| Trait with one implementor | MAJOR | Delete trait, use struct |
| `pub` on everything | MAJOR | Minimize public surface |
| Comments restating code | MINOR | Delete them |

> Deep dive: `rust-ai-antipatterns.md`

## Tooling Pipeline

```
cargo fmt --check          # Formatting
cargo clippy -- -D warnings  # Static analysis
cargo test                   # Unit + integration + doc tests
cargo miri test              # UB detection (if unsafe code)
cargo deny check             # License + advisory + duplicates
cargo audit                  # RustSec vulnerability scan
cargo doc --no-deps          # Verify docs build
```

## Related Documents

- `rust-ownership.md` — borrowing, lifetimes, clone patterns
- `rust-errors.md` — thiserror vs anyhow, ? operator, error enums
- `rust-traits.md` — generics vs trait objects, Deref, common traits
- `rust-unsafe.md` — SAFETY comments, soundness, Miri
- `rust-concurrency.md` — Send/Sync, Arc/Mutex, channels, atomics
- `rust-async.md` — tokio patterns, blocking, cancellation, timeouts
- `rust-testing.md` — unit, integration, doc, property, Miri tests
- `rust-iterators.md` — combinators vs C-style loops
- `rust-ai-antipatterns.md` — LLM-generated code patterns to flag
