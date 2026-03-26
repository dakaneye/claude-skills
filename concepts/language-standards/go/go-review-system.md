# Go Code Review System

> How to use the Go language standards documents together for effective code review.

## Document Hierarchy

```
                    go-drivec-checklist.md
                         (Always Load)
                              |
    +----------+-------+------+------+-------+----------+
    |          |       |      |      |       |          |
 errors   receivers  interfaces context concurrency  testing
    |                              |         |
    +------------------------------+---------+
                         |
              concurrency-patterns
                         |
                    performance
                         |
                   ai-antipatterns
```

## Loading Strategy

### Phase 1: Initial Scan (Always)
**Load**: `go-drivec-checklist.md`

Quick DRIVEC scan of entire PR/file:
- **D**RY: Method layering, no duplication
- **R**eceivers: Value vs pointer patterns
- **I**nterfaces: Small, consumer-defined
- **V**alidation: Complete or explicitly absent
- **E**rrors: Static errors, proper chaining
- **C**ontext: First parameter, cancellation respect

### Phase 2: Pattern Detection (Conditional)

Load detailed documents based on patterns detected:

| Pattern Detected | Load Document |
|------------------|---------------|
| Multiple `if err != nil` | `go-errors.md` |
| Struct methods (`func (r *Type)`) | `go-receivers.md` |
| `type X interface` definitions | `go-interfaces.md` |
| `context.Context` parameters | `go-context.md` |
| `go func()`, channels, `sync.*` | `go-concurrency.md` |
| `*_test.go` files | `go-testing.md` |
| Hot paths, large loops | `go-performance.md` |
| AI-generated code suspected | `go-ai-antipatterns.md` |

### Phase 3: Advanced Patterns (When Needed)

| Trigger | Load Document |
|---------|---------------|
| Fan-out/fan-in, worker pools | `go-concurrency-patterns.md` |
| `sync.Mutex`, `sync.RWMutex`, `sync.Pool` | `go-concurrency-patterns.md` |
| Bounded concurrency with semaphores | `go-concurrency-patterns.md` |

## Severity Levels

All checklists use severity indicators:

| Level | Meaning | Action |
|-------|---------|--------|
| **[BLOCKER]** | Breaks correctness, security, or causes data races | Must fix before merge |
| **[MAJOR]** | Violates idioms, causes maintenance issues | Should fix unless justified |
| **[MINOR]** | Style preference, micro-optimization | Nice to have |

## Co-Loading Rules

Some documents should load together:

| Primary | Co-load |
|---------|---------|
| `go-context.md` | `go-concurrency.md` |
| `go-concurrency.md` | `go-context.md` |
| `go-concurrency-patterns.md` | `go-concurrency.md`, `go-context.md` |
| `go-interfaces.md` | `go-receivers.md` |
| `go-performance.md` | `go-ai-antipatterns.md` |

## Review Workflow

### 1. Quick Scan
```
Load: go-drivec-checklist.md
Action: Scan entire diff using DRIVEC mnemonic
Output: List of areas needing detailed review
```

### 2. Deep Dive
```
For each area identified:
  1. Load relevant detailed document(s)
  2. Apply checklist items
  3. Mark severity of each finding
```

### 3. AI Code Detection
```
If code seems:
  - Over-engineered for its purpose
  - Has factory patterns for single implementations
  - Uses channels for synchronous operations
  - Has excessive configuration

Then: Load go-ai-antipatterns.md
```

### 4. Report Format
```markdown
## Go Review Findings

### [BLOCKER]
- go-context.md: Context stored in struct (line 45)
- go-concurrency.md: Fire-and-forget goroutine (line 78)

### [MAJOR]
- go-errors.md: Using fmt.Errorf for static string (line 23)
- go-interfaces.md: 8-method interface (line 100)

### [MINOR]
- go-performance.md: Slice not pre-allocated (line 55)
```

## Document Index

| Document | Focus | Load When |
|----------|-------|-----------|
| `go-drivec-checklist.md` | Quick reference | Always |
| `go-errors.md` | Error handling | Error patterns detected |
| `go-receivers.md` | Method receivers | Struct methods reviewed |
| `go-interfaces.md` | Interface design | Interface definitions found |
| `go-context.md` | Context patterns | context.Context used |
| `go-concurrency.md` | Basic concurrency | Goroutines, channels found |
| `go-concurrency-patterns.md` | Advanced concurrency | Fan-out, sync primitives |
| `go-testing.md` | Test patterns | Test files reviewed |
| `go-performance.md` | Performance | Hot paths, loops |
| `go-ai-antipatterns.md` | AI code smells | AI code suspected |

## Quick Reference: Severity by Document

### Blockers (Must Fix)
- **errors**: Using `%s` instead of `%w` for error wrapping
- **context**: Context stored in struct, not propagated to goroutines
- **concurrency**: Fire-and-forget goroutines, data races
- **interfaces**: Returning interfaces, using `any` when generics work
- **performance**: O(n²) in hot paths, defer in hot loops
- **ai-antipatterns**: Factory for single implementation, channels for sync ops

### Major (Should Fix)
- **errors**: Static strings with `fmt.Errorf`, missing `%w`
- **receivers**: Inconsistent receiver types, methods ignoring receiver
- **interfaces**: God interfaces, interface in implementation package
- **context**: No cancellation check in long operations
- **testing**: No error case testing

### Minor (Nice to Have)
- **errors**: "failed to" prefix
- **receivers**: Value receiver on 60-byte struct (near threshold)
- **testing**: Compact format not used
- **performance**: Slice not pre-allocated for known size
