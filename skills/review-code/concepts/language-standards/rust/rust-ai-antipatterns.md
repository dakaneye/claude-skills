# Rust AI-Generated Anti-Patterns

> Common patterns produced by AI that violate Rust idioms. Load when reviewing AI-assisted `.rs` code.

## Activation Triggers

Load this document when:
- Reviewing any `.rs` file generated or modified by AI assistants
- Code has excessive `.clone()` calls or `.unwrap()` outside tests
- Seeing factory patterns, trait hierarchies, or builder patterns for simple structs
- Code uses `String` parameters that are only read, or `HashMap<String, String>` for config
- Generated code seems to fight the borrow checker instead of working with it

## Clone Spam

```rust
// AI SMELL: .clone() to satisfy the borrow checker
fn process_items(items: Vec<String>) -> Vec<String> {
    let mut results = Vec::new();
    for item in items.clone() {  // Clones entire Vec
        let processed = item.clone();  // Clones each String
        results.push(format!("{}-done", processed));
    }
    results
}

// RIGHT: Consume the iterator, no clones needed
fn process_items(items: Vec<String>) -> Vec<String> {
    items.into_iter()
        .map(|item| format!("{item}-done"))
        .collect()
}
```

```rust
// AI SMELL: Clone of large struct when a reference works
fn validate(config: &Config) -> bool {
    let c = config.clone();  // Unnecessary clone
    c.timeout > 0 && !c.name.is_empty()
}

// RIGHT: Just use the reference
fn validate(config: &Config) -> bool {
    config.timeout > 0 && !config.name.is_empty()
}
```

## Unwrap Everywhere

```rust
// AI SMELL: Chain of unwraps — each one is a potential panic
fn load_config(path: &str) -> Config {
    let content = std::fs::read_to_string(path).unwrap();
    let parsed: Config = serde_json::from_str(&content).unwrap();
    let db_url = parsed.database.unwrap();
    parsed
}

// RIGHT: Propagate errors with ? and context
fn load_config(path: &str) -> anyhow::Result<Config> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("read config: {path}"))?;
    let parsed: Config = serde_json::from_str(&content)
        .context("parse config JSON")?;
    Ok(parsed)
}
```

## Over-Abstraction

```rust
// AI SMELL: Trait hierarchy and factory for two config options
trait ConfigStrategy {
    fn apply(&self, config: &mut Config);
}

struct ProductionStrategy;
struct DevelopmentStrategy;

impl ConfigStrategy for ProductionStrategy {
    fn apply(&self, config: &mut Config) { config.debug = false; }
}

impl ConfigStrategy for DevelopmentStrategy {
    fn apply(&self, config: &mut Config) { config.debug = true; }
}

struct ConfigBuilderFactory;

impl ConfigBuilderFactory {
    fn create(env: &str) -> Box<dyn ConfigStrategy> {
        match env {
            "prod" => Box::new(ProductionStrategy),
            _ => Box::new(DevelopmentStrategy),
        }
    }
}

// RIGHT: A function that returns a struct
fn config_for_env(env: &str) -> Config {
    Config {
        debug: env != "prod",
        ..Config::default()
    }
}
```

## Reimplementing std

```rust
// AI SMELL: Manual loop to find first match
fn find_admin(users: &[User]) -> Option<&User> {
    for user in users {
        if user.role == Role::Admin {
            return Some(user);
        }
    }
    None
}

// RIGHT: Use iterator combinators
fn find_admin(users: &[User]) -> Option<&User> {
    users.iter().find(|u| u.role == Role::Admin)
}
```

```rust
// AI SMELL: Manual flatten
fn collect_tags(items: &[Item]) -> Vec<&str> {
    let mut all_tags = Vec::new();
    for item in items {
        for tag in &item.tags {
            all_tags.push(tag.as_str());
        }
    }
    all_tags
}

// RIGHT: flat_map
fn collect_tags(items: &[Item]) -> Vec<&str> {
    items.iter()
        .flat_map(|item| item.tags.iter().map(String::as_str))
        .collect()
}
```

## Stringly-Typed APIs

```rust
// AI SMELL: String parameters for known variants
fn set_mode(mode: &str) {
    match mode {
        "read" => { /* ... */ }
        "write" => { /* ... */ }
        _ => panic!("unknown mode"),  // Runtime failure
    }
}

fn connect(config: HashMap<String, String>) {
    let host = config.get("host").unwrap();
    let port: u16 = config.get("port").unwrap().parse().unwrap();
    // ...
}

// RIGHT: Encode invariants in the type system
enum Mode { Read, Write }

fn set_mode(mode: Mode) {
    match mode {
        Mode::Read => { /* ... */ }
        Mode::Write => { /* ... */ }
        // No wildcard needed — exhaustive at compile time
    }
}

struct ConnectConfig {
    host: String,
    port: u16,
}

fn connect(config: &ConnectConfig) {
    // Fields are typed and guaranteed present
}
```

## Excessive pub Visibility

```rust
// AI SMELL: Everything is pub
pub struct Parser {
    pub input: String,
    pub position: usize,
    pub tokens: Vec<Token>,
}

pub fn advance(parser: &mut Parser) { /* ... */ }
pub fn peek(parser: &Parser) -> Option<&Token> { /* ... */ }
pub fn reset_internal_state(parser: &mut Parser) { /* ... */ }

// RIGHT: Pub only on the interface
pub struct Parser {
    input: String,
    position: usize,
    tokens: Vec<Token>,
}

impl Parser {
    pub fn new(input: String) -> Self { /* ... */ }
    pub fn parse(&mut self) -> Result<Ast, ParseError> { /* ... */ }

    fn advance(&mut self) { /* ... */ }
    fn peek(&self) -> Option<&Token> { /* ... */ }
    fn reset_internal_state(&mut self) { /* ... */ }
}
```

