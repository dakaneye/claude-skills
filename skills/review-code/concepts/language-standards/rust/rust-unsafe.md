# Rust Unsafe Code Patterns

> Rules for writing and reviewing unsafe Rust code. Load when reviewing code with `unsafe` blocks or FFI.

## Activation Triggers

Load this document when:
- Code contains `unsafe` keyword
- Raw pointers: `*const T`, `*mut T`
- `std::mem::transmute` or `transmute_copy`
- FFI boundaries: `extern "C"`, `#[no_mangle]`
- `static mut` declarations
- Implementing unsafe traits (`Send`, `Sync`, `GlobalAlloc`)
- Union field access

## What Unsafe Unlocks

Unsafe grants exactly five superpowers. Nothing else requires unsafe:

1. **Dereference raw pointers** (`*const T`, `*mut T`)
2. **Call unsafe functions** (including `extern` FFI functions)
3. **Access or modify mutable statics** (`static mut`)
4. **Implement unsafe traits** (`Send`, `Sync`, `GlobalAlloc`)
5. **Access union fields**

If code uses `unsafe` for anything else, the block is either unnecessary or the
author misunderstands what unsafe does.

## SAFETY Comments

Every `unsafe` block MUST have a `// SAFETY:` comment. Every `unsafe fn` MUST
have a `# Safety` section in its doc comment.

```rust
// BAD: Bare unsafe block — reviewer cannot verify correctness
unsafe {
    ptr::copy_nonoverlapping(src, dst, len);
}

// GOOD: SAFETY comment explains why invariants hold
// SAFETY: `src` and `dst` were allocated by the same allocator with
// layout `Layout::array::<T>(len)`. They do not overlap because `dst`
// was freshly allocated above. `len` is the exact count from the
// source slice.
unsafe {
    ptr::copy_nonoverlapping(src, dst, len);
}
```

```rust
// BAD: unsafe fn without doc comment
pub unsafe fn set_len(new_len: usize) { /* ... */ }

// GOOD: # Safety section documents caller requirements
/// Overrides the length of this buffer without dropping or initializing elements.
///
/// # Safety
///
/// - `new_len` must be less than or equal to `capacity()`.
/// - Elements at `old_len..new_len` must be initialized before being read.
pub unsafe fn set_len(&mut self, new_len: usize) {
    self.len = new_len;
}
```

## Soundness

A safe public API must never allow undefined behavior regardless of how it is
called. The unsafe code inside must uphold all invariants.

```rust
// BAD: Safe wrapper that can trigger UB with out-of-bounds index
pub fn get_unchecked(&self, index: usize) -> &T {
    // SAFETY: caller promises index is valid — BUT THIS IS A SAFE FUNCTION!
    unsafe { self.data.get_unchecked(index) }
}

// GOOD: Safe wrapper validates before entering unsafe
pub fn get(&self, index: usize) -> Option<&T> {
    if index < self.len {
        // SAFETY: We just verified index < self.len, and self.len <= capacity
        // is maintained by all constructors and push/pop methods.
        Some(unsafe { self.data.get_unchecked(index) })
    } else {
        None
    }
}
```

**Rule**: If a safe function can cause UB for any possible input, the code is
unsound. Fix the API or mark it `unsafe fn`.

## Valid Reasons for Unsafe

1. **FFI** — calling C libraries that Rust cannot verify

```rust
// Practical FFI example: calling libc's getenv
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

extern "C" {
    fn getenv(name: *const c_char) -> *const c_char;
}

pub fn env_var(key: &str) -> Option<String> {
    let c_key = CString::new(key).ok()?;
    // SAFETY: `c_key` is a valid null-terminated C string.
    // `getenv` returns either null or a pointer to a static
    // environment string that remains valid for the process lifetime.
    let ptr = unsafe { getenv(c_key.as_ptr()) };
    if ptr.is_null() {
        None
    } else {
        // SAFETY: `ptr` is non-null and points to a valid C string
        // as guaranteed by the POSIX getenv specification.
        Some(unsafe { CStr::from_ptr(ptr) }.to_string_lossy().into_owned())
    }
}
```

