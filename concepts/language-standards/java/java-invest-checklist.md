# INVEST Checklist for Java Code Review

> Quick reference mnemonic for Java code review. Load focused files for deep patterns.

## Philosophy

Java is explicit, type-safe, and verbose by design. Embrace these qualities rather than fighting them. The best Java code is boring, predictable, and uses standard library patterns consistently.

**Core Principles:**
- Fail fast with meaningful errors
- Immutable by default
- Explicit over clever
- Standard library first
- Test what matters

---

## The INVEST Checklist

### **I**mmutability First
- [ ] Records for value objects (<5 fields)
- [ ] `@Value.Immutable` for complex objects
- [ ] `List.of()` / `Set.of()` for collections
- [ ] No setters unless truly needed
- [ ] Defensive copies when exposing collections

### **N**ull Safety
- [ ] `Objects.requireNonNull()` in constructors
- [ ] `Optional<T>` for return types only (not fields)
- [ ] `@Nullable` / `@NonNull` annotations
- [ ] Return empty collections, not null
- [ ] No null checks on @NonNull parameters

### **V**alidation Early
- [ ] Validate in constructor (fail fast)
- [ ] Static factory methods for validation logic
- [ ] Return validation result objects
- [ ] Don't use exceptions for expected invalidity
- [ ] Document preconditions in Javadoc

### **E**xceptions with Context
- [ ] Chain exceptions with `throw new Exception("context", cause)`
- [ ] Specific exception types (not `Exception`)
- [ ] Try-with-resources for `AutoCloseable`
- [ ] No empty catch blocks
- [ ] No catch-and-rethrow without adding context

### **S**tandard Library First
- [ ] Use `java.util.concurrent` over raw threads
- [ ] `Stream` API for transformations (not loops-as-streams)
- [ ] `String.join()` over manual concatenation
- [ ] `Collections.unmodifiableList()` when needed
- [ ] No reinventing existing utilities

### **T**esting Patterns
- [ ] Test behavior, not implementation
- [ ] Descriptive test names (`shouldDoXWhenY`)
- [ ] AssertJ for fluent assertions
- [ ] Mock interfaces, real objects for values
- [ ] Parameterized tests for multiple cases

---

## Pre-Commit Checklist

```
[ ] Run: mvn clean verify
[ ] Run: mvn dependency:analyze (check for unused)
[ ] Run: mvn spotless:check (or apply)
[ ] Check: No @SuppressWarnings without comment
[ ] Check: No TODOs in committed code
[ ] Check: All public methods have Javadoc
[ ] Check: Tests pass and coverage maintained
[ ] Check: No System.out.println (use logger)
```

---

## Focused Files

Load these for deep patterns:

| File | When to Load |
|------|--------------|
| `java-exceptions.md` | Exception handling, chaining |
| `java-optional.md` | Optional usage patterns |
| `java-immutability.md` | Records, defensive copies |
| `java-streams.md` | Stream API patterns |
| `java-nulls.md` | Null handling, @NonNull |
| `java-testing.md` | JUnit 5, AssertJ, mocking |
| `java-concurrency.md` | Virtual threads, structured concurrency |
| `java-ai-antipatterns.md` | AI code smells, performance |

---

## Summary: The Java Way

1. **Be explicit** - Java is verbose; embrace it
2. **Fail fast** - Validate early, throw descriptively
3. **Immutable by default** - Mutability must be justified
4. **Standard library first** - Don't reinvent
5. **Test what matters** - Behavior over implementation
6. **Chain exceptions** - Always preserve context
7. **Use types** - Optional, Stream, Records appropriately
8. **Trust annotations** - @NonNull means no null check needed

Remember: Boring Java is good Java. Predictable patterns > clever tricks.

---

## Review Protocol

When reviewing or writing Java code, follow this sequence:

```
1. INVEST Checklist Pass
   └─ Check all 6 boxes above

2. AI Anti-Pattern Scan
   └─ Load java-ai-antipatterns.md
   └─ Check Detection Signals table

3. Quick Reference Verification
   └─ Check relevant focused file tables

4. Confidence Check
   └─ Only flag issues for exact pattern matches
   └─ When uncertain, load the focused file for detail
```

### Load Order for Reviews

| Review Type | Load These Files |
|-------------|------------------|
| Quick scan | This checklist only |
| Exception code | + `java-exceptions.md` |
| Null handling | + `java-nulls.md`, `java-optional.md` |
| Collections/streams | + `java-streams.md`, `java-immutability.md` |
| Concurrent code | + `java-concurrency.md` |
| Full review | All files + `java-ai-antipatterns.md` |
