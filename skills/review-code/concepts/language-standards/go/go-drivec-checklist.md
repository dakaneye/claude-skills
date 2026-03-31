# Go DRIVEC Checklist

> Quick reference mnemonic for Go code review. Load this for fast quality checks.

## The DRIVEC Mnemonic

- **D**RY: Method layering, no duplication, compose functions
- **R**eceivers: Value vs pointer patterns, consistency within types
- **I**nterfaces: Small interfaces (1-3 methods), accept interfaces, return structs
- **V**alidation: Complete validation or documented absence, no partial checks
- **E**rrors: Static errors with errors.New, proper chaining, no "failed to" prefix
- **C**ontext: First parameter always, respect cancellation, never stored in structs

## Core Philosophy

- **Rob Pike**: "Clear is better than clever"
- **Dave Cheney**: "Errors are values, handle them explicitly"
- **Mitchell Hashimoto**: Production code must work at 3am when you're paged

## Quick Checks

### D - DRY
- [ ] **[MAJOR]** Methods layer on each other (no duplicated branch logic)
- [ ] **[MAJOR]** No copy-paste code with minor variations
- [ ] **[MINOR]** String building uses strings.Builder in loops

### R - Receivers
- [ ] **[BLOCKER]** Pointer receivers when any method mutates
- [ ] **[MAJOR]** Consistent receiver type across all methods
- [ ] **[MAJOR]** Methods that don't use receiver → standalone functions
- [ ] **[MINOR]** Value receivers for small, read-only types (< 64 bytes)

### I - Interfaces
- [ ] **[BLOCKER]** Accept interfaces, return structs
- [ ] **[BLOCKER]** No interface{}/any when generics work
- [ ] **[MAJOR]** 1-3 methods maximum
- [ ] **[MAJOR]** Defined near consumer, not implementation

### V - Validation
- [ ] **[MAJOR]** Complete or explicitly absent (no partial)
- [ ] **[MINOR]** No redundant overlapping safety checks
- [ ] **[MINOR]** Validate once at boundaries, trust internally
- [ ] **[MINOR]** Zero values are useful or require construction

### E - Errors
- [ ] **[BLOCKER]** `fmt.Errorf` with `%w` for wrapping (not `%s` or `%v`)
- [ ] **[MAJOR]** `errors.New` for static strings
- [ ] **[MAJOR]** Custom error types have inspectable fields
- [ ] **[MINOR]** No "failed to" prefix (state action directly)

### C - Context
- [ ] **[BLOCKER]** First parameter always
- [ ] **[BLOCKER]** Not stored in structs
- [ ] **[BLOCKER]** Propagated to goroutines
- [ ] **[MAJOR]** Cancellation respected in long operations

## Additional Quick Checks

### Concurrency
- [ ] **[BLOCKER]** Goroutines have shutdown mechanism
- [ ] **[BLOCKER]** Channels closed by sender
- [ ] **[MAJOR]** Bounded concurrency for parallel work
- [ ] **[MINOR]** Loop variables captured (pre-Go 1.22)

### Testing
- [ ] **[BLOCKER]** Error cases tested explicitly
- [ ] **[MAJOR]** Use t.Context() not context.Background() (Go 1.24+)
- [ ] **[MAJOR]** Table-driven with compact format
- [ ] **[MINOR]** Error messages: `field: got = %v, want = %v`

### AI Code Detection
- [ ] **[BLOCKER]** No factory patterns for single implementations
- [ ] **[BLOCKER]** No channels wrapping synchronous operations
- [ ] **[MAJOR]** No excessive configuration (10+ fields)
- [ ] **[MAJOR]** No generics where concrete types work

## Related Standards

For detailed patterns and examples, see:
- `go-review-system.md` - How to use these documents together
- `go-errors.md` - Error handling patterns
- `go-receivers.md` - Receiver type patterns
- `go-interfaces.md` - Interface design
- `go-context.md` - Context patterns
- `go-concurrency.md` - Basic concurrency patterns
- `go-concurrency-patterns.md` - Advanced concurrency patterns
- `go-testing.md` - Testing patterns
- `go-performance.md` - Performance anti-patterns
- `go-ai-antipatterns.md` - AI-generated code smells
