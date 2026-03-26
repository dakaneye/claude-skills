# Go Context Patterns

> Context as first parameter, respect cancellation. Load when reviewing I/O or network code.

## Activation Triggers

Load this document when:
- File imports `context` package
- Functions have `context.Context` parameters
- Code makes HTTP requests or external API calls
- Reviewing long-running operations or goroutines

## Always Pass Context as First Parameter

```go
// AI SMELL: Context buried in struct or not passed
type Client struct {
    ctx     context.Context  // DON'T store context in struct
    baseURL string
}

func (c *Client) Fetch(url string) ([]byte, error) {
    req, _ := http.NewRequest("GET", url, nil)
    // No context! Can't cancel
    return c.do(req)
}

// RIGHT: Context as first parameter
type Client struct {
    baseURL string
    http    *http.Client
}

func (c *Client) Fetch(ctx context.Context, url string) ([]byte, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, fmt.Errorf("create request: %w", err)
    }
    resp, err := c.http.Do(req)
    if err != nil {
        return nil, fmt.Errorf("fetch %s: %w", url, err)
    }
    defer resp.Body.Close()
    return io.ReadAll(resp.Body)
}
```

## Respect Context Cancellation

```go
// AI SMELL: Ignoring context cancellation
func ProcessItems(ctx context.Context, items []Item) error {
    for _, item := range items {
        // Long operation - doesn't check cancellation
        if err := process(item); err != nil {
            return err
        }
    }
    return nil
}

// RIGHT: Check context in long-running operations
func ProcessItems(ctx context.Context, items []Item) error {
    for _, item := range items {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }

        if err := process(ctx, item); err != nil {
            return fmt.Errorf("process item %s: %w", item.ID, err)
        }
    }
    return nil
}

// RIGHT: Use context with timeout for external calls
func FetchWithTimeout(ctx context.Context, url string) ([]byte, error) {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }
    // ...
}
```

## Context Value Antipatterns

```go
// AI SMELL: Using context for optional parameters
ctx = context.WithValue(ctx, "verbose", true)
ctx = context.WithValue(ctx, "timeout", 30)

func Process(ctx context.Context) {
    if ctx.Value("verbose").(bool) {  // Type assertion panic risk
        log.Println("processing...")
    }
}

// AI SMELL: String keys (collision risk)
ctx = context.WithValue(ctx, "requestID", "abc123")

// RIGHT: Typed keys for request-scoped data ONLY
type contextKey string

const (
    requestIDKey contextKey = "requestID"
    userIDKey    contextKey = "userID"
)

func WithRequestID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, requestIDKey, id)
}

func RequestIDFrom(ctx context.Context) string {
    if id, ok := ctx.Value(requestIDKey).(string); ok {
        return id
    }
    return ""
}

// RIGHT: Pass configuration explicitly, not via context
type ProcessOptions struct {
    Verbose bool
    Timeout time.Duration
}

func Process(ctx context.Context, opts ProcessOptions) error {
    if opts.Verbose {
        log.Println("processing...")
    }
    // ...
}
```

## Context Propagation in Goroutines

```go
// WRONG: Losing context in goroutine
func Process(ctx context.Context, items []Item) {
    for _, item := range items {
        go func(item Item) {
            process(item)  // Lost context! Can't cancel
        }(item)
    }
}

// RIGHT: Pass context to goroutines
func Process(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)

    for _, item := range items {
        item := item  // Capture - unnecessary in Go 1.22+
        g.Go(func() error {
            return process(ctx, item)  // Context passed through
        })
    }

    return g.Wait()
}
```

## Review Checklist

- [ ] **[BLOCKER]** Context is first parameter
- [ ] **[BLOCKER]** Context not stored in structs
- [ ] **[BLOCKER]** Context propagated to goroutines
- [ ] **[MAJOR]** Cancellation checked in long-running operations
- [ ] **[MAJOR]** Timeout set for external calls
- [ ] **[MAJOR]** Configuration passed explicitly, not via context
- [ ] **[MINOR]** Context values only for request-scoped data (trace ID, user ID)
- [ ] **[MINOR]** Typed keys for context values

## Related Documents

- `go-concurrency.md` - Goroutine lifecycle and errgroup patterns
- `go-concurrency-patterns.md` - Advanced patterns with context
- `go-errors.md` - Handling context.Canceled and context.DeadlineExceeded
