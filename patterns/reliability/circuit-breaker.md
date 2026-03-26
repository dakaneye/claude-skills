# Circuit Breaker Pattern

> Prevent cascading failures by failing fast when a dependency is unhealthy, allowing the system to recover.

**Source**: Michael Nygard, "Release It!" (2007)

## Intent

Handle failures in distributed systems gracefully. When a remote service is failing, stop making requests to it temporarily to:
1. Give it time to recover
2. Prevent resource exhaustion (threads, connections)
3. Fail fast to users instead of hanging

## The Electrical Analogy

```
CLOSED (normal)     OPEN (tripped)      HALF-OPEN (testing)
     │                   │                    │
  [─/─]               [─ ─]               [─/─] (one request)
     │                   │                    │
  Current              No                  Test if
  flows              current              recovered
```

## State Machine

```
                    failure threshold
                    exceeded
         ┌─────────────────────────────┐
         │                             ▼
    ┌────┴────┐                  ┌──────────┐
    │ CLOSED  │                  │   OPEN   │
    │ (allow) │                  │  (deny)  │
    └────┬────┘                  └────┬─────┘
         │                            │
         │     success               │ timeout expires
         │  ◀──────────────────────────────┐
         │                            │    │
         │                            ▼    │
         │                      ┌──────────┴─┐
         │                      │ HALF-OPEN  │
         │                      │  (probe)   │
         │                      └────────────┘
         │                            │
         └────────────────────────────┘
                  failure (trip again)
```

## When to Use

- Remote service calls (HTTP, gRPC, database)
- Operations that can timeout or fail
- Dependencies that have been unreliable
- Protecting critical paths from slow/failing dependencies

## When NOT to Use

- Local method calls (no network)
- Operations that must complete (use retry instead)
- Fire-and-forget operations
- In-process failures (use try/catch)

## Language Examples

### Java (Resilience4j)

```java
// Configuration
CircuitBreakerConfig config = CircuitBreakerConfig.custom()
    .failureRateThreshold(50)           // 50% failure rate trips circuit
    .slowCallRateThreshold(50)          // 50% slow calls also trips
    .slowCallDurationThreshold(Duration.ofSeconds(2))
    .waitDurationInOpenState(Duration.ofSeconds(30))  // Wait before half-open
    .permittedNumberOfCallsInHalfOpenState(3)         // Test calls
    .minimumNumberOfCalls(10)           // Minimum calls before calculating rate
    .slidingWindowType(SlidingWindowType.COUNT_BASED)
    .slidingWindowSize(100)             // Last 100 calls
    .build();

CircuitBreaker circuitBreaker = CircuitBreaker.of("paymentService", config);

// Usage with decorator
Supplier<Payment> decoratedSupplier = CircuitBreaker
    .decorateSupplier(circuitBreaker, () -> paymentService.process(request));

Try<Payment> result = Try.ofSupplier(decoratedSupplier)
    .recover(CallNotPermittedException.class, e -> {
        // Circuit is OPEN - fail fast
        return Payment.fallback("Service temporarily unavailable");
    })
    .recover(Exception.class, e -> {
        // Actual failure from service
        return Payment.fallback("Payment failed: " + e.getMessage());
    });

// Usage with annotations (Spring)
@CircuitBreaker(name = "paymentService", fallbackMethod = "fallbackPayment")
public Payment processPayment(PaymentRequest request) {
    return paymentClient.process(request);
}

public Payment fallbackPayment(PaymentRequest request, Exception e) {
    log.warn("Circuit breaker fallback for payment", e);
    return Payment.pending("Will retry later");
}
```

### Go (Custom Implementation)

