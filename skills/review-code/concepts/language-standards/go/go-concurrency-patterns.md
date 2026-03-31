# Go Advanced Concurrency Patterns

> Fan-out/fan-in, sync primitives, bounded concurrency. Load when reviewing complex concurrent code.

**Prerequisite**: Load `go-concurrency.md` first for basics.

## Fan-Out/Fan-In

```go
// Fan-out: distribute work to multiple workers
func fanOut(ctx context.Context, input <-chan Job, workers int) []<-chan Result {
    outputs := make([]<-chan Result, workers)
    for i := 0; i < workers; i++ {
        outputs[i] = worker(ctx, input)
    }
    return outputs
}

// Fan-in: merge multiple channels into one
func fanIn(ctx context.Context, channels ...<-chan Result) <-chan Result {
    var wg sync.WaitGroup
    merged := make(chan Result)

    output := func(ch <-chan Result) {
        defer wg.Done()
        for result := range ch {
            select {
            case <-ctx.Done():
                return
            case merged <- result:
            }
        }
    }

    wg.Add(len(channels))
    for _, ch := range channels {
        go output(ch)
    }

    go func() {
        wg.Wait()
        close(merged)
    }()

    return merged
}
```

## Sync Primitives

```go
// sync.Mutex: Protect shared state
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// sync.RWMutex: Multiple readers, single writer
type Cache struct {
    mu   sync.RWMutex
    data map[string]string
}

func (c *Cache) Get(key string) (string, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    v, ok := c.data[key]
    return v, ok
}

// sync.Once: One-time initialization
type Client struct {
    once     sync.Once
    conn     *Connection
    connErr  error
}

func (c *Client) connect() {
    c.once.Do(func() {
        c.conn, c.connErr = dial()
    })
}

// sync.Pool: Reuse expensive allocations
var bufferPool = sync.Pool{
    New: func() any {
        return new(bytes.Buffer)
    },
}
```

## Bounded Concurrency

```go
// AI SMELL: Unbounded goroutines
func ProcessAll(items []Item) {
    for _, item := range items {
        go process(item)  // Could spawn millions!
    }
}

// RIGHT: Bounded concurrency with semaphore
func ProcessAll(ctx context.Context, items []Item, concurrency int) error {
    sem := make(chan struct{}, concurrency)
    g, ctx := errgroup.WithContext(ctx)

    for _, item := range items {
        item := item  // Capture - unnecessary in Go 1.22+

        select {
        case sem <- struct{}{}:
        case <-ctx.Done():
            return ctx.Err()
        }

        g.Go(func() error {
            defer func() { <-sem }()
            return process(ctx, item)
        })
    }

    return g.Wait()
}
```

## Worker Pool Pattern

```go
// RIGHT: Fixed worker pool with job channel
func WorkerPool(ctx context.Context, jobs <-chan Job, workers int) <-chan Result {
    results := make(chan Result)
    var wg sync.WaitGroup

    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range jobs {
                select {
                case <-ctx.Done():
                    return
                case results <- process(job):
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

## Pipeline Pattern

```go
// Stage 1: Generate
func generate(ctx context.Context, nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for _, n := range nums {
            select {
            case <-ctx.Done():
                return
            case out <- n:
            }
        }
    }()
    return out
}

// Stage 2: Square
func square(ctx context.Context, in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range in {
            select {
            case <-ctx.Done():
                return
            case out <- n * n:
            }
        }
    }()
    return out
}

// Usage: Pipeline composition
func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // Pipeline: generate -> square -> consume
    for n := range square(ctx, generate(ctx, 1, 2, 3, 4)) {
        fmt.Println(n)
    }
}
```

## Review Checklist (Advanced)

- [ ] **[BLOCKER]** Fan-in channels closed after all senders done (WaitGroup pattern)
- [ ] **[BLOCKER]** Worker pools have bounded size
- [ ] **[MAJOR]** Pipelines respect context cancellation at each stage
- [ ] **[MAJOR]** sync.RWMutex used when reads >> writes
- [ ] **[MAJOR]** sync.Once for expensive one-time initialization
- [ ] **[MINOR]** sync.Pool for frequently allocated temporary objects
- [ ] **[MINOR]** Consider sync.Map for concurrent read-heavy maps

## Related Documents

- `go-concurrency.md` - Basic goroutine and channel patterns (load first)
- `go-context.md` - Context propagation patterns
- `go-performance.md` - Performance optimization patterns
