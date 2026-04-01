# Rust Traits & Generics

> Trait design, dispatch strategy, and idiomatic type patterns. Load when reviewing trait-heavy Rust code.

## Activation Triggers

Load this document when:
- Reviewing trait definitions or `impl Trait` blocks
- Code uses `dyn Trait` or `Box<dyn Trait>`
- Generic type parameters or `where` clauses appear
- `Deref` implementations on custom types
- Derive macros on structs or enums
- Conversion trait implementations (`From`, `Into`, `AsRef`)
- `Send`/`Sync` bounds or thread-safety concerns

## Generics vs Trait Objects

Use generics (static dispatch) when the concrete type is known at compile time. Use `dyn Trait` (dynamic dispatch) when you need heterogeneous collections or plugin architectures.

```rust
// AI SMELL: Box<dyn Trait> when only one concrete type exists
fn process(handler: Box<dyn Handler>) -> Result<()> {
    handler.handle()  // vtable indirection for no reason
}

// RIGHT: Generic with trait bound — monomorphized, zero-cost
fn process<H: Handler>(handler: H) -> Result<()> {
    handler.handle()  // Static dispatch, inlined by compiler
}

// RIGHT: impl Trait in argument position (syntactic sugar for simple cases)
fn process(handler: impl Handler) -> Result<()> {
    handler.handle()
}

// LEGITIMATE USE: Heterogeneous collection requires trait objects
struct Pipeline {
    steps: Vec<Box<dyn Step>>,  // Different concrete types at runtime
}

// LEGITIMATE USE: Plugin architecture where types are unknown at compile time
fn load_plugin(path: &Path) -> Box<dyn Plugin> {
    // Loaded dynamically — trait object is the right choice
}
```

**Why**: Generics produce specialized code per type (monomorphization) with zero runtime cost. Trait objects add vtable indirection and prevent inlining. Only pay for dynamic dispatch when you genuinely need it.

## Deref Polymorphism Anti-Pattern

`Deref` is for smart pointers only (`Box`, `Arc`, `Rc`, custom pointer types). Using it for inheritance-like field delegation is an anti-pattern that confuses readers and breaks expectations.

```rust
// AI SMELL: Deref for "inheritance" — masquerades as a pointer type
struct MyWrapper {
    inner: Inner,
}

impl Deref for MyWrapper {
    type Target = Inner;
    fn deref(&self) -> &Inner {
        &self.inner  // Makes MyWrapper "inherit" all Inner methods
    }
}

// RIGHT: Explicit delegation methods
struct MyWrapper {
    inner: Inner,
}

impl MyWrapper {
    fn name(&self) -> &str {
        self.inner.name()
    }

    fn process(&self) -> Result<()> {
        self.inner.process()
    }
}

// RIGHT: AsRef for cheap reference conversions
impl AsRef<Inner> for MyWrapper {
    fn as_ref(&self) -> &Inner {
        &self.inner
    }
}

// LEGITIMATE USE: Smart pointer types
struct SharedBuffer {
    data: Arc<Vec<u8>>,
}

impl Deref for SharedBuffer {
    type Target = [u8];
    fn deref(&self) -> &[u8] {
        &self.data  // This IS a smart pointer — Deref is correct
    }
}
```

**Why**: `Deref` coercion happens implicitly. When used for field delegation, method resolution becomes unpredictable and the type pretends to be something it is not. Readers expect `Deref` targets to be the "pointed-to" value, not a parent class.

## Common Trait Implementations

Per Rust API Guidelines (C-COMMON-TRAITS), eagerly derive standard traits on public types.

```rust
// AI SMELL: Missing standard derives
pub struct Config {
    pub name: String,
    pub timeout: Duration,
}

// RIGHT: Derive everything applicable
#[derive(Debug, Clone, PartialEq, Eq, Hash, Default)]
pub struct Config {
    pub name: String,
    pub timeout: Duration,
}

// Manual Display when you need custom formatting (derive is not available)
impl fmt::Display for Config {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Config({}, {}ms)", self.name, self.timeout.as_millis())
    }
}
```

**When to derive vs implement manually**:
- **Derive**: `Debug`, `Clone`, `PartialEq`, `Eq`, `Hash`, `Default` — when all fields support it
- **Manual**: `Display` (always manual), `PartialOrd`/`Ord` (when ordering differs from field order), `Default` (when defaults are non-trivial)
- **Never derive on types with interior mutability** (`RefCell`, `Cell`) — the derived `PartialEq` will compare current state, which is surprising

## Send and Sync

`Send` means ownership can transfer across threads. `Sync` means shared references (`&T`) can be sent across threads. Most types are automatically both.

```rust
// Types that are NOT Send + Sync:
// - Rc<T>: not Send, not Sync (reference count is not atomic)
// - RefCell<T>: Send but not Sync (runtime borrow checking is not thread-safe)
// - *const T, *mut T: not Send, not Sync (raw pointers)
// - MutexGuard<T>: not Send on some platforms

// AI SMELL: Using Rc in a type that will be shared across threads
struct Registry {
    entries: Rc<Vec<Entry>>,  // Not Send + Sync — cannot use with threads
}

// RIGHT: Use Arc for shared ownership across threads
struct Registry {
    entries: Arc<Vec<Entry>>,  // Send + Sync when Entry is Send + Sync
}

// RIGHT: When you need interior mutability across threads
struct SharedState {
    data: Arc<Mutex<HashMap<String, Value>>>,  // Thread-safe interior mutability
}

// Per C-SEND-SYNC: assert thread safety in tests
#[cfg(test)]
mod tests {
    use super::*;
    fn assert_send<T: Send>() {}
    fn assert_sync<T: Sync>() {}

    #[test]
    fn thread_safety() {
        assert_send::<Registry>();
        assert_sync::<Registry>();
    }
}
```

