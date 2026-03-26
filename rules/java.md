---
globs: "*.java"
---

# Java Quality Rules (INVEST)

## Checklist

### I - Immutability First
- `[MAJOR]` Records for value objects (<5 fields); `@Value.Immutable` for complex objects
- `[MAJOR]` `List.of()` / `Set.of()` for collections; no setters unless justified

### N - Null Safety
- `[MAJOR]` `Objects.requireNonNull()` in constructors
- `[MAJOR]` `Optional<T>` for return types only (not fields/parameters)
- `[MINOR]` Return empty collections, not null

### V - Validation Early
- `[MAJOR]` Validate in constructor (fail fast)
- `[MAJOR]` Static factory methods for complex validation logic

### E - Exceptions with Context
- `[BLOCKER]` Chain exceptions: `throw new XException("context", cause)`
- `[BLOCKER]` No empty catch blocks
- `[MAJOR]` Specific exception types (not bare `Exception`)
- `[MAJOR]` Try-with-resources for `AutoCloseable`

### S - Standard Library First
- `[MAJOR]` `java.util.concurrent` over raw threads
- `[MAJOR]` Stream API for transformations; `String.join()` over manual concat
- `[MAJOR]` No reinventing existing utilities

### T - Testing Patterns
- `[MAJOR]` Test behavior, not implementation
- `[MAJOR]` AssertJ for assertions; `@ParameterizedTest` for multiple cases
- `[MINOR]` Descriptive names: `shouldDoXWhenY`

### Pre-Commit
- `[MAJOR]` `mvn clean verify` passes
- `[MAJOR]` `mvn dependency:analyze` — no unused deps
- `[MAJOR]` No `System.out.println` — use logger

## AI Detection Signals

| Signal | Severity | What to Look For |
|--------|----------|------------------|
| Null check on @NonNull | MAJOR | Redundant validation — trust annotation |
| `StringProcessor` interface | MAJOR | Over-engineering: just call `toUpperCase()` |
| `catch (E e) { throw e; }` | MAJOR | Pointless catch-rethrow |
| `catch (E e) { }` | BLOCKER | Silent failure — swallowed exception |
| `.toString()` in concat | MINOR | Redundant — automatic in string context |
| `+=` string in loop | MAJOR | O(n^2) — use `StringBuilder` or `String.join()` |
| `method(true, false, true)` | MAJOR | Boolean params — use builder/options object |
| `instanceof` then cast | MINOR | Use pattern matching (Java 16+) |
| `== "string"` | BLOCKER | Reference comparison — use `.equals()` |
| `Pattern.matches()` in loop | MAJOR | Compile once as `static final Pattern` |
| List search inside loop | MAJOR | O(n^2) — build `Map` first |
| Autoboxing in hot loop | MINOR | Use `IntStream` or primitive arrays |

## Top 3 Anti-Pattern Examples

### Over-engineering simple logic
```java
// BAD
interface StringProcessor { String process(String input); }
class UpperCaseProcessor implements StringProcessor {
    @Override public String process(String input) { return input.toUpperCase(); }
}

// GOOD
String result = input.toUpperCase();
```

### Silent exception swallowing
```java
// BAD
try { processData(data); }
catch (ProcessingException e) { /* TODO */ }

// GOOD
try { processData(data); }
catch (ProcessingException e) {
    log.error("Failed to process data for {}", data.getId(), e);
    throw new ServiceException("Data processing failed", e);
}
```

### O(n^2) loop with stream search
```java
// BAD
for (Order o : orders) {
    Customer c = customers.stream()
        .filter(x -> x.getId().equals(o.getCustomerId()))
        .findFirst().orElse(null);
}

// GOOD
Map<String, Customer> map = customers.stream()
    .collect(Collectors.toMap(Customer::getId, Function.identity()));
for (Order o : orders) { Customer c = map.get(o.getCustomerId()); }
```

## Deep Dives
See `~/.claude/skills/review-code/` (java-*.md files) for focused files on exceptions, optional, immutability, streams, nulls, testing, concurrency, and AI anti-patterns.
