# Java Stream API Patterns

> When to use streams, collectors, and handling checked exceptions.
>
> **See also:** `java-immutability.md` (immutable collectors), `java-exceptions.md` (checked exceptions in lambdas)

## Don't Overuse Streams

```java
// ❌ More complex than imperative code
List<String> result = list.stream()
    .filter(Objects::nonNull)
    .collect(Collectors.toList());

// Simple loop is clearer here
List<String> result = new ArrayList<>();
for (String item : list) {
    if (item != null) {
        result.add(item);
    }
}

// ✅ Good use: multiple operations with readability
Map<String, List<Artifact>> grouped = artifacts.stream()
    .filter(a -> a.getVersion() != null)
    .filter(a -> !a.isSnapshot())
    .collect(Collectors.groupingBy(Artifact::getGroupId));
```

## Don't Use Side Effects in Streams

```java
// ❌ Anti-Pattern: Side Effects in Streams
List<String> processed = new ArrayList<>();
artifacts.stream()
    .map(Artifact::getId)
    .forEach(id -> processed.add(id)); // Side effect!

// ✅ Correct: Use Collectors
List<String> processed = artifacts.stream()
    .map(Artifact::getId)
    .collect(Collectors.toList());
```

## Handling Checked Exceptions

```java
// ❌ Doesn't compile - can't throw checked exception from lambda
files.stream()
    .map(file -> Files.readString(file)) // IOException!
    .collect(Collectors.toList());

// ✅ Option 1: Wrap in unchecked exception
files.stream()
    .map(file -> {
        try {
            return Files.readString(file);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    })
    .collect(Collectors.toList());

// ✅ Option 2: Extract to method that handles exception
files.stream()
    .map(this::readFileSafely)
    .filter(Optional::isPresent)
    .map(Optional::get)
    .collect(Collectors.toList());

private Optional<String> readFileSafely(Path file) {
    try {
        return Optional.of(Files.readString(file));
    } catch (IOException e) {
        log.warn("Failed to read file: {}", file, e);
        return Optional.empty();
    }
}
```

## Stream Misuse Patterns

```java
// ❌ WRONG: Stream for simple iteration (overhead)
items.stream().forEach(item -> process(item));

// ✅ RIGHT: Enhanced for loop
for (Item item : items) {
    process(item);
}

// ❌ WRONG: Collecting just to iterate
items.stream()
    .filter(Item::isActive)
    .collect(Collectors.toList())  // Unnecessary intermediate list
    .forEach(this::process);

// ✅ RIGHT: Don't collect if not needed
items.stream()
    .filter(Item::isActive)
    .forEach(this::process);
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| Stream for simple filter | Overkill | Use loop |
| `forEach` with side effects | Hard to reason about | Use `collect()` |
| Checked exception in lambda | Won't compile | Wrap or extract method |
| `collect()` then `forEach()` | Wasteful | Just `forEach()` |
| `stream().forEach()` | Why stream? | Enhanced for loop |
