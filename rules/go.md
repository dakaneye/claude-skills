---
globs: "*.go"
---

# Go Quality Rules (DRIVEC)

## Checklist

### D - DRY
- `[BLOCKER]` No duplicated branch logic across methods
- `[MAJOR]` Methods layer on each other, not copy-paste

### R - Receivers
- `[BLOCKER]` Pointer receivers when any method mutates
- `[MAJOR]` Consistent receiver type across all methods on a type
- `[MAJOR]` Methods that don't use receiver should be standalone functions

### I - Interfaces
- `[BLOCKER]` Accept interfaces, return structs
- `[BLOCKER]` No `interface{}`/`any` when generics work
- `[MAJOR]` 1-3 methods maximum; defined near consumer

### V - Validation
- `[MAJOR]` Complete or explicitly absent (no partial checks)
- `[MINOR]` Validate once at boundaries, trust internally

### E - Errors
- `[BLOCKER]` `fmt.Errorf` with `%w` for wrapping (not `%s`/`%v`)
- `[MAJOR]` `errors.New` for static strings
- `[MINOR]` No "failed to" prefix (state action directly: `"open file: %w"`)

### C - Context
- `[BLOCKER]` First parameter always; not stored in structs; propagated to goroutines
- `[MAJOR]` Cancellation respected in long operations

### Concurrency
- `[BLOCKER]` Goroutines have shutdown mechanism; channels closed by sender
- `[MAJOR]` Bounded concurrency for parallel work (errgroup)

### Testing
- `[BLOCKER]` Error cases tested explicitly
- `[MAJOR]` Table-driven with `t.Run()`; use `t.Context()` (Go 1.24+)

## AI Detection Signals

| Signal | Severity | What to Look For |
|--------|----------|------------------|
| Factory for single impl | BLOCKER | `ValidatorFactory` returning one type |
| Channel wrapping sync op | BLOCKER | `func F() <-chan R` for synchronous work |
| Cache without TTL/maxsize | BLOCKER | `map` cache with no eviction strategy |
| Interface for stdlib ops | MAJOR | `StringJoiner` wrapping `strings.Join` |
| Config struct 10+ fields | MAJOR | Functional options not used |
| Custom parsing for known formats | MAJOR | Hand-rolled semver/URL/JSON parsing |
| Generics where concrete works | MAJOR | `Repository[T]` for one entity type |
| "Helper" wrapping stdlib | MINOR | `IsEmpty(s)` instead of `s == ""` |
| "failed to" error prefix | MINOR | Verbose error stutter |
| Over-documented simple funcs | MINOR | Godoc on unexported one-liners |

## Top 3 Anti-Pattern Examples

### Factory for single implementation
```go
// BAD
type ValidatorFactory struct{}
func (f *ValidatorFactory) Create(t string) Validator { /* switch with 1 case */ }

// GOOD
func NewEmailValidator() *EmailValidator { return &EmailValidator{} }
```

### Channel wrapping synchronous work
```go
// BAD
func Process(item Item) <-chan Result {
    ch := make(chan Result, 1)
    go func() { ch <- doWork(item); close(ch) }()
    return ch
}

// GOOD
func Process(item Item) Result { return doWork(item) }
```

### Excessive configuration
```go
// BAD: 15-field config struct
type ClientConfig struct { BaseURL string; Timeout time.Duration; /* ...13 more */ }

// GOOD: Functional options with sensible defaults
type Option func(*Client)
func WithTimeout(d time.Duration) Option { return func(c *Client) { c.http.Timeout = d } }
func NewClient(base string, opts ...Option) *Client { /* apply opts */ }
```

## Deep Dives
See `~/.claude/concepts/language-standards/go/` for focused files on errors, receivers, interfaces, context, concurrency, testing, performance, and AI anti-patterns.
