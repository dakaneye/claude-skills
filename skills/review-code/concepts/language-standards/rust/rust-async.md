# Rust Async Patterns (Tokio)

> Idiomatic async/await patterns with Tokio runtime. Load when reviewing async fn, .await, spawn, or select! code.

## Activation Triggers

Load this document when:
- Code contains `async fn`, `.await`, or `#[tokio::main]` / `#[tokio::test]`
- File imports `tokio::` (spawn, sync, time, fs, signal)
- Code uses `select!`, `Future`, `Pin`, or `JoinHandle`
- Reviewing concurrent I/O, task spawning, or shutdown logic

## When to Use Async

Async is for **I/O-bound** work: network calls, file I/O, database queries. It is NOT for CPU-bound computation.

```rust
// BAD: Async for CPU-bound work — no .await, wastes runtime thread
async fn compute_hash(data: &[u8]) -> Vec<u8> {
    sha256::digest(data).to_vec()
}

// GOOD: Sync function, or offload via spawn_blocking
fn compute_hash(data: &[u8]) -> Vec<u8> { sha256::digest(data).to_vec() }

async fn compute_hash_async(data: Vec<u8>) -> Vec<u8> {
    tokio::task::spawn_blocking(move || sha256::digest(&data).to_vec()).await.unwrap()
}
```

If your program makes one HTTP call and exits, sync is simpler. Async adds cancellation, pinning, and Send bounds. Justify the cost.

## Blocking in Async: The Cardinal Sin

NEVER call blocking functions inside async tasks. Tokio has a fixed number of worker threads (default: CPU core count). Blocking one starves the others and can deadlock the entire runtime.

```rust
// BAD                              // GOOD
std::fs::read_to_string(path)?     tokio::fs::read_to_string(path).await?
std::thread::sleep(dur)            tokio::time::sleep(dur).await
std::sync::Mutex across .await     tokio::sync::Mutex (see below)

// For unavoidable blocking (third-party sync library):
async fn compress(path: PathBuf) -> Result<Vec<u8>> {
    tokio::task::spawn_blocking(move || {
        let data = std::fs::read(&path)?;
        Ok(zstd::encode_all(&data[..], 3)?)
    }).await?
}
```

## tokio::sync::Mutex vs std::sync::Mutex

Use `tokio::sync::Mutex` when the lock is held **across** `.await` points. Use `std::sync::Mutex` when the critical section is short and does NOT cross `.await` -- it is actually faster for non-async work.

```rust
// BAD: std::sync::Mutex held across .await — can deadlock the runtime
use std::sync::Mutex;

async fn update_cache(cache: &Mutex<HashMap<String, String>>, key: String) {
    let mut guard = cache.lock().unwrap();
    let value = fetch_value(&key).await; // .await while holding std lock!
    guard.insert(key, value);
}

// GOOD: tokio::sync::Mutex when lock spans .await
use tokio::sync::Mutex;

async fn update_cache(cache: &Mutex<HashMap<String, String>>, key: String) {
    let mut guard = cache.lock().await;
    let value = fetch_value(&key).await;
    guard.insert(key, value);
}

// GOOD: std::sync::Mutex for short, non-async critical sections (faster)
use std::sync::Mutex;

fn record_metric(metrics: &Mutex<Vec<u64>>, value: u64) {
    metrics.lock().unwrap().push(value); // No .await — std::sync is fine
}
```

## Cancellation Safety

Tasks can be dropped at any `.await` point. When a future is dropped, partially-completed work is abandoned. Design for idempotency.

```rust
// BAD: Write half a file, get cancelled, leave corrupt state
async fn save_data(path: &Path, data: &[u8]) -> Result<()> {
    let mut file = tokio::fs::File::create(path).await?; // Truncates existing
    file.write_all(data).await?; // If cancelled here, file is truncated but incomplete
    Ok(())
}

// GOOD: Atomic write via temp file + rename
async fn save_data(path: &Path, data: &[u8]) -> Result<()> {
    let tmp = path.with_extension("tmp");
    tokio::fs::write(&tmp, data).await?;
    tokio::fs::rename(&tmp, path).await?; // Atomic on same filesystem
    Ok(())
}
```

