# Timeout Pattern

> Set a time limit for operations. If the operation doesn't complete within the limit, abort it and handle the failure.

**Source**: Michael Nygard, "Release It!" (2007, 2018)

## Intent

Prevent indefinite blocking by setting explicit time limits on operations. When a timeout expires, fail fast and allow the system to recover rather than waiting forever.

## Key Concepts

- **Time Budget**: Fixed duration for operation completion
- **Fail Fast**: Better to fail quickly than hang indefinitely
- **Resource Protection**: Prevents thread/connection exhaustion
- **Cascading Prevention**: Stops slow dependencies from blocking callers

## The Problem

```
Without Timeouts:
┌─────────┐         ┌─────────────┐
│ Service │────────►│Slow/Hung DB │
│   A     │ waiting │             │
│ (stuck) │ forever │  (not       │
│         │────────►│  responding)│
└─────────┘         └─────────────┘
     ↑
     │ All threads blocked waiting
     │ Service A becomes unresponsive
```

## When to Use

- **Always** - Every external call should have a timeout
- Network operations (HTTP, database, queues)
- Inter-service communication
- File I/O on network filesystems
- Any operation that can hang

## When NOT to Use

- Never skip timeouts on external calls
- Long-running background jobs (use different mechanism)
- User-facing uploads (show progress instead)

## Types of Timeouts

| Type | Description | Example |
|------|-------------|---------|
| **Connection Timeout** | Time to establish connection | 2-5 seconds |
| **Read Timeout** | Time to receive response | 5-30 seconds |
| **Write Timeout** | Time to send request | 5-10 seconds |
| **Request Timeout** | Total time for operation | Sum of above + processing |
| **Idle Timeout** | Time before closing idle connection | 30-300 seconds |

## Language Examples

### Java

```java
// HTTP Client timeouts
@Configuration
public class HttpClientConfig {

    @Bean
    public RestTemplate restTemplate() {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(3));
        factory.setReadTimeout(Duration.ofSeconds(10));
        return new RestTemplate(factory);
    }

    @Bean
    public WebClient webClient() {
        HttpClient httpClient = HttpClient.create()
            .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 3000)
            .responseTimeout(Duration.ofSeconds(10))
            .doOnConnected(conn -> conn
                .addHandlerLast(new ReadTimeoutHandler(10))
                .addHandlerLast(new WriteTimeoutHandler(5))
            );

        return WebClient.builder()
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .build();
    }
}

// Database timeouts
@Configuration
public class DataSourceConfig {

    @Bean
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://localhost:5432/db");

        // Connection pool timeouts
        config.setConnectionTimeout(5000);      // Wait for connection from pool
        config.setValidationTimeout(3000);      // Connection validation
        config.setIdleTimeout(300000);          // Close idle connections
        config.setMaxLifetime(1800000);         // Max connection lifetime
        config.setLeakDetectionThreshold(60000); // Detect connection leaks

        return new HikariDataSource(config);
    }
}

// Query timeout
@Repository
public class OrderRepository {

    @QueryHints(@QueryHint(name = "javax.persistence.query.timeout", value = "5000"))
    List<Order> findPendingOrders();

    // Or programmatically
    public List<Order> findWithTimeout(Specification<Order> spec) {
        Query query = entityManager.createQuery(
            "SELECT o FROM Order o WHERE o.status = :status"
        );
        query.setHint("javax.persistence.query.timeout", 5000);
        query.setParameter("status", OrderStatus.PENDING);
        return query.getResultList();
    }
}

// CompletableFuture with timeout
public class AsyncService {

    public CompletableFuture<Result> fetchWithTimeout(String id) {
        return CompletableFuture.supplyAsync(() -> {
                return externalService.fetch(id);
            })
            .orTimeout(10, TimeUnit.SECONDS)
            .exceptionally(ex -> {
                if (ex instanceof TimeoutException) {
                    log.warn("Fetch timed out for id: {}", id);
                    return Result.timeout();
                }
                throw new CompletionException(ex);
            });
    }
}

// Timeout with fallback
@Service
public class OrderService {
    private final InventoryClient inventoryClient;
    private final Duration timeout = Duration.ofSeconds(5);

    public boolean checkInventory(List<Item> items) {
        try {
            return CompletableFuture
                .supplyAsync(() -> inventoryClient.check(items))
                .get(timeout.toMillis(), TimeUnit.MILLISECONDS);
        } catch (TimeoutException e) {
            log.warn("Inventory check timed out, using cache");
            return inventoryCache.check(items);  // Fallback to cache
        } catch (Exception e) {
            throw new ServiceException("Inventory check failed", e);
        }
    }
}

// Resilience4j TimeLimiter
@Configuration
public class TimeLimiterConfig {

    @Bean
    public TimeLimiterRegistry timeLimiterRegistry() {
        return TimeLimiterRegistry.of(Map.of(
            "inventoryService", TimeLimiterConfig.custom()
                .timeoutDuration(Duration.ofSeconds(5))
                .cancelRunningFuture(true)
                .build(),
            "paymentService", TimeLimiterConfig.custom()
                .timeoutDuration(Duration.ofSeconds(10))
                .build()
        ));
    }
}

@Service
public class TimeoutProtectedService {
    private final TimeLimiter timeLimiter;

    public InventoryStatus checkInventory(List<Item> items) {
        Supplier<CompletableFuture<InventoryStatus>> supplier = () ->
            CompletableFuture.supplyAsync(() -> inventoryClient.check(items));

        return TimeLimiter.decorateFutureSupplier(timeLimiter, supplier).get();
    }
}
```

