# Java Immutability Patterns

> Records, defensive copies, and immutable collections.
>
> **See also:** `java-nulls.md` (requireNonNull in constructors), `java-streams.md` (collectors for immutable results)

## Use Records for Value Objects

```java
// ❌ Anti-Pattern: Mutable Value Objects
public class BuildResult {
    private String artifactId;
    private boolean success;
    private List<String> errors;

    // AI generates setters for everything
    public void setArtifactId(String artifactId) {
        this.artifactId = artifactId;
    }

    public List<String> getErrors() {
        return errors; // Mutable list exposed!
    }
}

// ✅ Correct: Immutable with Records (Java 16+)
public record BuildResult(
    String artifactId,
    boolean success,
    List<String> errors // Defensive copy in constructor
) {
    public BuildResult {
        errors = List.copyOf(errors); // Immutable copy
        Objects.requireNonNull(artifactId, "artifactId cannot be null");
    }

    public static BuildResult success(String artifactId) {
        return new BuildResult(artifactId, true, List.of());
    }

    public static BuildResult failure(String artifactId, String... errors) {
        return new BuildResult(artifactId, false, List.of(errors));
    }
}
```

## Immutables Library Alternative

```java
@Value.Immutable
@JsonDeserialize(as = ImmutableBuildResult.class)
public interface BuildResult {
    String artifactId();
    boolean success();
    List<String> errors();

    static ImmutableBuildResult.Builder builder() {
        return ImmutableBuildResult.builder();
    }

    static BuildResult success(String artifactId) {
        return builder()
            .artifactId(artifactId)
            .success(true)
            .build();
    }
}
```

## Don't Expose Mutable Collections

```java
// ❌ Anti-Pattern: Exposing Mutable Collections
private final List<String> items = new ArrayList<>();

public List<String> getItems() {
    return items; // Caller can modify!
}

// ✅ Correct: Return Unmodifiable Views
private final List<String> items = new ArrayList<>();

public List<String> getItems() {
    return Collections.unmodifiableList(items);
}

// Or better: copy to immutable collection
public List<String> getItems() {
    return List.copyOf(items);
}
```

## Collection Factories

```java
// ❌ Anti-Pattern: Wrong Collection Type
List<String> tags = new ArrayList<>(Arrays.asList("java", "build"));
tags.add("test"); // Oops, modified

// Arrays.asList has surprising mutability
List<String> items = Arrays.asList("a", "b");
items.set(0, "c"); // Works!
items.add("d"); // UnsupportedOperationException!

// ✅ Correct: Use Appropriate Factory
// Truly immutable (Java 9+)
List<String> tags = List.of("java", "build");
Set<String> keys = Set.of("id", "name", "version");
Map<String, String> config = Map.of("key", "value");

// Empty immutable
List<String> empty = List.of();

// From existing collection (defensive copy)
List<String> copy = List.copyOf(existingList);

// Mutable when needed
List<String> mutable = new ArrayList<>(List.of("a", "b"));
```

## Decision Tree

```
Need to modify?
  ├─ Yes → new ArrayList<>() / new HashMap<>()
  └─ No → List.of() / Set.of() / Map.of()

Have existing collection?
  ├─ Need defensive copy → List.copyOf(existing)
  └─ Just iterate → use as-is
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `setX()` everywhere | Mutable | Use records or immutables |
| `getList()` returns field | Caller can modify | `List.copyOf()` or unmodifiable |
| `Arrays.asList()` | Partial mutability | `List.of()` |
| Empty collection creation | Wasteful | `List.of()` |
| No constructor validation | Invalid state | Compact constructor in record |
