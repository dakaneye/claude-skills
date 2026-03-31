# Go Receiver Type Patterns

> When to use value vs pointer receivers. Load when reviewing struct methods.

## Activation Triggers

Load this document when:
- Reviewing struct method definitions (`func (r *Type)` or `func (r Type)`)
- Struct has multiple methods with different receiver types
- Reviewing performance-sensitive code with small structs

## Value vs Pointer Receivers

```go
// AI SMELL: Pointer receiver on small immutable type
type PackageInfo struct {
    Scope   string  // 16 bytes
    Name    string  // 16 bytes
    Version string  // 16 bytes = 48 bytes total
}

func (n *PackageInfo) FullName() string {  // Forces heap allocation
    if n.Scope == "" {
        return n.Name
    }
    return "@" + n.Scope + "/" + n.Name
}

// RIGHT: Value receiver for small, read-only types
func (n PackageInfo) FullName() string {  // Can stay on stack
    if n.Scope == "" {
        return n.Name
    }
    return "@" + n.Scope + "/" + n.Name
}
```

**Rule**: Use value receivers when:
- Type is small (< 64 bytes, roughly 4-8 words)
- Method doesn't mutate the receiver
- All methods on the type are read-only

## Detach Methods That Don't Use Receiver

```go
// AI SMELL: Method that doesn't use receiver state
func (a *Analyzer) findCacheDir(path string) (string, error) {
    // Never accesses 'a' - just uses the path argument
    indexDir := filepath.Join(path, "_cacache", "index-v5")
    if _, err := os.Stat(indexDir); err != nil {
        return "", err
    }
    return indexDir, nil
}

// RIGHT: Standalone function when receiver is unused
func findCacheDir(path string) (string, error) {
    indexDir := filepath.Join(path, "_cacache", "index-v5")
    if _, err := os.Stat(indexDir); err != nil {
        return "", err
    }
    return indexDir, nil
}
```

**Why**: Methods should only be methods when they need receiver state. A method that ignores its receiver is misleading.

## Consistency Within Types

```go
// WRONG: Mixed receiver types without good reason
type Config struct {
    Items []string
    Name  string
}

func (c Config) GetName() string { return c.Name }      // Value
func (c *Config) AddItem(item string) { c.Items = ... } // Pointer - OK
func (c Config) Validate() error { ... }                // Value
func (c *Config) Clone() Config { ... }                 // Pointer - WHY?

// RIGHT: Consistent receivers (pointer when any method mutates)
func (c *Config) GetName() string { return c.Name }
func (c *Config) AddItem(item string) { c.Items = append(c.Items, item) }
func (c *Config) Validate() error { ... }
func (c *Config) Clone() *Config {
    clone := *c
    clone.Items = make([]string, len(c.Items))
    copy(clone.Items, c.Items)
    return &clone
}
```

## Large Types: Always Pointer Receiver

```go
// WRONG: Value receiver on large struct
type BuildContext struct {
    Config      BuildConfig   // 200+ bytes
    Environment Environment   // 300+ bytes
    Dependencies []Dependency
}

func (ctx BuildContext) Validate() error {  // Copies entire struct!
    return nil
}

// RIGHT: Pointer receiver for large structs
func (ctx *BuildContext) Validate() error {
    return nil
}
```

## Interface Satisfaction

```go
// Be explicit about which type satisfies interface
type Counter struct {
    count int
}

func (c *Counter) Get() int { return c.count }
func (c *Counter) Increment() { c.count++ }

// Document interface satisfaction
var _ Getter = (*Counter)(nil)
var _ Incrementer = (*Counter)(nil)
```

## Review Checklist

- [ ] **[BLOCKER]** Pointer receivers when any method mutates
- [ ] **[MAJOR]** Consistent receiver type across all methods of a type
- [ ] **[MAJOR]** Methods that don't use receiver → standalone functions
- [ ] **[MINOR]** Value receivers for small (< 64 bytes), read-only types
- [ ] **[MINOR]** Pointer receivers for large structs (> 64 bytes)
- [ ] **[MINOR]** Interface satisfaction explicitly documented

## Related Documents

- `go-interfaces.md` - Interface satisfaction and design
- `go-performance.md` - Performance implications of receiver types
- `go-ai-antipatterns.md` - Over-engineered method patterns
