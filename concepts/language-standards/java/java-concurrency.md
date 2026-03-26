# Java Concurrency Patterns

> Virtual threads, structured concurrency, and thread-safe patterns.
>
> **See also:** `java-immutability.md` (thread-safe immutable objects), `java-exceptions.md` (exception handling in async code)

## Virtual Threads (Java 21+)

```java
// ❌ WRONG: Thread pools for I/O-bound work
ExecutorService executor = Executors.newFixedThreadPool(100);
List<Future<Result>> futures = tasks.stream()
    .map(task -> executor.submit(() -> callExternalApi(task)))
    .toList();

// ✅ RIGHT: Virtual threads for I/O-bound operations
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    List<Future<Result>> futures = tasks.stream()
        .map(task -> executor.submit(() -> callExternalApi(task)))
        .toList();
    // Process results...
}
```

## Structured Concurrency (Java 21+)

```java
// ❌ WRONG: Manual coordination of subtasks
CompletableFuture<User> userFuture = CompletableFuture.supplyAsync(this::fetchUser);
CompletableFuture<Order> orderFuture = CompletableFuture.supplyAsync(this::fetchOrder);
// What if one fails? Manual cleanup needed

// ✅ RIGHT: Structured concurrency with proper scoping
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    var user = scope.fork(this::fetchUser);
    var order = scope.fork(this::fetchOrder);

    scope.join();
    scope.throwIfFailed();

    return new UserOrder(user.get(), order.get());
}
```

## Thread-Safe Patterns

```java
// ❌ WRONG: Mutable shared state
public class Counter {
    private int count = 0;

    public void increment() { count++; }  // Race condition!
    public int get() { return count; }
}

// ✅ RIGHT: Use atomic classes
public class Counter {
    private final AtomicInteger count = new AtomicInteger(0);

    public void increment() { count.incrementAndGet(); }
    public int get() { return count.get(); }
}

// ✅ BETTER: Use LongAdder for high contention
public class Counter {
    private final LongAdder count = new LongAdder();

    public void increment() { count.increment(); }
    public long get() { return count.sum(); }
}
```

## Concurrent Collections

```java
// ❌ WRONG: Synchronized wrapper with compound operations
Map<String, Integer> counts = Collections.synchronizedMap(new HashMap<>());
// This is NOT atomic:
Integer count = counts.get(key);
counts.put(key, count == null ? 1 : count + 1);

// ✅ RIGHT: ConcurrentHashMap with atomic compute
ConcurrentMap<String, Integer> counts = new ConcurrentHashMap<>();
counts.compute(key, (k, v) -> v == null ? 1 : v + 1);

// Or use merge for counting
counts.merge(key, 1, Integer::sum);
```

## CompletableFuture Patterns

```java
// ❌ WRONG: Sequential CompletableFuture
CompletableFuture<User> userFuture = fetchUser(id);
User user = userFuture.join();  // Blocks
CompletableFuture<List<Order>> ordersFuture = fetchOrders(id);
List<Order> orders = ordersFuture.join();  // Blocks again

// ✅ RIGHT: Parallel execution
CompletableFuture<User> userFuture = fetchUser(id);
CompletableFuture<List<Order>> ordersFuture = fetchOrders(id);
CompletableFuture.allOf(userFuture, ordersFuture).join();
User user = userFuture.join();
List<Order> orders = ordersFuture.join();
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `newFixedThreadPool` for I/O | Limited scalability | Virtual threads |
| Manual CompletableFuture coordination | Cleanup issues | Structured concurrency |
| `count++` on shared field | Race condition | `AtomicInteger` |
| `synchronizedMap` compound ops | Not atomic | `ConcurrentHashMap.compute` |
| Sequential `.join()` calls | Wastes time | `CompletableFuture.allOf` |