### Go

```go
// HTTP client with timeouts
func NewHTTPClient() *http.Client {
    return &http.Client{
        Timeout: 30 * time.Second,  // Total request timeout
        Transport: &http.Transport{
            DialContext: (&net.Dialer{
                Timeout:   5 * time.Second,   // Connection timeout
                KeepAlive: 30 * time.Second,
            }).DialContext,
            TLSHandshakeTimeout:   5 * time.Second,
            ResponseHeaderTimeout: 10 * time.Second,
            IdleConnTimeout:       90 * time.Second,
            MaxIdleConns:          100,
            MaxIdleConnsPerHost:   10,
        },
    }
}

// Context-based timeout
func (s *OrderService) CheckInventory(ctx context.Context, items []Item) (bool, error) {
    // Create timeout context
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    // Make request
    available, err := s.inventory.Check(ctx, items)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            // Timeout - try fallback
            slog.Warn("inventory check timed out, using cache")
            return s.cache.CheckInventory(items)
        }
        return false, fmt.Errorf("check inventory: %w", err)
    }

    return available, nil
}

// Database query timeout
func (r *OrderRepository) FindPending(ctx context.Context) ([]Order, error) {
    ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
    defer cancel()

    rows, err := r.db.QueryContext(ctx,
        "SELECT * FROM orders WHERE status = $1",
        OrderStatusPending,
    )
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return nil, ErrQueryTimeout
        }
        return nil, fmt.Errorf("query orders: %w", err)
    }
    defer rows.Close()

    // ... scan results
}

// Timeout utility function
func WithTimeout[T any](ctx context.Context, timeout time.Duration, fn func(context.Context) (T, error)) (T, error) {
    ctx, cancel := context.WithTimeout(ctx, timeout)
    defer cancel()

    resultCh := make(chan T, 1)
    errCh := make(chan error, 1)

    go func() {
        result, err := fn(ctx)
        if err != nil {
            errCh <- err
            return
        }
        resultCh <- result
    }()

    select {
    case result := <-resultCh:
        return result, nil
    case err := <-errCh:
        var zero T
        return zero, err
    case <-ctx.Done():
        var zero T
        return zero, ctx.Err()
    }
}

// Usage
func (s *Service) FetchUser(ctx context.Context, id string) (*User, error) {
    return WithTimeout(ctx, 5*time.Second, func(ctx context.Context) (*User, error) {
        return s.userClient.Get(ctx, id)
    })
}

// gRPC timeouts
func NewGRPCClient(addr string) (*grpc.ClientConn, error) {
    return grpc.Dial(addr,
        grpc.WithTransportCredentials(insecure.NewCredentials()),
        grpc.WithUnaryInterceptor(
            grpc_middleware.ChainUnaryClient(
                grpc_retry.UnaryClientInterceptor(
                    grpc_retry.WithMax(3),
                    grpc_retry.WithPerRetryTimeout(2*time.Second),
                ),
            ),
        ),
        grpc.WithDefaultCallOptions(
            grpc.WaitForReady(false),
        ),
    )
}

// Per-call timeout
func (c *Client) GetUser(ctx context.Context, id string) (*User, error) {
    ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
    defer cancel()

    return c.grpcClient.GetUser(ctx, &GetUserRequest{Id: id})
}
```

## Timeout Strategy

### Cascading Timeouts

```
Client           Service A         Service B         Database
  │                 │                 │                 │
  │───── 30s ──────►│                 │                 │
  │                 │───── 20s ──────►│                 │
  │                 │                 │───── 10s ──────►│
  │                 │                 │◄────────────────│
  │                 │◄────────────────│                 │
  │◄────────────────│                 │                 │

Each layer's timeout should be LESS than caller's timeout
```

```java
// Cascading timeout calculation
public class TimeoutCalculator {
    private static final Duration SAFETY_MARGIN = Duration.ofMillis(500);

    public Duration calculateDownstreamTimeout(Duration upstreamTimeout) {
        // Leave margin for processing and network latency
        long downstreamMs = upstreamTimeout.toMillis() - SAFETY_MARGIN.toMillis();
        return Duration.ofMillis(Math.max(downstreamMs, 1000));  // Min 1 second
    }
}

// Example: API Gateway -> Service -> Database
// Gateway timeout: 30s
// Service timeout: 25s (30s - 5s margin)
// DB timeout: 20s (25s - 5s margin)
```