2. **Novel abstractions** — allocators, custom smart pointers, lock-free data structures
3. **Benchmarked performance** — safe code is measurably too slow (with profiling evidence)
4. **Low-level primitives** — implementing building blocks like `Vec`, `Arc`, `Mutex`

## Invalid Reasons for Unsafe

These are code smells that mean the design needs restructuring:

- **Bypassing the borrow checker** — redesign with proper ownership
- **Circumventing `Send`/`Sync`** — if the type is not thread-safe, do not lie
- **Shortcutting lifetimes via `transmute`** — fix the lifetime annotations instead
- **"I know what I'm doing"** — without proof (benchmarks, formal reasoning, SAFETY comment)
- **Avoiding refactoring** — unsafe as a shortcut to avoid restructuring code

```rust
// BAD: transmute to bypass lifetime — this is UB waiting to happen
fn extend_lifetime<'a, T>(t: &T) -> &'a T {
    unsafe { std::mem::transmute(t) }
}

// GOOD: Fix the actual lifetime relationship in the type system
struct Container<'a> {
    data: &'a [u8],
}
```

## Miri Testing

`cargo miri test` detects undefined behavior at runtime: use-after-free, data
races, out-of-bounds access, invalid pointer dereference, and more.

Run Miri in CI for any crate containing unsafe code:

```yaml
# GitHub Actions example
miri:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: dtolnay/rust-toolchain@nightly
      with:
        components: miri
    - name: Run Miri
      run: cargo miri test
      env:
        MIRIFLAGS: "-Zmiri-strict-provenance"
```

**Flags**: `-Zmiri-strict-provenance` catches pointer provenance violations.
Add `-Zmiri-disable-isolation` only if tests need filesystem or env access.

## static mut Alternatives

Never use `static mut`. It is a data race in every concurrent context and
requires unsafe for every access. Alternatives:

| Need | Use | Example |
|------|-----|---------|
| Simple counter/flag | `AtomicU32`, `AtomicBool` | `static INIT: AtomicBool = AtomicBool::new(false);` |
| One-time initialization | `OnceLock` | `static CONFIG: OnceLock<Config> = OnceLock::new();` |
| Lazy computation | `LazyLock` | `static RE: LazyLock<Regex> = LazyLock::new(\|\| Regex::new(r"...").unwrap());` |
| Complex shared state | `Mutex<T>` or `RwLock<T>` | `static CACHE: Mutex<HashMap<K, V>> = Mutex::new(HashMap::new());` |

```rust
// BAD: static mut — UB in any concurrent access
static mut COUNTER: u32 = 0;
fn increment() {
    unsafe { COUNTER += 1; }  // Data race if called from multiple threads
}

// GOOD: Atomic for simple values
use std::sync::atomic::{AtomicU32, Ordering};
static COUNTER: AtomicU32 = AtomicU32::new(0);
fn increment() {
    COUNTER.fetch_add(1, Ordering::Relaxed);
}
```

## Review Checklist

- [ ] **[BLOCKER]** Every `unsafe` block has `// SAFETY:` comment explaining why invariants hold
- [ ] **[BLOCKER]** Every `unsafe fn` has `# Safety` doc section listing caller requirements
- [ ] **[BLOCKER]** No safe public API can trigger undefined behavior (soundness)
- [ ] **[BLOCKER]** No `static mut` — use `AtomicU32`, `OnceLock`, `LazyLock`, or `Mutex`
- [ ] **[MAJOR]** Unsafe code wrapped in safe abstraction with minimal surface area
- [ ] **[MAJOR]** Miri testing enabled for all unsafe code paths (`cargo miri test`)
- [ ] **[MAJOR]** Unsafe justified by valid reason (FFI, benchmarked perf, novel abstraction)

## Related Documents

- `rust-ffi.md` - FFI patterns and C interop (planned)
- `rust-concurrency.md` - Thread safety and Send/Sync (planned)
