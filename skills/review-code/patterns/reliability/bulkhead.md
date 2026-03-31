# Bulkhead Pattern

> Isolate elements into pools so that if one fails, the others continue to function. Inspired by ship compartments that prevent flooding from sinking the entire vessel.

**Source**: Michael Nygard, "Release It!" (2007, 2018)

## Intent

Partition system resources (threads, connections, memory) into isolated pools. A failure in one pool doesn't exhaust resources for other pools, preventing cascading failures.

## Key Concepts

- **Isolation**: Each component gets its own resource pool
- **Containment**: Failures are contained within their pool
- **Resilience**: System continues functioning despite partial failure
- **Graceful Degradation**: Overwhelmed components fail without affecting others

## Structure

```
Without Bulkhead:
┌─────────────────────────────────────────────────┐
│              Shared Thread Pool (100)            │
│                                                  │
│  Service A ────────┐                             │
│                    ├──► All 100 threads          │
│  Service B ────────┤      consumed by            │
│                    │      slow Service C!        │
│  Service C (slow) ─┘                             │
└─────────────────────────────────────────────────┘

With Bulkhead:
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│  Pool A (30)  │  │  Pool B (30)  │  │  Pool C (40)  │
│               │  │               │  │               │
│  Service A    │  │  Service B    │  │  Service C    │
│  (healthy)    │  │  (healthy)    │  │  (slow/full)  │
└───────────────┘  └───────────────┘  └───────────────┘
        ✓                  ✓                  ✗
   Still works!       Still works!      Isolated failure
```

## When to Use

- Multiple downstream dependencies with different reliability
- Critical and non-critical paths share resources
- Slow services can consume all shared resources
- Need to protect critical functionality

## When NOT to Use

- Single downstream dependency
- All dependencies equally reliable
- System has excess capacity
- Adds complexity without clear benefit

## Types of Bulkheads

### 1. Thread Pool Isolation
Separate thread pools for different services.

### 2. Connection Pool Isolation
Separate connection pools for different databases/services.

### 3. Semaphore Isolation
Limit concurrent calls without dedicated threads.

### 4. Process Isolation
Separate processes for different workloads.

## Language Examples

### Java (Resilience4j)

```java
// Configuration
@Configuration
public class BulkheadConfig {

    @Bean
    public BulkheadRegistry bulkheadRegistry() {
        return BulkheadRegistry.of(Map.of(
            "inventoryService", BulkheadConfig.custom()
                .maxConcurrentCalls(25)
                .maxWaitDuration(Duration.ofMillis(500))
                .build(),
            "paymentService", BulkheadConfig.custom()
                .maxConcurrentCalls(10)  // More restrictive for payment
                .maxWaitDuration(Duration.ofMillis(100))
                .build(),
            "notificationService", BulkheadConfig.custom()
                .maxConcurrentCalls(50)  // Non-critical, allow more
                .maxWaitDuration(Duration.ZERO)  // Fail fast
                .build()
        ));
    }
}

// Service with bulkhead
@Service
public class OrderService {
    private final Bulkhead inventoryBulkhead;
    private final Bulkhead paymentBulkhead;
    private final Bulkhead notificationBulkhead;

    private final InventoryClient inventoryClient;
    private final PaymentClient paymentClient;
    private final NotificationClient notificationClient;

    public OrderService(BulkheadRegistry registry, ...) {
        this.inventoryBulkhead = registry.bulkhead("inventoryService");
        this.paymentBulkhead = registry.bulkhead("paymentService");
        this.notificationBulkhead = registry.bulkhead("notificationService");
        // ... clients
    }

    public Order createOrder(CreateOrderCommand command) {
        // Check inventory (with bulkhead)
        boolean available = Bulkhead.decorateSupplier(inventoryBulkhead,
            () -> inventoryClient.checkAvailability(command.getItems())
        ).get();

        if (!available) {
            throw new InsufficientInventoryException();
        }

        // Process payment (with bulkhead)
        PaymentResult payment = Bulkhead.decorateSupplier(paymentBulkhead,
            () -> paymentClient.charge(command.getCustomerId(), command.getTotal())
        ).get();

        Order order = Order.create(command, payment);

        // Send notification (with bulkhead, non-blocking)
        try {
            Bulkhead.decorateRunnable(notificationBulkhead,
                () -> notificationClient.sendConfirmation(order)
            ).run();
        } catch (BulkheadFullException e) {
            // Non-critical: log and continue
            log.warn("Notification bulkhead full, skipping notification for order {}", order.getId());
        }

        return order;
    }
}

// Thread Pool Bulkhead (for async operations)
@Configuration
public class ThreadPoolBulkheadConfig {

    @Bean
    public ThreadPoolBulkheadRegistry threadPoolBulkheadRegistry() {
        return ThreadPoolBulkheadRegistry.of(Map.of(
            "inventoryService", ThreadPoolBulkheadConfig.custom()
                .maxThreadPoolSize(10)
                .coreThreadPoolSize(5)
                .queueCapacity(25)
                .keepAliveDuration(Duration.ofSeconds(20))
                .build()
        ));
    }
}

@Service
public class AsyncOrderService {
    private final ThreadPoolBulkhead bulkhead;

    public CompletableFuture<InventoryStatus> checkInventoryAsync(List<Item> items) {
        return ThreadPoolBulkhead.decorateCompletionStage(bulkhead,
            () -> inventoryClient.checkAvailabilityAsync(items)
        ).toCompletableFuture();
    }
}
```

