# Java Optional Usage

> Proper Optional patterns for return types, not fields.
>
> **See also:** `java-nulls.md` (null handling), `java-exceptions.md` (when to throw vs return Optional)

## Don't Use Optional.get() Without Check

```java
// ❌ Anti-Pattern: Runtime bomb
Optional<String> result = findResult(id);
return result.get(); // Throws NoSuchElementException if empty!

// ✅ Correct: Provide default
return findResult(id).orElse("default");

// ✅ Correct: Throw descriptive exception
return findResult(id)
    .orElseThrow(() -> new NotFoundException("Result not found: " + id));

// ✅ Correct: Chain operations
return findResult(id)
    .map(String::toUpperCase)
    .filter(s -> s.length() > 5)
    .orElse(null);
```

## Optional Only for Return Types

```java
// ❌ Anti-Pattern: Optional for Fields
public class User {
    private Optional<String> middleName; // Wrong!

    public Optional<String> getMiddleName() {
        return middleName;
    }
}

// ✅ Correct: Optional Only for Return Types
public class User {
    private String middleName; // Can be null

    public Optional<String> getMiddleName() {
        return Optional.ofNullable(middleName);
    }
}
```

## Don't Wrap Collections

```java
// ❌ Anti-Pattern: Optional of Collection
// Redundant - empty collection already signals absence
public Optional<List<String>> getTags() {
    return Optional.of(tags);
}

// ✅ Correct: Return Empty Collection
public List<String> getTags() {
    return tags != null ? tags : List.of();
}
```

## Efficient Optional Usage

```java
// ❌ WRONG: isPresent + get
if (optional.isPresent()) {
    return optional.get();
}
return defaultValue;

// ✅ RIGHT: orElse
return optional.orElse(defaultValue);

// ❌ WRONG: Creating Optional just to use orElse
return Optional.ofNullable(getValue()).orElse(defaultValue);

// ✅ RIGHT: Ternary for simple null checks
var value = getValue();
return value != null ? value : defaultValue;
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `optional.get()` | Runtime exception | Use `orElse()` or `orElseThrow()` |
| `Optional<String> field` | Not for fields | Field `String`, return `Optional` |
| `Optional<List<T>>` | Redundant | Return `List.of()` |
| `isPresent() + get()` | Verbose | Use `orElse()` |
| `Optional.ofNullable(x).orElse(y)` | Overkill | `x != null ? x : y` |
