# Rust Concurrency

> Thread safety through ownership and type system. Load when reviewing Rust code with shared state, threads, or parallelism.

## Activation Triggers

Load this document when:
- Code uses `Arc`, `Mutex`, `RwLock`, or `AtomicU32`/`AtomicBool`
- Code contains `thread::spawn` or `std::thread` imports
- Code uses `rayon` (`par_iter`, `par_bridge`)
- Code uses `mpsc` channels or `crossbeam::channel`
- Code references `Send` or `Sync` trait bounds

## Send and Sync Recap

Rust enforces thread safety at compile time through two marker traits.

| Trait  | Meaning                                      | Example types                     |
|--------|----------------------------------------------|-----------------------------------|
| `Send` | Safe to transfer ownership to another thread | `String`, `Vec<T>`, `Arc<T>`     |
| `Sync` | Safe to share `&T` references across threads | `Mutex<T>`, `AtomicU64`, `Arc<T>`|
| Neither| Must stay on one thread                      | `Rc<T>`, `RefCell<T>`            |

Most types are `Send + Sync` automatically. The compiler derives these from a type's fields. If any field is not `Send`, the containing type is not `Send`.

```rust
// COMPILE ERROR: Rc is not Send
use std::rc::Rc;
let data = Rc::new(42);
std::thread::spawn(move || {
    println!("{data}");  // ERROR: Rc<i32> cannot be sent between threads safely
});

// RIGHT: Use Arc for cross-thread ownership
use std::sync::Arc;
let data = Arc::new(42);
std::thread::spawn(move || {
    println!("{data}");  // Arc<i32> is Send + Sync
});
```

## Arc<Mutex<T>> Pattern

The workhorse for shared mutable state across threads. `Arc` provides shared ownership, `Mutex` provides exclusive access.

```rust
// BAD: Holding lock across a long operation
fn update_cache(cache: &Arc<Mutex<HashMap<String, Vec<u8>>>>, key: &str) {
    let mut guard = cache.lock().unwrap();
    let data = fetch_from_network(key);  // Lock held during I/O!
    guard.insert(key.to_owned(), data);
}

// GOOD: Lock, clone out, drop lock, work on copy
fn update_cache(cache: &Arc<Mutex<HashMap<String, Vec<u8>>>>, key: &str) {
    let data = fetch_from_network(key);  // No lock held during I/O
    let mut guard = cache.lock().unwrap();
    guard.insert(key.to_owned(), data);  // Lock held only for the insert
}

// GOOD: Explicit scope to minimize lock duration
fn read_and_process(state: &Arc<Mutex<AppState>>) -> Result<Output> {
    let snapshot = {
        let guard = state.lock().unwrap();
        guard.config.clone()  // Clone what you need, drop the lock
    };
    // Process snapshot without holding the lock
    expensive_computation(&snapshot)
}
```

**Key rules:**
- Lock, do minimal work, unlock. Never hold a lock across I/O or computation.
- Clone `Arc` to share across threads: `let handle = Arc::clone(&shared)`.
- Prefer `Arc::clone(&x)` over `x.clone()` to make shared-ownership intent clear.

## Arc<RwLock<T>> When Reads Dominate

Multiple concurrent readers, exclusive writers. Use when the read-to-write ratio is high.

```rust
use std::sync::{Arc, RwLock};

struct ConfigStore {
    inner: Arc<RwLock<Config>>,
}

impl ConfigStore {
    fn get_timeout(&self) -> Duration {
        // Multiple threads can read concurrently
        let config = self.inner.read().unwrap();
        config.timeout
    }

    fn update_timeout(&self, new_timeout: Duration) {
        // Writer gets exclusive access, blocks readers
        let mut config = self.inner.write().unwrap();
        config.timeout = new_timeout;
    }
}
```

**When to choose `RwLock` over `Mutex`:**
- Reads are frequent, writes are rare (config, caches, routing tables)
- Read operations take non-trivial time (worth the extra overhead of `RwLock`)

**When `Mutex` is better:**
- Writes are frequent or read/write ratio is near 1:1
- Lock hold time is very short (the overhead of `RwLock` is not worth it)

## Bounded Concurrency

Never spawn unlimited threads or tasks. OS threads are expensive (~8 MB stack each).

```rust
// BAD: Unbounded thread spawning
fn process_all(items: Vec<Item>) -> Vec<Result<Output>> {
    let handles: Vec<_> = items.into_iter()
        .map(|item| std::thread::spawn(move || process(item)))
        .collect();  // 10,000 items = 10,000 threads = OOM
    handles.into_iter().map(|h| h.join().unwrap()).collect()
}

// GOOD: Rayon for CPU-bound parallelism
use rayon::prelude::*;

fn process_all(items: &[Item]) -> Vec<Output> {
    items.par_iter()          // Uses a thread pool (defaults to num CPUs)
        .map(|item| process(item))
        .collect()
}

// GOOD: Bounded channel for I/O-bound work
use std::sync::mpsc;

fn process_bounded(items: Vec<Item>, max_concurrent: usize) -> Vec<Output> {
    let (tx, rx) = mpsc::sync_channel(max_concurrent);
    let items_len = items.len();

    for item in items {
        let tx = tx.clone();
        std::thread::spawn(move || {
            let result = process(item);
            let _ = tx.send(result);  // Blocks when channel is full
        });
    }
    drop(tx);  // Drop original sender so rx iterator terminates

    rx.iter().collect()
}
```