```go
package circuitbreaker

import (
    "errors"
    "sync"
    "time"
)

var ErrCircuitOpen = errors.New("circuit breaker is open")

type State int

const (
    StateClosed State = iota
    StateOpen
    StateHalfOpen
)

type CircuitBreaker struct {
    mu sync.Mutex

    state            State
    failureCount     int
    successCount     int
    failureThreshold int
    successThreshold int
    timeout          time.Duration
    lastFailure      time.Time
}

func New(failureThreshold, successThreshold int, timeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        state:            StateClosed,
        failureThreshold: failureThreshold,
        successThreshold: successThreshold,
        timeout:          timeout,
    }
}

func (cb *CircuitBreaker) Execute(fn func() error) error {
    if !cb.allowRequest() {
        return ErrCircuitOpen
    }

    err := fn()

    cb.recordResult(err == nil)
    return err
}

func (cb *CircuitBreaker) allowRequest() bool {
    cb.mu.Lock()
    defer cb.mu.Unlock()

    switch cb.state {
    case StateClosed:
        return true

    case StateOpen:
        // Check if timeout has passed
        if time.Since(cb.lastFailure) > cb.timeout {
            cb.state = StateHalfOpen
            cb.successCount = 0
            return true
        }
        return false

    case StateHalfOpen:
        return true
    }

    return false
}

func (cb *CircuitBreaker) recordResult(success bool) {
    cb.mu.Lock()
    defer cb.mu.Unlock()

    switch cb.state {
    case StateClosed:
        if success {
            cb.failureCount = 0
        } else {
            cb.failureCount++
            if cb.failureCount >= cb.failureThreshold {
                cb.state = StateOpen
                cb.lastFailure = time.Now()
            }
        }

    case StateHalfOpen:
        if success {
            cb.successCount++
            if cb.successCount >= cb.successThreshold {
                cb.state = StateClosed
                cb.failureCount = 0
            }
        } else {
            cb.state = StateOpen
            cb.lastFailure = time.Now()
        }
    }
}

// Usage
func main() {
    cb := circuitbreaker.New(
        5,                    // 5 failures to open
        2,                    // 2 successes to close
        30*time.Second,       // Wait 30s before half-open
    )

    err := cb.Execute(func() error {
        return externalService.Call()
    })

    if errors.Is(err, circuitbreaker.ErrCircuitOpen) {
        // Use fallback
        return cachedResult()
    }
}
```

### Python

```python
import time
from enum import Enum
from functools import wraps
from threading import Lock
from typing import Callable, TypeVar, Generic

T = TypeVar('T')

class State(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class CircuitBreakerError(Exception):
    pass

class CircuitBreaker:
    def __init__(
        self,
        failure_threshold: int = 5,
        success_threshold: int = 2,
        timeout: float = 30.0,
    ):
        self._state = State.CLOSED
        self._failure_count = 0
        self._success_count = 0
        self._failure_threshold = failure_threshold
        self._success_threshold = success_threshold
        self._timeout = timeout
        self._last_failure_time: float = 0
        self._lock = Lock()

    @property
    def state(self) -> State:
        with self._lock:
            if self._state == State.OPEN:
                if time.time() - self._last_failure_time > self._timeout:
                    self._state = State.HALF_OPEN
                    self._success_count = 0
            return self._state

    def call(self, func: Callable[[], T]) -> T:
        if self.state == State.OPEN:
            raise CircuitBreakerError("Circuit breaker is open")

        try:
            result = func()
            self._record_success()
            return result
        except Exception as e:
            self._record_failure()
            raise

    def _record_success(self) -> None:
        with self._lock:
            if self._state == State.HALF_OPEN:
                self._success_count += 1
                if self._success_count >= self._success_threshold:
                    self._state = State.CLOSED
                    self._failure_count = 0
            else:
                self._failure_count = 0

    def _record_failure(self) -> None:
        with self._lock:
            if self._state == State.HALF_OPEN:
                self._state = State.OPEN
                self._last_failure_time = time.time()
            else:
                self._failure_count += 1
                if self._failure_count >= self._failure_threshold:
                    self._state = State.OPEN
                    self._last_failure_time = time.time()


# Decorator usage
def circuit_breaker(cb: CircuitBreaker):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            return cb.call(lambda: func(*args, **kwargs))
        return wrapper
    return decorator


# Usage
payment_cb = CircuitBreaker(failure_threshold=5, timeout=30.0)

@circuit_breaker(payment_cb)
def process_payment(amount: float) -> str:
    return payment_service.charge(amount)

# With fallback
def safe_process_payment(amount: float) -> str:
    try:
        return process_payment(amount)
    except CircuitBreakerError:
        return queue_for_later(amount)
```

## Configuration Guidelines

| Parameter | Description | Typical Value |
|-----------|-------------|---------------|
| Failure Threshold | Failures to trip | 5-10 |
| Success Threshold | Successes to recover | 2-5 |
| Timeout | Wait before half-open | 30-60 seconds |
| Window Size | Calls to consider | 10-100 |
| Slow Call Threshold | What's "slow" | 2-5 seconds |

## Review Checklist

### Correct Implementation
- [ ] **[BLOCKER]** Fallback exists when circuit is open
- [ ] **[BLOCKER]** Circuit breaker is per-dependency (not global)
- [ ] **[MAJOR]** Timeout configured appropriately for the service
- [ ] **[MAJOR]** Metrics/logging when state changes
- [ ] **[MINOR]** Half-open state allows limited requests