### Java (Using ExecutorService Directly)

```java
@Service
public class BulkheadedServiceClient {
    // Separate thread pools for different services
    private final ExecutorService inventoryExecutor;
    private final ExecutorService paymentExecutor;
    private final ExecutorService notificationExecutor;

    public BulkheadedServiceClient() {
        // Critical path: limited pool
        this.inventoryExecutor = new ThreadPoolExecutor(
            5, 25,                           // core/max threads
            60L, TimeUnit.SECONDS,
            new ArrayBlockingQueue<>(50),    // Bounded queue
            new ThreadPoolExecutor.CallerRunsPolicy()  // Backpressure
        );

        // Payment: very limited, fast fail
        this.paymentExecutor = new ThreadPoolExecutor(
            2, 10,
            30L, TimeUnit.SECONDS,
            new ArrayBlockingQueue<>(10),
            new ThreadPoolExecutor.AbortPolicy()  // Reject when full
        );

        // Notifications: larger pool, best effort
        this.notificationExecutor = new ThreadPoolExecutor(
            10, 50,
            60L, TimeUnit.SECONDS,
            new LinkedBlockingQueue<>(100)
        );
    }

    public CompletableFuture<InventoryStatus> checkInventory(List<Item> items) {
        return CompletableFuture.supplyAsync(
            () -> inventoryClient.check(items),
            inventoryExecutor
        ).orTimeout(5, TimeUnit.SECONDS);
    }

    public CompletableFuture<PaymentResult> processPayment(PaymentRequest request) {
        return CompletableFuture.supplyAsync(
            () -> paymentClient.charge(request),
            paymentExecutor
        ).orTimeout(10, TimeUnit.SECONDS);
    }

    @PreDestroy
    public void shutdown() {
        shutdownExecutor(inventoryExecutor, "inventory");
        shutdownExecutor(paymentExecutor, "payment");
        shutdownExecutor(notificationExecutor, "notification");
    }

    private void shutdownExecutor(ExecutorService executor, String name) {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(30, TimeUnit.SECONDS)) {
                log.warn("{} executor did not terminate gracefully", name);
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}
```

### Go

