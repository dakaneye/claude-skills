# Go Error Handling Patterns

> Detailed patterns for idiomatic Go error handling. Load when reviewing error-heavy code.

## Activation Triggers

Load this document when:
- File contains multiple `if err != nil` blocks
- Code uses `errors.New`, `fmt.Errorf`, or custom error types
- File imports `errors` package
- Reviewing error wrapping or sentinel error patterns

## Static Errors: errors.New vs fmt.Errorf

```go
// WRONG: fmt.Errorf for static strings
return nil, fmt.Errorf("package.json not found in npm tarball")

// RIGHT: errors.New for static strings
var ErrPackageJSONNotFound = errors.New("package.json not found in npm tarball")

// Sentinel errors enable caller inspection
if errors.Is(err, ErrPackageJSONNotFound) {
    // handle specifically
}
```

**Why**: `errors.New` allocates once at package init time. `fmt.Errorf` with static strings allocates on every call.

## Error Message Style (Dave Cheney Style)

```go
// AI SMELL: "failed to" prefix (Java energy)
return fmt.Errorf("failed to open npm tarball: %w", err)

// RIGHT: State the action directly
return fmt.Errorf("open npm tarball: %w", err)
```

**Why**: Error chains read naturally when unwrapped: "open npm tarball: open /path/to/file: permission denied"

## Error Wrapping with Context

```go
// WRONG: Naked error return loses context
func ProcessFile(path string) error {
    data, err := os.ReadFile(path)
    if err != nil {
        return err  // Which file? What operation?
    }
    return parse(data)
}

// WRONG: Wrapping without %w breaks Is/As
return fmt.Errorf("read %s: %s", path, err)  // Original error lost

// RIGHT: Wrap with %w and context
return fmt.Errorf("read %s: %w", path, err)  // Preserves error chain
```

## Custom Error Types

```go
// WRONG: Error type without useful fields
type ValidationError struct {
    message string
}

// RIGHT: Error type with inspectable fields
type ValidationError struct {
    Field   string
    Value   any
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation error: %s: %s (got %v)", e.Field, e.Message, e.Value)
}

// Usage: Caller can inspect
var validErr *ValidationError
if errors.As(err, &validErr) {
    log.Printf("Invalid field %s", validErr.Field)
}
```

## Don't Panic for Recoverable Errors

```go
// WRONG: Panic for expected error conditions
func ParseConfig(path string) Config {
    data, err := os.ReadFile(path)
    if err != nil {
        panic(err)  // Recoverable! Return error instead
    }
}

// RIGHT: Return errors for recoverable conditions
func ParseConfig(path string) (Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return Config{}, fmt.Errorf("read config: %w", err)
    }
    // ...
}

// Panic ONLY for truly unrecoverable programmer errors
func mustCompileRegex(pattern string) *regexp.Regexp {
    re, err := regexp.Compile(pattern)
    if err != nil {
        panic(fmt.Sprintf("invalid regex %q: %v", pattern, err))
    }
    return re
}

var emailRegex = mustCompileRegex(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
```

## Review Checklist

- [ ] **[BLOCKER]** Dynamic errors use `fmt.Errorf` with `%w` verb (not `%s` or `%v`)
- [ ] **[BLOCKER]** Panics only for unrecoverable programmer errors
- [ ] **[MAJOR]** Static error strings use `errors.New`, not `fmt.Errorf`
- [ ] **[MAJOR]** `errors.Is()` and `errors.As()` work as expected
- [ ] **[MAJOR]** Custom error types have inspectable fields
- [ ] **[MINOR]** No "failed to" prefix in error messages

## Related Documents

- `go-context.md` - Context cancellation errors
- `go-testing.md` - Testing error conditions
- `go-ai-antipatterns.md` - Verbose error handling patterns