## Review Checklist

### Configuration
- [ ] **[BLOCKER]** All external calls have explicit timeouts
- [ ] **[BLOCKER]** Timeouts cascade (downstream < upstream)
- [ ] **[MAJOR]** Separate connection and read timeouts
- [ ] **[MAJOR]** Timeouts based on SLA requirements
- [ ] **[MINOR]** Timeouts are configurable (not hardcoded)

### Handling
- [ ] **[BLOCKER]** Timeout exceptions handled gracefully
- [ ] **[MAJOR]** Logging includes timeout duration and operation
- [ ] **[MAJOR]** Fallback behavior defined for timeouts
- [ ] **[MINOR]** Metrics track timeout rate

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** No timeout on network calls
- [ ] **[BLOCKER]** Timeout longer than caller's timeout
- [ ] **[MAJOR]** Same timeout for all operations
- [ ] **[MAJOR]** Swallowed timeout exceptions

## Common Mistakes

### 1. No Timeout at All
```java
// BAD: No timeout - can hang forever
Response response = httpClient.execute(request);

// GOOD: Explicit timeout
Response response = httpClient.execute(request,
    RequestConfig.custom()
        .setConnectTimeout(3000)
        .setSocketTimeout(10000)
        .build()
);
```

### 2. Timeout Longer Than Caller
```java
// BAD: Service B timeout > Service A timeout
// Service A calls Service B
// Service A timeout: 5 seconds
// Service B timeout: 10 seconds  // Still waiting after A gave up!

// GOOD: Cascade timeouts
// Service A timeout: 10 seconds
// Service B timeout: 7 seconds (leaves 3s margin)
```

### 3. Silently Swallowing Timeout
```java
// BAD: Timeout hidden
try {
    return client.fetch(id);
} catch (TimeoutException e) {
    return null;  // Silent failure!
}

// GOOD: Log and handle appropriately
try {
    return client.fetch(id);
} catch (TimeoutException e) {
    log.warn("Fetch timed out for id={}", id);
    metrics.incrementTimeout("fetch");
    throw new ServiceTimeoutException("Fetch service timed out", e);
}
```

### 4. Infinite Retry with Timeout
```java
// BAD: Retry forever with timeout each time
while (true) {
    try {
        return client.fetchWithTimeout(5, TimeUnit.SECONDS);
    } catch (TimeoutException e) {
        // Retry indefinitely - bad!
    }
}

// GOOD: Limited retries with backoff
RetryTemplate retry = RetryTemplate.builder()
    .maxAttempts(3)
    .exponentialBackoff(100, 2, 2000)
    .build();

return retry.execute(ctx -> client.fetchWithTimeout(5, TimeUnit.SECONDS));
```

## Timeout Guidelines

| Operation Type | Typical Timeout | Notes |
|---------------|-----------------|-------|
| **Connection** | 1-5 seconds | Fail fast if can't connect |
| **Health Check** | 1-3 seconds | Must be quick |
| **Read (simple)** | 5-10 seconds | Single record lookup |
| **Read (complex)** | 10-30 seconds | Reports, aggregations |
| **Write** | 5-15 seconds | Database inserts/updates |
| **External API** | 10-30 seconds | Depends on SLA |
| **File Upload** | Based on size | Calculate from bandwidth |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Circuit Breaker** | Opens after repeated timeouts |
| **Retry** | Retry after timeout (carefully) |
| **Bulkhead** | Prevent timeout cascade |
| **Deadline Propagation** | Pass remaining time to callees |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Resilience4j TimeLimiter](https://resilience4j.readme.io/docs/timeout) | Composable with other policies |
| **Java** | [Failsafe](https://failsafe.dev/) | Timeout + retry + circuit breaker |
| **Java** | [java.util.concurrent](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/concurrent/CompletableFuture.html) | `CompletableFuture.orTimeout()` (Java 9+) |
| **Go** | [context](https://pkg.go.dev/context) | Built-in `context.WithTimeout()` - idiomatic |
| **Python** | [asyncio](https://docs.python.org/3/library/asyncio-task.html) | `asyncio.timeout()` (Python 3.11+) |
| **Python** | [async-timeout](https://pypi.org/project/async-timeout/) | For older Python versions |
| **Python** | [timeout-decorator](https://pypi.org/project/timeout-decorator/) | Decorator-based for sync code |
| **JavaScript** | [p-timeout](https://github.com/sindresorhus/p-timeout) | Promise timeout wrapper |
| **JavaScript** | [AbortController](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) | Built-in, works with fetch |
| **JavaScript** | [cockatiel](https://github.com/connor4312/cockatiel) | Timeout policy with other resilience patterns |

## References

- Michael Nygard, "Release It!" Chapter 5
- AWS Well-Architected Framework - Reliability Pillar
- Google SRE Book - Handling Overload
