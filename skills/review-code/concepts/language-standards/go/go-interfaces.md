# Go Interface Design Patterns

> Small, consumer-defined interfaces. Load when reviewing API design.

## Activation Triggers

Load this document when:
- Reviewing interface definitions (`type X interface`)
- Code has `interface{}` or `any` type assertions
- Reviewing function signatures that accept or return interfaces
- Assessing API surface design

## Accept Interfaces, Return Structs (Rob Pike Pattern)

```go
// AI SMELL: Accept concrete types, return interfaces
func NewValidator(repo *PostgresRepository) Validator {
    return &validator{repo: repo}  // Returns interface - hides implementation
}

// RIGHT: Accept interfaces, return structs
func NewValidator(repo Repository) *Validator {
    return &Validator{repo: repo}  // Returns concrete type
}

// Callers depend on minimal behavior
type Repository interface {
    Get(ctx context.Context, id string) ([]byte, error)
}
```

**Why**: Returning concrete types allows callers to see exactly what they're getting, access all methods without type assertions, and benefit from compiler optimizations.

## Keep Interfaces Small (1-3 Methods)

```go
// AI SMELL: God interface (Java inheritance thinking)
type Storage interface {
    Get(key string) ([]byte, error)
    Set(key string, value []byte) error
    Delete(key string) error
    List(prefix string) ([]string, error)
    Watch(prefix string) (<-chan Event, error)
    Backup(path string) error
    Restore(path string) error
    Stats() StorageStats
    Close() error
}

// RIGHT: Small, focused interfaces
type Reader interface {
    Get(ctx context.Context, key string) ([]byte, error)
}

type Writer interface {
    Set(ctx context.Context, key string, value []byte) error
}

type Deleter interface {
    Delete(ctx context.Context, key string) error
}

// Compose when needed
type ReadWriter interface {
    Reader
    Writer
}

type Store interface {
    Reader
    Writer
    Deleter
    io.Closer
}
```

## Interface Location: Define Near Consumer

```go
// AI SMELL: Interface defined in implementation package
// package storage
type Storage interface {
    Get(key string) ([]byte, error)
    Set(key string, value []byte) error
}

// RIGHT: Interface defined where it's used (consumer package)
// package service
type DataStore interface {  // Only methods this package needs
    Get(key string) ([]byte, error)
}

type Service struct {
    store DataStore  // Depends on interface
}

// package storage - no interface, just implementation
type FileStorage struct { ... }
func (f *FileStorage) Get(key string) ([]byte, error) { ... }
```

## Avoid interface{}/any (Use Generics Instead)

```go
// AI SMELL: Using interface{}/any for generic code
func Contains(slice []interface{}, item interface{}) bool {
    for _, v := range slice {
        if v == item {
            return true
        }
    }
    return false
}

// RIGHT: Use generics (Go 1.18+)
func Contains[T comparable](slice []T, item T) bool {
    for _, v := range slice {
        if v == item {
            return true
        }
    }
    return false
}

// AI SMELL: Map with any values
cache := make(map[string]any)
cache["count"] = 42
count := cache["count"].(int)  // Runtime panic if wrong type

// RIGHT: Generic cache
type Cache[V any] struct {
    data map[string]V
    mu   sync.RWMutex
}

func (c *Cache[V]) Get(key string) (V, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    v, ok := c.data[key]
    return v, ok
}
```

## Embedding for Composition

```go
// AI SMELL: Inheritance-style thinking
type Dog struct {
    Animal  // Embedding for "inheritance"
}

func (d *Dog) Speak() string {
    return "Woof"  // "Override" - not Go idiomatic
}

// RIGHT: Composition and interfaces
type Speaker interface {
    Speak() string
}

type Dog struct {
    Name string
}

func (d *Dog) Speak() string {
    return "Woof"
}

// Embed for implementation reuse, not for polymorphism
type Server struct {
    http.Server  // Embed for all Server methods
    logger *slog.Logger
}
```

## Visibility: Private by Default

Make types, functions, and variables private (lowercase) unless they need to be part of the public API. Only expose what external consumers actually need.

```go
// WRONG: Exported but only used within package
type PnpmStoreEntry struct {  // Exported but no external package uses it
    Package NpmPackageInfo
}

func IsPnpmStore(path string) bool {  // Exported but only called internally
    // ...
}

// RIGHT: Private when only used internally
type pnpmStoreEntry struct {  // Lowercase - package-private
    Package NpmPackageInfo
}

func isPnpmStore(path string) bool {  // Lowercase - package-private
    // ...
}

// Test function naming for private functions
func Test_isPnpmStore(t *testing.T) {  // Use underscore after Test
    // Tests for private functions use Test_ prefix
}
```

**Why**: Minimizing the public API surface reduces maintenance burden, makes refactoring easier, and prevents unintended dependencies. If something is exported, you're committing to support it.

**Detection**: Search for exported identifiers and verify they're used outside the package:
```bash
# Find exported types/funcs and check if any external package imports them
grep -r "TypeName" --include="*.go" | grep -v "_test.go"
```

## Review Checklist

- [ ] **[BLOCKER]** Functions accept interfaces, return concrete types
- [ ] **[BLOCKER]** No interface{}/any when generics work
- [ ] **[MAJOR]** Interfaces have 1-3 methods maximum
- [ ] **[MAJOR]** Interfaces defined near consumer, not implementation
- [ ] **[MAJOR]** Types/functions private unless external packages need them
- [ ] **[MINOR]** Interface composition over large interfaces
- [ ] **[MINOR]** Embedding for reuse, not polymorphism
- [ ] **[MINOR]** Test functions for private funcs use `Test_` prefix

## Related Documents

- `go-receivers.md` - Interface satisfaction with pointer vs value receivers
- `go-ai-antipatterns.md` - Unnecessary interface patterns
- `go-testing.md` - Testing private functions
