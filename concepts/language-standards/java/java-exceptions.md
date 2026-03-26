# Java Exception Handling

> Chaining exceptions, try-with-resources, and proper exception types.
>
> **See also:** `java-optional.md` (when to return Optional vs throw), `java-ai-antipatterns.md` (catch-and-rethrow smell)

## Chain Exceptions with Context

```java
// ❌ Anti-Pattern: Swallowing Exceptions
try {
    service.processData(data);
} catch (Exception e) {
    log.error("Error processing data");
    // Exception lost! No context preserved
}

// ✅ Correct: Chain Exceptions with Context
try {
    service.processData(data);
} catch (DataValidationException e) {
    throw new ProcessingException(
        "Failed to process data for artifact " + artifactId, e);
} catch (IOException e) {
    throw new ProcessingException(
        "I/O error during data processing", e);
}
```

## Catch Specific Exceptions

```java
// ❌ Anti-Pattern: Generic Exception Catching
try {
    buildArtifact(artifact);
} catch (Exception e) {
    // Too broad! Catches RuntimeException, Error, etc.
    log.error("Build failed", e);
}

// ✅ Correct: Catch Specific Exceptions
try {
    buildArtifact(artifact);
} catch (BuildException e) {
    // Expected failure during build
    return BuildResult.failed(e.getMessage());
} catch (IOException e) {
    // Unexpected I/O issue
    throw new InfrastructureException("Build I/O failure", e);
}
// Let unchecked exceptions (NPE, IllegalState) propagate
```

## Don't Use Exceptions for Control Flow

```java
// ❌ Anti-Pattern: Exceptions for Logic
public Optional<User> findUser(String id) {
    try {
        return Optional.of(userRepository.getById(id));
    } catch (UserNotFoundException e) {
        return Optional.empty(); // Wrong! This hides real errors
    }
}

// ✅ Correct: Return Optional for Expected Absence
public Optional<User> findUser(String id) {
    // Let UserNotFoundException propagate if it's truly exceptional
    // Use Optional only when absence is expected
    User user = userRepository.findById(id); // returns null if not found
    return Optional.ofNullable(user);
}
```

## Try-With-Resources

```java
// ❌ Manual resource management
InputStream in = null;
try {
    in = new FileInputStream(file);
    processStream(in);
} finally {
    if (in != null) {
        in.close(); // Might throw, complicates error handling
    }
}

// ✅ Automatic resource management
try (InputStream in = new FileInputStream(file)) {
    processStream(in);
} // Automatically closed even if exception thrown
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `catch (Exception e) {}` | Swallows error | Chain with context |
| `catch (Exception e)` | Too broad | Catch specific types |
| `throw e` (same type) | Pointless | Let it propagate |
| Manual `close()` | Error-prone | Try-with-resources |
| Exception for control flow | Abuse | Return Optional |

---

## Exception Handling Decision Tree

```
Exception occurs in your code:
│
├─ Can you add meaningful context?
│   ├─ Yes → Chain: throw new XException("context: " + detail, e)
│   └─ No → Let it propagate (don't catch-and-rethrow same type)
│
├─ Is this a recoverable error?
│   ├─ Yes (caller can handle) → Checked exception or return type
│   └─ No (programming error) → Unchecked RuntimeException
│
├─ Should caller distinguish error types?
│   ├─ Yes → Create specific exception class
│   └─ No → Use existing exception with good message
│
└─ Is absence expected (not exceptional)?
    ├─ Yes → Return Optional<T>
    └─ No → Throw exception

Catching exceptions:
│
├─ Can you recover?
│   ├─ Yes → Handle and continue
│   └─ No → Chain and rethrow with context
│
├─ Need to clean up resources?
│   └─ Always use try-with-resources for AutoCloseable
│
└─ Multiple exception types?
    └─ Use multi-catch: catch (IOException | SQLException e)
```

### When to Use What

| Situation | Approach |
|-----------|----------|
| User not found (expected) | Return `Optional.empty()` |
| User not found (unexpected) | Throw `NotFoundException` |
| Invalid input from user | Throw specific validation exception |
| Programming bug (null where unexpected) | Let NullPointerException propagate |
| I/O failure | Chain with context, throw infrastructure exception |
| Third-party API failure | Wrap in domain exception with context |