## Box dyn Error Return Types

```rust
// AI SMELL: Erased error type — callers cannot match
fn fetch_user(id: u64) -> Result<User, Box<dyn std::error::Error>> {
    let resp = reqwest::blocking::get(format!("/users/{id}"))?;
    let user: User = resp.json()?;
    Ok(user)
}

// RIGHT: Typed errors with thiserror
#[derive(Debug, thiserror::Error)]
enum FetchError {
    #[error("HTTP request: {0}")]
    Http(#[from] reqwest::Error),
    #[error("user {id} not found")]
    NotFound { id: u64 },
}

fn fetch_user(id: u64) -> Result<User, FetchError> {
    let resp = reqwest::blocking::get(format!("/users/{id}"))?;
    if resp.status() == 404 {
        return Err(FetchError::NotFound { id });
    }
    Ok(resp.json()?)
}

// OR for application code: anyhow::Result<User>
```

## C-Style Loops

```rust
// AI SMELL: Index-based loop with bounds checks at runtime
fn double_all(values: &mut Vec<i32>) {
    for i in 0..values.len() {
        values[i] = values[i] * 2;
    }
}

// RIGHT: Idiomatic iterator
fn double_all(values: &mut [i32]) {
    for v in values.iter_mut() {
        *v *= 2;
    }
}
```

## Deref for Inheritance

```rust
// AI SMELL: Using Deref to fake OOP inheritance
struct MyVec {
    inner: Vec<String>,
    name: String,
}

impl std::ops::Deref for MyVec {
    type Target = Vec<String>;
    fn deref(&self) -> &Self::Target { &self.inner }
}

// Now MyVec "inherits" all Vec methods — confusing API surface

// RIGHT: Explicit delegation or AsRef
struct MyVec {
    inner: Vec<String>,
    name: String,
}

impl MyVec {
    fn items(&self) -> &[String] { &self.inner }
    fn push(&mut self, item: String) { self.inner.push(item); }
}

impl AsRef<[String]> for MyVec {
    fn as_ref(&self) -> &[String] { &self.inner }
}
```

## Comments Restating Code

```rust
// AI SMELL: Noise comments
/// Creates a new vector
let v = Vec::new();

/// Iterates over the items
for item in &items {
    /// Checks if the item is valid
    if item.is_valid() {
        /// Pushes to results
        results.push(item);
    }
}

// RIGHT: Comments explain WHY, not WHAT
// Collect valid items first to avoid holding a lock during processing
let valid: Vec<_> = items.iter().filter(|i| i.is_valid()).collect();
```

## Hallucinated Features

```rust
// AI SMELL: API that does not exist
let result = some_vec.sorted();  // Vec has no .sorted() method
let x = my_option.unwrap_or_default_with(|| expensive());  // Not real
let s = String::from_iter(['a', 'b']);  // Exists, but AI may get the import wrong

// RIGHT: Always verify generated code compiles
// Use sort/sort_by for in-place, or .iter().sorted() from itertools
let mut sorted = some_vec.clone();
sorted.sort();

let x = my_option.unwrap_or_else(|| expensive());
```

## Quick Detection Table

| Pattern | Severity | Quick Test |
|---------|----------|------------|
| `.clone()` in loop body | BLOCKER | Can a reference or `into_iter` work instead? |
| `.unwrap()` outside tests | BLOCKER | Can `?` with context replace it? |
| Trait with one implementor | MAJOR | Delete the trait, use the struct directly |
| Manual loop doing what an iterator method does | MAJOR | Check `std::iter` docs |
| `String` parameter that is only read | MAJOR | Change to `&str` |
| `HashMap<String, String>` for config | MAJOR | Use a typed struct |
| `pub` on internal helpers | MAJOR | Remove `pub`, see what breaks |
| `Box<dyn Error>` return | MAJOR | Use `thiserror` or `anyhow` |
| `Deref` impl for non-smart-pointer | MAJOR | Use explicit delegation or `AsRef` |
| Comments restating code | MINOR | Delete them |
| Made-up std functions | BLOCKER | Run `cargo check` |

## Review Checklist

- [ ] **[BLOCKER]** No clone spam to satisfy borrow checker
- [ ] **[BLOCKER]** No `.unwrap()` in non-test code without justification
- [ ] **[BLOCKER]** No hallucinated APIs — code compiles with `cargo check`
- [ ] **[MAJOR]** No over-abstraction (traits/factories for single implementations)
- [ ] **[MAJOR]** No reimplemented std functionality (check iterators, Option/Result combinators)
- [ ] **[MAJOR]** No stringly-typed APIs where enums or newtypes work
- [ ] **[MAJOR]** Minimal `pub` surface area — private by default
- [ ] **[MAJOR]** Typed error enums or anyhow, not `Box<dyn Error>`
- [ ] **[MAJOR]** Idiomatic iterators, not C-style index loops
- [ ] **[MAJOR]** No `Deref` for fake inheritance
- [ ] **[MINOR]** No comments restating what code already says

## Related Documents

- `rust-ownership.md` — Borrow checker patterns and lifetime design
- `rust-iterators.md` — Iterator combinators and idiomatic loops
- `rust-errors.md` — Error handling patterns
- `rust-traits.md` — When traits are appropriate