```go
// Semaphore-based bulkhead
type Bulkhead struct {
    name       string
    semaphore  chan struct{}
    timeout    time.Duration
    metrics    *BulkheadMetrics
}

func NewBulkhead(name string, maxConcurrent int, timeout time.Duration) *Bulkhead {
    return &Bulkhead{
        name:      name,
        semaphore: make(chan struct{}, maxConcurrent),
        timeout:   timeout,
        metrics:   newBulkheadMetrics(name),
    }
}

func (b *Bulkhead) Execute(ctx context.Context, fn func() error) error {
    // Try to acquire permit
    select {
    case b.semaphore <- struct{}{}:
        // Acquired permit
        defer func() { <-b.semaphore }()
        b.metrics.RecordAcquire()
        return fn()

    case <-time.After(b.timeout):
        b.metrics.RecordRejected()
        return ErrBulkheadFull

    case <-ctx.Done():
        return ctx.Err()
    }
}

// Usage
type OrderService struct {
    inventoryBulkhead    *Bulkhead
    paymentBulkhead      *Bulkhead
    notificationBulkhead *Bulkhead

    inventory    InventoryClient
    payment      PaymentClient
    notification NotificationClient
}

func NewOrderService(inv InventoryClient, pay PaymentClient, notif NotificationClient) *OrderService {
    return &OrderService{
        inventoryBulkhead:    NewBulkhead("inventory", 25, 500*time.Millisecond),
        paymentBulkhead:      NewBulkhead("payment", 10, 100*time.Millisecond),
        notificationBulkhead: NewBulkhead("notification", 50, 0), // Fail fast

        inventory:    inv,
        payment:      pay,
        notification: notif,
    }
}

func (s *OrderService) CreateOrder(ctx context.Context, cmd CreateOrderCommand) (*Order, error) {
    // Check inventory with bulkhead
    var available bool
    err := s.inventoryBulkhead.Execute(ctx, func() error {
        var err error
        available, err = s.inventory.CheckAvailability(ctx, cmd.Items)
        return err
    })
    if err != nil {
        if errors.Is(err, ErrBulkheadFull) {
            return nil, fmt.Errorf("inventory service overloaded: %w", err)
        }
        return nil, fmt.Errorf("check inventory: %w", err)
    }

    if !available {
        return nil, ErrInsufficientInventory
    }

    // Process payment with bulkhead
    var payment *PaymentResult
    err = s.paymentBulkhead.Execute(ctx, func() error {
        var err error
        payment, err = s.payment.Charge(ctx, cmd.CustomerID, cmd.Total)
        return err
    })
    if err != nil {
        return nil, fmt.Errorf("process payment: %w", err)
    }

    order := NewOrder(cmd, payment)

    // Send notification (best effort)
    go func() {
        notifCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()

        if err := s.notificationBulkhead.Execute(notifCtx, func() error {
            return s.notification.SendConfirmation(notifCtx, order)
        }); err != nil {
            slog.Warn("failed to send notification",
                "order_id", order.ID,
                "error", err,
            )
        }
    }()

    return order, nil
}

// Worker pool bulkhead
type WorkerPoolBulkhead struct {
    workers chan struct{}
    jobs    chan func()
    wg      sync.WaitGroup
}

func NewWorkerPoolBulkhead(numWorkers int, queueSize int) *WorkerPoolBulkhead {
    b := &WorkerPoolBulkhead{
        workers: make(chan struct{}, numWorkers),
        jobs:    make(chan func(), queueSize),
    }

    // Start workers
    for i := 0; i < numWorkers; i++ {
        b.wg.Add(1)
        go b.worker()
    }

    return b
}

func (b *WorkerPoolBulkhead) worker() {
    defer b.wg.Done()
    for job := range b.jobs {
        job()
    }
}

func (b *WorkerPoolBulkhead) Submit(job func()) error {
    select {
    case b.jobs <- job:
        return nil
    default:
        return ErrQueueFull
    }
}
```

## Review Checklist