**Guidelines:**
- CPU-bound: use `rayon` (thread pool sized to CPU count)
- I/O-bound: use bounded channels or semaphores to limit concurrency
- Never call `thread::spawn` in an unbounded loop

## Message Passing

Prefer channels over shared state when data flows in one direction.

```rust
// std::sync::mpsc — multi-producer, single-consumer
use std::sync::mpsc;
use std::thread;

fn producer_consumer() {
    let (tx, rx) = mpsc::channel();

    // Spawn multiple producers
    for id in 0..4 {
        let tx = tx.clone();
        thread::spawn(move || {
            let result = expensive_work(id);
            tx.send(result).expect("receiver dropped");
        });
    }
    drop(tx);  // Drop the original sender

    // Single consumer collects all results
    for result in rx {
        handle_result(result);
    }
}
```

For more flexibility, use `crossbeam::channel`:
- Multi-producer, multi-consumer (MPMC)
- Bounded and unbounded variants
- `select!` macro for multiplexing multiple channels
- `never()` channel for conditional arms

```rust
use crossbeam::channel::{bounded, select};

let (work_tx, work_rx) = bounded(100);
let (done_tx, done_rx) = bounded(0);

// Worker reads from work_rx, signals done_tx
thread::spawn(move || {
    for task in work_rx {
        process(task);
    }
    let _ = done_tx.send(());
});
```

**When to use channels vs shared state:**
- Channels: data flows in one direction, pipeline architectures, decoupled components
- Shared state (`Arc<Mutex<T>>`): multiple threads need read/write access to the same data

## Atomics

Lock-free primitives for simple counters and flags. No mutex overhead, no poisoning.

```rust
// BAD: static mut for a counter (UB without synchronization)
static mut REQUEST_COUNT: u64 = 0;
fn handle_request() {
    unsafe { REQUEST_COUNT += 1; }  // Data race!
}

// GOOD: Atomic counter
use std::sync::atomic::{AtomicU64, Ordering};

static REQUEST_COUNT: AtomicU64 = AtomicU64::new(0);
fn handle_request() {
    REQUEST_COUNT.fetch_add(1, Ordering::Relaxed);  // Lock-free, thread-safe
}

// GOOD: Atomic flag for shutdown signaling
use std::sync::atomic::AtomicBool;

static SHUTDOWN: AtomicBool = AtomicBool::new(false);

fn worker_loop() {
    while !SHUTDOWN.load(Ordering::SeqCst) {
        do_work();
    }
}

fn request_shutdown() {
    SHUTDOWN.store(true, Ordering::SeqCst);
}
```

**Ordering guide:**
- `Relaxed` — counters, stats, anything where order relative to other operations doesn't matter
- `SeqCst` — flags, coordination, when in doubt (safest, slight overhead)
- `Acquire`/`Release` — paired operations guarding data (advanced; use `SeqCst` unless profiling demands otherwise)

## Mutex Poisoning

When a thread panics while holding a lock, the mutex becomes "poisoned." Subsequent `.lock()` calls return `Err(PoisonError)`.

```rust
use std::sync::Mutex;

let data = Mutex::new(vec![1, 2, 3]);

// Option 1: Crash on poison (most common — if another thread panicked,
// the data may be in an inconsistent state)
let guard = data.lock().unwrap();

// Option 2: Recover from poison (when you know the data is still valid)
let guard = data.lock().unwrap_or_else(|poisoned| {
    eprintln!("mutex poisoned, recovering");
    poisoned.into_inner()
});

// Option 3: Use parking_lot::Mutex which does not poison
// (popular crate, lighter weight, no poisoning)
```

**Guidance:** Default to `.unwrap()`. Poison recovery is rare and should be explicitly justified. If you find yourself recovering from poison frequently, investigate why threads are panicking.

## Review Checklist

- [ ] **[BLOCKER]** No data races — `Send`/`Sync` bounds respected, no `static mut`
- [ ] **[BLOCKER]** Mutex locks held for minimal duration (no I/O or computation under lock)
- [ ] **[MAJOR]** Bounded concurrency — no unlimited `thread::spawn` in loops
- [ ] **[MAJOR]** `Arc<Mutex<T>>` for shared mutation, `Arc<RwLock<T>>` when reads dominate
- [ ] **[MAJOR]** Prefer message passing over shared state when data flows one direction
- [ ] **[MINOR]** Atomics for simple counters/flags instead of `Mutex`
- [ ] **[MINOR]** `Arc::clone(&x)` over `x.clone()` for clarity of intent

## Related Documents

- `rust-ownership.md` — Ownership, borrowing, and lifetime patterns
- `rust-errors.md` — Error handling and the `?` operator
