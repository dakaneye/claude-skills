# Rust Ownership & Borrowing

> Core ownership, borrowing, and lifetime patterns. Load when reviewing Rust code with lifetime annotations, clone calls, or borrow checker issues.

## Activation Triggers

Load this document when:
- Code contains lifetime annotations (`'a`, `'static`)
- Reviewing `.clone()` calls or `Rc`/`Arc` usage
- Borrow checker errors mentioned in context
- Code uses `&mut` patterns or interior mutability (`RefCell`, `Cell`, `Mutex`)
- `Cow` type appears in signatures or return types

## The Three Ownership Rules

1. Each value has exactly one owner
2. Only one owner at a time (ownership transfers on assignment/move)
3. Value is dropped when its owner goes out of scope

```rust
// Move semantics — s1 is invalid after assignment
let s1 = String::from("config");
let s2 = s1;
// println!("{s1}");  // COMPILE ERROR: value moved

// Copy types transfer by copy, not move
let port: u16 = 8080;
let backup_port = port;
println!("{port}");  // Fine — u16 implements Copy
```

## Borrowing Patterns

Many `&T` (shared) OR one `&mut T` (exclusive). Never both simultaneously.

```rust
// WRONG: Shared and mutable borrow overlap
fn update_config(config: &mut HashMap<String, String>, key: &str) {
    let current = config.get(key);       // &config (shared borrow)
    config.insert(key.to_owned(), "new".to_owned()); // &mut config (mutable borrow)
    println!("{current:?}");             // shared borrow still alive — CONFLICT
}

// RIGHT: End the shared borrow before mutating
fn update_config(config: &mut HashMap<String, String>, key: &str) {
    let current = config.get(key).cloned();  // clone ends the shared borrow
    config.insert(key.to_owned(), "new".to_owned());
    println!("{current:?}");
}
```

## When Clone Is Actually OK

Clone is a tool, not a sin. The question is whether it serves a purpose.

**Acceptable clones:**
- Small `Copy`-like types (`String` config values at startup)
- Crossing thread boundaries (`Arc::clone(&shared_state)`)
- Breaking borrow conflicts where restructuring is disproportionate

**Bad clones:**
```rust
// WRONG: Clone to silence the borrow checker in a hot path
fn process_entries(entries: &[LogEntry]) -> Vec<String> {
    entries.iter()
        .map(|e| e.clone())  // Cloning entire struct just to iterate
        .filter(|e| e.level == Level::Error)
        .map(|e| e.message)
        .collect()
}

// RIGHT: Borrow through the pipeline
fn process_entries(entries: &[LogEntry]) -> Vec<&str> {
    entries.iter()
        .filter(|e| e.level == Level::Error)
        .map(|e| e.message.as_str())
        .collect()
}
```

## Parameter Flexibility

Accept the most general borrowed form. Let callers decide allocation.

```rust
// WRONG: Forcing callers to allocate
fn resolve_endpoint(host: &String, path: &Vec<String>) -> String { ... }
fn read_manifest(path: &PathBuf) -> Result<Manifest> { ... }

// RIGHT: Accept borrowed slices
fn resolve_endpoint(host: &str, segments: &[String]) -> String { ... }
fn read_manifest(path: impl AsRef<Path>) -> Result<Manifest> { ... }
```

**Why**: `&String` auto-derefs to `&str`, but requiring `&String` forces callers holding `&str` to allocate. Same for `&Vec<T>` vs `&[T]` and `&PathBuf` vs `impl AsRef<Path>`.

## Lifetime Elision

The compiler infers lifetimes in three cases:
1. Each reference parameter gets its own lifetime
2. If exactly one input lifetime, it applies to all output references
3. If `&self` or `&mut self` exists, its lifetime applies to output references

```rust
// Elision handles this — no annotations needed
fn first_word(s: &str) -> &str { ... }
// Desugars to: fn first_word<'a>(s: &'a str) -> &'a str

// MUST annotate: multiple reference params, ambiguous output
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str {
    if a.len() >= b.len() { a } else { b }
}

// MUST annotate: struct holding a reference
struct ServiceConfig<'a> {
    endpoint: &'a str,
    api_key: &'a str,
}
```

**Rule of thumb**: if the compiler asks for lifetimes, add them. If it doesn't, leave them out.

## Interior Mutability

Mutate through a shared reference. Justified when the type's API is logically immutable but needs internal bookkeeping.

```rust
// JUSTIFIED: Cache behind an immutable API
struct DnsResolver {
    cache: RefCell<HashMap<String, IpAddr>>,
}

impl DnsResolver {
    fn resolve(&self, host: &str) -> Result<IpAddr> {
        if let Some(addr) = self.cache.borrow().get(host) {
            return Ok(*addr);
        }
        let addr = self.lookup(host)?;
        self.cache.borrow_mut().insert(host.to_owned(), addr);
        Ok(addr)
    }
}

// CODE SMELL: Rc<RefCell<T>> as default architecture
// WRONG: Fighting the borrow checker with indirection
struct Pipeline {
    stage_a: Rc<RefCell<StageA>>,
    stage_b: Rc<RefCell<StageB>>,  // Both stages mutate shared state
}

// RIGHT: Restructure ownership — pass data between stages
fn run_pipeline(input: Data) -> Result<Output> {
    let intermediate = stage_a(input)?;
    stage_b(intermediate)
}
```

**When to use what:**
- `Cell<T>` — `Copy` types only, zero overhead
- `RefCell<T>` — single-threaded, runtime borrow checks
- `Mutex<T>` / `RwLock<T>` — multi-threaded shared state

## Cow: Clone on Write

When a function sometimes borrows and sometimes allocates.

```rust
use std::borrow::Cow;

/// Normalize a container image reference, only allocating when needed.
fn normalize_image_ref(input: &str) -> Cow<'_, str> {
    if input.contains("://") {
        // Already has scheme — borrow the input as-is
        Cow::Borrowed(input)
    } else {
        // Need to prepend — must allocate
        Cow::Owned(format!("docker://{input}"))
    }
}

// Caller doesn't care whether it allocated
let reference = normalize_image_ref("cgr.dev/chainguard/static");
println!("{reference}");  // Works regardless of variant
```

**Why**: Avoids unconditional allocation when the common case needs no modification.

## Review Checklist

- [ ] **[BLOCKER]** No `.clone()` to silence borrow checker without justification
- [ ] **[BLOCKER]** No `Rc<RefCell<T>>` when ownership restructuring works
- [ ] **[MAJOR]** Parameters accept borrowed forms (`&str`, `&[T]`, `impl AsRef<Path>`)
- [ ] **[MAJOR]** Lifetimes only where elision doesn't cover
- [ ] **[MINOR]** `Cow` used where allocation is conditional

## Related Documents

- `rust-errors.md` - Error handling and the `?` operator
- `rust-concurrency.md` - `Send`, `Sync`, and `Arc` patterns