**Why**: Per API Guidelines (C-SEND-SYNC), types that can be Send+Sync should be. Accidentally using `Rc` instead of `Arc` makes a type unusable in async or threaded contexts.

## Newtype Pattern

Wrap primitive types to provide type safety and prevent argument mix-ups.

```rust
// AI SMELL: Bare primitives for distinct concepts
fn transfer(from: i64, to: i64, amount: f64) -> Result<()> {
    // Easy to swap from/to — compiler won't catch it
}

// RIGHT: Newtypes enforce correct usage at compile time
pub struct AccountId(i64);
pub struct Amount(f64);

fn transfer(from: AccountId, to: AccountId, amount: Amount) -> Result<()> {
    // Impossible to pass an Amount where an AccountId is expected
}

// Implement traits to make newtypes ergonomic
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(i64);

impl UserId {
    pub fn new(id: i64) -> Self {
        Self(id)
    }

    pub fn as_i64(self) -> i64 {
        self.0
    }
}

impl fmt::Display for UserId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "user:{}", self.0)
    }
}
```

**Why**: Newtypes are zero-cost (same representation as the inner type). They catch logic errors at compile time that unit tests would miss, and they make function signatures self-documenting.

## Conversion Traits

Follow the Rust API Guidelines naming conventions (C-CONV):
- `as_` — cheap reference-to-reference conversion (no allocation)
- `to_` — expensive conversion that may allocate (like `to_string()`)
- `into_` — consuming conversion that takes ownership
- No `get_` prefix on getters (use bare name: `fn name(&self) -> &str`)

```rust
// AI SMELL: Wrong naming convention
impl Token {
    fn get_value(&self) -> &str { &self.value }       // Don't use get_ prefix
    fn into_string(&self) -> String { self.value.clone() }  // into_ but doesn't consume
    fn as_owned(&self) -> Token { self.clone() }       // as_ but allocates
}

// RIGHT: Follow as_/to_/into_ conventions
impl Token {
    fn value(&self) -> &str { &self.value }            // Getter: bare name
    fn as_str(&self) -> &str { &self.value }           // Cheap reference conversion
    fn to_uppercase(&self) -> String { self.value.to_uppercase() }  // Allocates
    fn into_string(self) -> String { self.value }      // Consumes self
}

// Use From/Into for conversions between types
impl From<String> for Token {
    fn from(value: String) -> Self {
        Token { value }
    }
}

// TryFrom for fallible conversions
impl TryFrom<&str> for Port {
    type Error = PortError;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        let n: u16 = s.parse().map_err(|_| PortError::Invalid(s.to_string()))?;
        if n == 0 { return Err(PortError::Zero); }
        Ok(Port(n))
    }
}
```

**Why**: Consistent naming tells callers the cost model. `as_` is always cheap, `to_` may allocate, `into_` consumes. Breaking these conventions misleads callers about performance.

## Trait Object Safety

A trait is object-safe (usable as `dyn Trait`) when it has no `Self` in return position and no generic methods.

```rust
// NOT object-safe: Self in return position
trait Cloneable {
    fn clone_self(&self) -> Self;  // Size of Self unknown at runtime
}

// NOT object-safe: Generic method
trait Serializer {
    fn serialize<W: Write>(&self, writer: W);  // Generics need monomorphization
}

// RIGHT: Object-safe design (per C-OBJECT)
trait Handler {
    fn handle(&self, request: &Request) -> Box<dyn Response>;  // No Self, no generics
}

// RIGHT: Split into object-safe and non-object-safe parts
trait Cloneable: CloneableBase {
    fn clone_box(&self) -> Box<dyn Cloneable>;  // Object-safe alternative
}

trait CloneableBase {
    fn clone_self(&self) -> Self where Self: Sized;  // Sized bound opts out of object safety
}
```

**Detection**: If you see `dyn Trait` and the trait has `-> Self` or generic methods, the code will not compile. Design traits that may be used as trait objects to be object-safe from the start.

## Review Checklist

- [ ] **[BLOCKER]** No `Deref` polymorphism (Deref only for smart pointer types)
- [ ] **[MAJOR]** Common traits derived: `Debug`, `Clone`, `PartialEq`, `Default`
- [ ] **[MAJOR]** Newtypes used for type-safe distinctions (no bare `i64` for IDs, etc.)
- [ ] **[MAJOR]** Generics preferred over trait objects when types are known at compile time
- [ ] **[MAJOR]** Types are `Send + Sync` where possible (`Arc` over `Rc` for shared data)
- [ ] **[MINOR]** Conversion methods follow `as_`/`to_`/`into_` naming conventions
- [ ] **[MINOR]** No `get_` prefix on getters
- [ ] **[MINOR]** Traits designed to be object-safe when trait objects are anticipated

## Related Documents

- Rust API Guidelines: C-COMMON-TRAITS, C-SEND-SYNC, C-OBJECT, C-CONV
