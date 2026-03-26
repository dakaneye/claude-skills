# Go Testing Patterns

> Idiomatic Go testing patterns. Load when reviewing test code.

## Activation Triggers

Load this document when:
- Reviewing `*_test.go` files
- Writing or reviewing test functions (`func Test*`)
- Checking test coverage or test quality
- File imports `testing` package

## Use t.Context() in Tests (Go 1.24+)

```go
// WRONG: Using context.Background() in tests
func TestFetch(t *testing.T) {
    ctx := context.Background()  // Don't use this in tests
    result, err := client.Fetch(ctx, "example")
    // ...
}

// RIGHT: Use t.Context() for automatic cancellation on test failure
func TestFetch(t *testing.T) {
    ctx := t.Context()  // Cancelled when test ends/fails
    result, err := client.Fetch(ctx, "example")
    // ...
}
```

**Why**: `t.Context()` is automatically cancelled when the test completes or fails, ensuring proper cleanup.

## Table-Driven Tests

```go
// WRONG: Repetitive individual tests
func TestAdd1Plus1(t *testing.T) {
    if Add(1, 1) != 2 {
        t.Error("1 + 1 should equal 2")
    }
}

// RIGHT: Table-driven tests with compact format
func TestAdd(t *testing.T) {
    tests := []struct {
        name string
        a, b int
        want int
    }{{
        name: "positive",
        a: 1, b: 1,
        want: 2,
    }, {
        name: "negative",
        a: -1, b: -1,
        want: -2,
    }, {
        name: "mixed",
        a: -1, b: 1,
        want: 0,
    }}

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.want {
                t.Errorf("Add(%d, %d): got = %d, want = %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

**Compact format rules:**
- Opening: `}{{` (closes struct definition, opens first element)
- Between elements: `}, {` (closes element, opens next)
- Closing: `}}` (closes last element and slice)

## Error Message Format: got/want Pattern

```go
// WRONG: Various inconsistent formats
t.Errorf("Package.Name = %q, want %q", got, want)
t.Errorf("expected %q but got %q", want, got)

// RIGHT: Consistent got = / want = pattern
t.Errorf("Package.Name: got = %q, want = %q", got, want)
t.Errorf("Add(%d, %d): got = %d, want = %d", a, b, got, want)
```

**Pattern**: `field/operation: got = %v, want = %v`

## Test Helpers

```go
// WRONG: Duplicated setup in each test
func TestProcessA(t *testing.T) {
    tempDir, err := os.MkdirTemp("", "test")
    if err != nil {
        t.Fatal(err)
    }
    defer os.RemoveAll(tempDir)
    // Test code...
}

// RIGHT: Use t.TempDir() and test helpers
func TestProcessA(t *testing.T) {
    tempDir := t.TempDir()  // Automatic cleanup
    // Test code...
}

// For complex setup, create helper
func setupTestDB(t *testing.T) *TestDB {
    t.Helper()  // Marks as helper for better error reporting

    db, err := NewTestDB()
    if err != nil {
        t.Fatalf("setup database: %v", err)
    }

    t.Cleanup(func() {
        if err := db.Close(); err != nil {
            t.Errorf("close database: %v", err)
        }
    })

    return db
}
```

## Testing Error Conditions

```go
// WRONG: Only testing happy path
func TestParseConfig(t *testing.T) {
    cfg, err := ParseConfig("testdata/valid.yaml")
    if err != nil {
        t.Fatal(err)
    }
    // Only happy path tested
}

// RIGHT: Test error cases explicitly
func TestParseConfig(t *testing.T) {
    t.Run("valid config", func(t *testing.T) {
        cfg, err := ParseConfig("testdata/valid.yaml")
        if err != nil {
            t.Fatalf("unexpected error: %v", err)
        }
        if cfg.Name != "test" {
            t.Errorf("Name: got = %q, want = %q", cfg.Name, "test")
        }
    })

    t.Run("missing file", func(t *testing.T) {
        _, err := ParseConfig("testdata/nonexistent.yaml")
        if err == nil {
            t.Fatal("expected error for missing file")
        }
        if !errors.Is(err, os.ErrNotExist) {
            t.Errorf("error: got = %v, want = os.ErrNotExist", err)
        }
    })

    t.Run("invalid yaml", func(t *testing.T) {
        _, err := ParseConfig("testdata/invalid.yaml")
        if err == nil {
            t.Fatal("expected error for invalid yaml")
        }
        var syntaxErr *yaml.SyntaxError
        if !errors.As(err, &syntaxErr) {
            t.Errorf("error type: got = %T, want = *yaml.SyntaxError", err)
        }
    })
}
```

## Test Function Naming

```go
// WRONG: Test function names must start with uppercase after "Test"
func TestnpmCacheEntry(t *testing.T) { }  // COMPILE ERROR

// RIGHT: Test function names follow TestXxx pattern
func TestNpmCacheEntry(t *testing.T) { }   // Tests npmCacheEntry type
func TestIsNpmCache(t *testing.T) { }      // Tests isNpmCache function

// Subtests can have any case
func TestNpmCacheEntry(t *testing.T) {
    t.Run("coordinates", func(t *testing.T) { })  // lowercase OK
    t.Run("with scope", func(t *testing.T) { })   // spaces OK
}
```

**CAUTION**: When unexporting symbols (e.g., `NpmCacheEntry` → `npmCacheEntry`), don't accidentally rename `TestNpmCacheEntry` to `TestnpmCacheEntry`.

## Review Checklist

- [ ] **[BLOCKER]** Error cases tested explicitly
- [ ] **[BLOCKER]** Test function names remain TestXxx after refactoring
- [ ] **[MAJOR]** Use t.Context() instead of context.Background() (Go 1.24+)
- [ ] **[MAJOR]** Table-driven tests for multiple cases
- [ ] **[MAJOR]** Test helpers use t.Helper()
- [ ] **[MINOR]** Compact format: `}{{`, `}, {`, `}}`
- [ ] **[MINOR]** Error messages: `field: got = %v, want = %v`
- [ ] **[MINOR]** Edge cases from comments are tested

## Related Documents

- `go-errors.md` - Testing error conditions with errors.Is/errors.As
- `go-context.md` - Context in tests
- `go-concurrency.md` - Testing concurrent code with -race flag