### Design
- [ ] **[BLOCKER]** Critical and non-critical paths have separate pools
- [ ] **[MAJOR]** Pool sizes based on expected load and SLAs
- [ ] **[MAJOR]** Bulkheads combined with timeouts
- [ ] **[MINOR]** Metrics exposed for pool utilization

### Implementation
- [ ] **[BLOCKER]** Bounded queues (not unbounded)
- [ ] **[MAJOR]** Rejection policy defined (fail fast vs. caller runs)
- [ ] **[MAJOR]** Graceful shutdown implemented
- [ ] **[MINOR]** Health checks include bulkhead state

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Unbounded queues (can cause OOM)
- [ ] **[MAJOR]** Same pool for all services
- [ ] **[MAJOR]** Missing timeout on bulkhead acquire
- [ ] **[MINOR]** No monitoring of bulkhead rejections

## Common Mistakes

### 1. Unbounded Queue
```java
// BAD: Unbounded queue can cause OOM
new ThreadPoolExecutor(10, 10, 0L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>()  // Unbounded!
);

// GOOD: Bounded queue with rejection policy
new ThreadPoolExecutor(10, 10, 0L, TimeUnit.SECONDS,
    new ArrayBlockingQueue<>(100),  // Bounded
    new ThreadPoolExecutor.CallerRunsPolicy()
);
```

### 2. No Timeout on Acquisition
```java
// BAD: Blocks indefinitely waiting for permit
bulkhead.acquire();  // May never return!

// GOOD: Timeout on acquisition
if (!bulkhead.tryAcquire(500, TimeUnit.MILLISECONDS)) {
    throw new BulkheadFullException("Service overloaded");
}
```

### 3. Shared Pool for Different SLAs
```java
// BAD: Critical payment shares pool with notifications
executor.submit(() -> processPayment(...));
executor.submit(() -> sendNotification(...));  // May starve payments!

// GOOD: Separate pools
paymentExecutor.submit(() -> processPayment(...));
notificationExecutor.submit(() -> sendNotification(...));
```

## Sizing Guidelines

| Factor | Consideration |
|--------|---------------|
| **Expected Concurrency** | Normal load × safety margin (1.5-2x) |
| **SLA Requirements** | Critical paths get dedicated resources |
| **Downstream Latency** | Slower services need larger pools |
| **Memory Constraints** | Each thread ~1MB stack |
| **Queue Size** | Latency × throughput |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Circuit Breaker** | Prevents calls to failing services |
| **Timeout** | Limits time waiting in bulkhead |
| **Rate Limiting** | Limits overall throughput |
| **Retry** | Retries may fill bulkhead - be careful |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Resilience4j Bulkhead](https://resilience4j.readme.io/docs/bulkhead) | Semaphore and thread pool isolation |
| **Java** | [Failsafe](https://failsafe.dev/) | Bulkhead with other resilience policies |
| **Java** | [Hystrix](https://github.com/Netflix/Hystrix) | Thread pool isolation (deprecated but influential) |
| **Go** | [golang.org/x/sync/semaphore](https://pkg.go.dev/golang.org/x/sync/semaphore) | Weighted semaphore for bulkhead |
| **Go** | Channels | Native channel-based semaphore (idiomatic) |
| **Python** | [asyncio.Semaphore](https://docs.python.org/3/library/asyncio-sync.html) | Built-in async semaphore |
| **Python** | [aiolimiter](https://pypi.org/project/aiolimiter/) | Rate limiting and bulkhead for async |
| **JavaScript** | [p-limit](https://github.com/sindresorhus/p-limit) | Concurrency limiter for promises |
| **JavaScript** | [cockatiel](https://github.com/connor4312/cockatiel) | Bulkhead policy with other patterns |
| **JavaScript** | [bottleneck](https://github.com/SGrondin/bottleneck) | Rate limiter with clustering support |

## References

- Michael Nygard, "Release It!" Chapter 5
- Resilience4j Bulkhead: https://resilience4j.readme.io/docs/bulkhead
- Netflix Hystrix (deprecated but influential)