`tokio::select!` drops the unselected branch. Be careful with stateful futures.

```rust
// BAD: msg may be partially processed then dropped
tokio::select! {
    msg = process_message(&mut stream) => handle(msg),
    _ = shutdown.recv() => return,
}

// GOOD: Use cancellation-safe methods (e.g., tokio streams are designed for this)
tokio::select! {
    msg = stream.recv() => { // recv() is cancellation-safe
        if let Some(msg) = msg { handle(msg); }
    }
    _ = shutdown.recv() => return,
}
```

## Timeouts

Wrap all external calls with `tokio::time::timeout`. Unbounded waits on external services cause cascading failures.

```rust
use tokio::time::{timeout, Duration};

// BAD: Hangs forever if server is unresponsive
let resp = client.get(format!("/users/{id}")).send().await?;

// GOOD: Bounded wait — double ? for timeout + inner Result
let resp = timeout(Duration::from_secs(30), client.get(format!("/users/{id}")).send())
    .await                              // Result<Result<Response, E>, Elapsed>
    .context("request timed out")?      // unwrap Elapsed
    .context("HTTP request failed")?;   // unwrap inner error
```

## Bounded Concurrency

Do not spawn unlimited tasks. Unbounded concurrency overwhelms downstream services and exhausts memory.

```rust
// BAD: Unbounded — spawns thousands of tasks at once
for url in urls {
    handles.push(tokio::spawn(async move { reqwest::get(&url).await?.text().await }));
}

// GOOD: Semaphore-gated concurrency
let semaphore = Arc::new(Semaphore::new(max_concurrent));
for url in urls {
    let permit = semaphore.clone().acquire_owned().await.unwrap();
    handles.push(tokio::spawn(async move {
        let result = reqwest::get(&url).await?.text().await;
        drop(permit);
        result
    }));
}

// GOOD: buffer_unordered for stream-based concurrency
use futures::stream::{self, StreamExt};
stream::iter(urls)
    .map(|url| async move { reqwest::get(&url).await?.text().await })
    .buffer_unordered(10)
    .collect::<Vec<_>>()
    .await;
```

## Spawning and JoinHandles

`tokio::spawn` returns a `JoinHandle`. Do not ignore it -- dropped handles detach the task (it runs forever with no way to observe panics or errors).

```rust
// BAD: Fire and forget — panic unobserved, no shutdown control
tokio::spawn(async move { loop { state.sync().await; } });
// JoinHandle dropped — task is detached

// GOOD: Graceful shutdown with cancellation token
use tokio_util::sync::CancellationToken;

let cancel = CancellationToken::new();
let token = cancel.clone();
let handle = tokio::spawn(async move {
    loop {
        tokio::select! {
            _ = token.cancelled() => return,
            _ = state.sync() => {}
        }
    }
});

// On shutdown: cancel all tasks, await handles
tokio::signal::ctrl_c().await?;
cancel.cancel();
if let Err(e) = handle.await {
    tracing::error!("task panicked: {e}");
}
```

## Review Checklist

- [ ] **[BLOCKER]** No blocking I/O in async tasks (`std::fs`, `std::thread::sleep`, sync HTTP)
- [ ] **[BLOCKER]** No `std::sync::Mutex` held across `.await` points
- [ ] **[BLOCKER]** No `block_on` inside async context (nested runtime panics)
- [ ] **[MAJOR]** Timeouts on all external calls (`tokio::time::timeout`)
- [ ] **[MAJOR]** Bounded concurrency (`Semaphore` or `buffer_unordered`)
- [ ] **[MAJOR]** Cancellation-safe designs (idempotent operations, atomic writes)
- [ ] **[MAJOR]** `JoinHandle`s awaited or aborted on shutdown

## Related Documents

- `rust-concurrency.md` - Thread-based concurrency patterns
- `rust-errors.md` - Error handling with `?`, `thiserror`, and `anyhow`
