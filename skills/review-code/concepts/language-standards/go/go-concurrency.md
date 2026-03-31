# Go Concurrency Basics

> Goroutines, channels, and data races. Load when reviewing concurrent code.

**Advanced patterns**: See `go-concurrency-patterns.md` for fan-out/fan-in, sync primitives, worker pools.

## Activation Triggers

Load this document when:
- File imports `sync`, `sync/atomic`, or `golang.org/x/sync/errgroup`
- Code contains `go func()` or `go someName(`
- Code contains channel operations (`make(chan`, `<-`, `chan T`)

## Goroutine Lifecycle Management

```go
// AI SMELL: Fire-and-forget goroutine (leak risk)
func StartWorker() {
    go func() {
        for {
            processQueue()  // Runs forever, no way to stop
        }
    }()
}

// RIGHT: Managed goroutine with shutdown
func StartWorker(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return  // Clean shutdown
            default:
                processQueue(ctx)
            }
        }
    }()
}

// BETTER: Use errgroup for coordinated goroutines
func RunWorkers(ctx context.Context, n int) error {
    g, ctx := errgroup.WithContext(ctx)

    for i := 0; i < n; i++ {
        workerID := i  // Capture - unnecessary in Go 1.22+
        g.Go(func() error {
            return runWorker(ctx, workerID)
        })
    }

    return g.Wait()
}
```

## Channel Patterns: Producer-Consumer

```go
// AI SMELL: Unbuffered channel causing goroutine leak
func ProcessAsync(items []Item) <-chan Result {
    results := make(chan Result)  // Unbuffered!

    go func() {
        for _, item := range items {
            results <- process(item)  // Blocks forever if receiver gone
        }
        close(results)
    }()

    return results
}

// RIGHT: Buffered channel or context-aware send
func ProcessAsync(ctx context.Context, items []Item) <-chan Result {
    results := make(chan Result, len(items))  // Buffered

    go func() {
        defer close(results)
        for _, item := range items {
            select {
            case <-ctx.Done():
                return  // Exit if cancelled
            case results <- process(item):
            }
        }
    }()

    return results
}
```

## Avoid Data Races

```go
// WRONG: Data race
type Stats struct {
    count int
}

func (s *Stats) Increment() {
    s.count++  // Not atomic!
}

// AI SMELL: Race with closure (pre-Go 1.22)
for i := 0; i < 10; i++ {
    go func() {
        fmt.Println(i)  // Race: i changes in loop
    }()
}

// RIGHT: Capture loop variable (required before Go 1.22)
for i := 0; i < 10; i++ {
    i := i  // Capture - unnecessary in Go 1.22+ but harmless
    go func() {
        fmt.Println(i)
    }()
}

// Go 1.22+: Loop variables are per-iteration by default
for i := 0; i < 10; i++ {
    go func() {
        fmt.Println(i)  // Safe in Go 1.22+
    }()
}

// RIGHT: Use atomic for simple counters
type Stats struct {
    count atomic.Int64
}

func (s *Stats) Increment() {
    s.count.Add(1)
}
```

## Channel Ownership Rules

```go
// RULE: Sender closes, receiver ranges
func producer(ctx context.Context) <-chan Item {
    items := make(chan Item)
    go func() {
        defer close(items)  // Sender closes
        for {
            select {
            case <-ctx.Done():
                return
            case items <- createItem():
            }
        }
    }()
    return items
}

func consumer(items <-chan Item) {
    for item := range items {  // Receiver ranges
        process(item)
    }
}

// WRONG: Receiver closing channel
func badConsumer(items chan Item) {
    for item := range items {
        process(item)
    }
    close(items)  // WRONG: Receiver should not close
}
```

## Review Checklist (Basics)

- [ ] **[BLOCKER]** Goroutines have clear shutdown mechanism (context cancellation)
- [ ] **[BLOCKER]** No data races (run with `-race` flag)
- [ ] **[BLOCKER]** Channels are closed by sender, not receiver
- [ ] **[MAJOR]** Buffered channels when receiver may not be ready
- [ ] **[MAJOR]** errgroup for coordinated goroutines
- [ ] **[MINOR]** Loop variables captured before goroutine (required pre-Go 1.22)

## Related Documents

- `go-concurrency-patterns.md` - Fan-out/fan-in, sync primitives, worker pools
- `go-context.md` - Context propagation and cancellation
- `go-performance.md` - Performance considerations for concurrent code
