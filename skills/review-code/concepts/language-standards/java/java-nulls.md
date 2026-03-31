# Java Null Handling

> Objects.requireNonNull, @Nullable annotations, and var usage.
>
> **See also:** `java-optional.md` (Optional for return types), `java-ai-antipatterns.md` (redundant null checks)

## Fail Fast with requireNonNull

```java
// ❌ Anti-Pattern: Defensive Null Checks Everywhere
public void processArtifact(Artifact artifact) {
    if (artifact == null) {
        throw new IllegalArgumentException("artifact cannot be null");
    }
    if (artifact.getId() == null) {
        throw new IllegalArgumentException("artifact id cannot be null");
    }
    // ... more null checks ...
}

// ✅ Correct: Fail Fast with Objects.requireNonNull
public void processArtifact(Artifact artifact) {
    Objects.requireNonNull(artifact, "artifact cannot be null");
    Objects.requireNonNull(artifact.getId(), "artifact.id cannot be null");

    // Continue with business logic
    // No need to check again - we've established invariants
}

// Better: Use in constructor
public class ArtifactProcessor {
    private final ArtifactRepository repository;
    private final ValidationService validator;

    public ArtifactProcessor(ArtifactRepository repository,
                            ValidationService validator) {
        this.repository = Objects.requireNonNull(repository);
        this.validator = Objects.requireNonNull(validator);
    }
}
```

## Use Nullability Annotations

```java
import org.checkerframework.checker.nullness.qual.Nullable;
import org.checkerframework.checker.nullness.qual.NonNull;

public class UserService {
    // Explicit: this might return null
    public @Nullable User findById(String id) {
        return repository.findById(id);
    }

    // Explicit: this never returns null
    public @NonNull List<User> findAll() {
        return repository.findAll();
    }
}
```

## Trust @NonNull Annotations

```java
// ❌ AI often generates this
public void process(@NonNull String input) {
    if (input == null) {
        throw new IllegalArgumentException("input cannot be null");
    }
    // ...
}

// ✅ Trust the annotation
public void process(@NonNull String input) {
    // No check needed - annotation enforces contract
}
```

## var Keyword Usage

### Good Uses of var

```java
// Obvious types from right side
var list = new ArrayList<String>();
var builder = ImmutableBuildResult.builder();
var response = httpClient.send(request);

// Iterator in loops
for (var entry : map.entrySet()) {
    process(entry.getKey(), entry.getValue());
}

// Try-with-resources
try (var reader = Files.newBufferedReader(path)) {
    return reader.lines().collect(Collectors.toList());
}
```

### When var Obscures Type

```java
// ❌ What type is this?
var result = processData(input);

// ❌ What's in this map?
var cache = new HashMap<>();

// ❌ Primitive wrapper or primitive?
var count = getCount();

// ✅ Correct: Explicit When Type Matters
Map<String, BuildResult> cache = new HashMap<>();
int count = getCount();
Optional<String> result = processData(input);
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `if (x == null) throw` | Verbose | `Objects.requireNonNull()` |
| Null check on @NonNull param | Redundant | Trust the annotation |
| No annotations | Ambiguous | Add `@Nullable`/`@NonNull` |
| `var result = method()` | Unclear type | Explicit type when not obvious |
| Return null for collection | Confusing | Return `List.of()` |