### Integration
- [ ] **[BLOCKER]** Used for network calls, not local operations
- [ ] **[MAJOR]** Combined with timeout (don't wait forever)
- [ ] **[MAJOR]** Fallback provides degraded functionality
- [ ] **[MINOR]** Dashboard/alerts for circuit state

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** No fallback when circuit opens (user sees error)
- [ ] **[BLOCKER]** Single circuit breaker for all services
- [ ] **[MAJOR]** Circuit breaker without timeout
- [ ] **[MAJOR]** Threshold too low (flapping) or too high (no protection)

## Common Mistakes

### 1. No Fallback
```java
// BAD: Circuit opens, error propagates
Payment process(Request req) {
    return circuitBreaker.execute(() -> paymentService.call(req));
    // When open, CallNotPermittedException thrown to user!
}

// GOOD: Graceful degradation
Payment process(Request req) {
    return Try.ofSupplier(
        CircuitBreaker.decorateSupplier(cb, () -> paymentService.call(req)))
        .recover(CallNotPermittedException.class, e -> queueForLater(req))
        .get();
}
```

### 2. Global Circuit Breaker
```java
// BAD: One circuit for all services
CircuitBreaker globalCb = CircuitBreaker.ofDefaults("global");

serviceA.call(globalCb);  // ServiceA failure
serviceB.call(globalCb);  // ...trips circuit for ServiceB too!

// GOOD: Per-service circuit breakers
CircuitBreaker cbA = CircuitBreaker.of("serviceA", configA);
CircuitBreaker cbB = CircuitBreaker.of("serviceB", configB);
```

### 3. Missing Timeout
```java
// BAD: Request hangs forever, eventually trips circuit
circuitBreaker.execute(() -> {
    return httpClient.get(url);  // No timeout!
});

// GOOD: Timeout + circuit breaker
circuitBreaker.execute(() -> {
    return httpClient.get(url, Duration.ofSeconds(5));
});
```

### 4. Threshold Too Sensitive
```java
// BAD: Trips on first failure
CircuitBreakerConfig.custom()
    .failureRateThreshold(1)  // One failure = open
    .minimumNumberOfCalls(1)
    .build();

// GOOD: Reasonable threshold
CircuitBreakerConfig.custom()
    .failureRateThreshold(50)   // 50% failure rate
    .minimumNumberOfCalls(10)   // After at least 10 calls
    .build();
```

## Combining with Other Patterns

### Circuit Breaker + Retry
```java
// Retry INSIDE circuit breaker
Retry retry = Retry.of("payment", RetryConfig.custom()
    .maxAttempts(3)
    .waitDuration(Duration.ofMillis(500))
    .build());

CircuitBreaker cb = CircuitBreaker.of("payment", config);

// Decorators compose from right to left
Supplier<Payment> supplier = Decorators.ofSupplier(() -> service.call())
    .withRetry(retry)          // Retry first
    .withCircuitBreaker(cb)    // Then circuit breaker
    .decorate();
// Each retry failure counts toward circuit breaker threshold
```

### Circuit Breaker + Bulkhead
```java
// Limit concurrent calls + circuit breaker
Bulkhead bulkhead = Bulkhead.of("payment", BulkheadConfig.custom()
    .maxConcurrentCalls(10)
    .maxWaitDuration(Duration.ofMillis(500))
    .build());

Supplier<Payment> supplier = Decorators.ofSupplier(() -> service.call())
    .withBulkhead(bulkhead)     // Limit concurrency
    .withCircuitBreaker(cb)     // Fail fast if unhealthy
    .decorate();
```

## Observability

Essential metrics to track:
- Circuit state changes (CLOSED→OPEN, OPEN→HALF_OPEN, etc.)
- Failure rate over time
- Number of rejected requests (when open)
- Recovery time (how long circuits stay open)

```java
// Resilience4j with Micrometer
CircuitBreaker cb = CircuitBreaker.of("payment", config);
TaggedCircuitBreakerMetrics.ofCircuitBreakerRegistry(registry)
    .bindTo(meterRegistry);

// Alerts
// - Alert when any circuit opens
// - Alert when circuit has been open > 5 minutes
// - Dashboard showing circuit states across services
```

## Testing Strategy

### What to Test
1. **State transitions**: CLOSED → OPEN → HALF-OPEN → CLOSED
2. **Threshold behavior**: Exact failure count that trips circuit
3. **Timeout expiration**: Circuit moves to half-open after timeout
4. **Recovery behavior**: Success in half-open closes circuit
5. **Fallback execution**: Fallback called when circuit is open

### How to Test

```java
// Java - Use a controllable time source
class CircuitBreakerTest {
    private TestClock clock;
    private CircuitBreaker cb;

    @BeforeEach
    void setup() {
        clock = new TestClock();
        cb = CircuitBreaker.builder()
            .clock(clock)
            .failureThreshold(3)
            .waitDuration(Duration.ofSeconds(30))
            .build();
    }

    @Test
    void shouldOpenAfterThresholdFailures() {
        // Fail 3 times
        repeat(3, () -> cb.execute(() -> { throw new IOException(); }));

        assertThat(cb.getState()).isEqualTo(State.OPEN);
    }

    @Test
    void shouldTransitionToHalfOpenAfterTimeout() {
        tripCircuit();
        assertThat(cb.getState()).isEqualTo(State.OPEN);

        clock.advance(Duration.ofSeconds(31));  // Past timeout

        assertThat(cb.getState()).isEqualTo(State.HALF_OPEN);
    }

    @Test
    void shouldCallFallbackWhenOpen() {
        tripCircuit();

        String result = cb.executeWithFallback(
            () -> externalService.call(),
            () -> "fallback"
        );

        assertThat(result).isEqualTo("fallback");
    }
}
```

```go
// Go - Use dependency injection for time
func TestCircuitBreaker_OpensAfterThreshold(t *testing.T) {
    cb := New(
        WithFailureThreshold(3),
        WithClock(mockClock),
    )

    // Simulate 3 failures
    for i := 0; i < 3; i++ {
        _ = cb.Execute(func() error { return errors.New("fail") })
    }

    if cb.State() != StateOpen {
        t.Errorf("expected OPEN, got %v", cb.State())
    }
}
```

### What to Mock
- **Time/Clock**: Control timeout expiration
- **External service**: Simulate failures and successes
- **Metrics collector**: Verify metrics are recorded

### Testing Anti-Patterns
- ❌ Using `time.Sleep()` in tests (flaky, slow)
- ❌ Testing implementation details (internal counters)
- ❌ Not testing the fallback path

## Often Composed With

| Pattern | Composition | Example |
|---------|-------------|---------|
| **Retry** | Retry inside CB; retries count toward threshold | `cb.execute(() -> retry.execute(service::call))` |
| **Timeout** | Timeout each call; CB aggregates timeouts as failures | Always set timeout < CB failure window |
| **Bulkhead** | Limit concurrency before CB check | `bulkhead.execute(() -> cb.execute(call))` |
| **Graceful Degradation** | CB open triggers degraded mode | Return cached/default data when open |
| **Health Check** | Separate health endpoint bypasses CB | Don't CB the health check itself |

### Composition Order (Right to Left)
```java
// Decorators compose right-to-left
Decorators.ofSupplier(service::call)
    .withRetry(retry)           // Innermost: retry transient failures
    .withCircuitBreaker(cb)     // Then: circuit breaker
    .withBulkhead(bulkhead)     // Outermost: limit concurrency
    .get();
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Retry** | Retry handles transient failures; Circuit Breaker prevents overload |
| **Timeout** | Timeout bounds individual calls; Circuit Breaker aggregates failures |
| **Bulkhead** | Bulkhead limits concurrency; Circuit Breaker stops requests entirely |
| **Fallback** | Always combine Circuit Breaker with fallback strategy |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Resilience4j](https://resilience4j.readme.io/) | Modern, lightweight, functional API. Recommended. |
| **Java** | [Failsafe](https://failsafe.dev/) | Lightweight, zero-dependency alternative |
| **Java** | [Spring Cloud Circuit Breaker](https://spring.io/projects/spring-cloud-circuitbreaker) | Abstraction over Resilience4j/Sentinel |
| **Go** | [sony/gobreaker](https://github.com/sony/gobreaker) | Simple, well-tested implementation |
| **Go** | [rubyist/circuitbreaker](https://github.com/rubyist/circuitbreaker) | Event-driven circuit breaker |
| **Python** | [pybreaker](https://pypi.org/project/pybreaker/) | Mature, thread-safe implementation |
| **Python** | [circuitbreaker](https://pypi.org/project/circuitbreaker/) | Decorator-based, async support |
| **JavaScript** | [opossum](https://github.com/nodeshift/opossum) | Feature-rich, Prometheus metrics |
| **JavaScript** | [cockatiel](https://github.com/connor4312/cockatiel) | Modern, TypeScript-first, composable policies |
| **Rust** | [failsafe-rs](https://github.com/dmexe/failsafe-rs) | Circuit breaker and rate limiter |

## References

- Michael Nygard, "Release It!" (2007, 2nd ed. 2018)
- Resilience4j: https://resilience4j.readme.io/
- Netflix Hystrix (deprecated, but influential): https://github.com/Netflix/Hystrix
- Martin Fowler: https://martinfowler.com/bliki/CircuitBreaker.html
