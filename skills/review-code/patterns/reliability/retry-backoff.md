# Retry with Exponential Backoff

> Automatically retry failed operations with increasing delays between attempts, preventing thundering herd and allowing transient failures to recover.

## Intent

Handle transient failures gracefully by retrying operations, with delays that prevent overwhelming a recovering service.

## When to Use

- Network calls that can experience transient failures
- Operations that are idempotent (safe to repeat)
- Rate-limited APIs
- Eventually consistent systems

## When NOT to Use

- Non-idempotent operations (without idempotency keys)
- Validation errors (4xx responses)
- Operations that should fail fast
- **CRITICAL**: Never retry non-idempotent writes without deduplication

## The Math

### Exponential Backoff Formula
```
delay = min(base * 2^attempt, max_delay)

Example with base=1s, max=32s:
Attempt 1: 1s  (1 * 2^0)
Attempt 2: 2s  (1 * 2^1)
Attempt 3: 4s  (1 * 2^2)
Attempt 4: 8s  (1 * 2^3)
Attempt 5: 16s (1 * 2^4)
Attempt 6: 32s (capped at max)
```

### With Jitter (Essential for Distributed Systems)
```
delay = random(0, min(cap, base * 2^attempt))

Why jitter?
Without jitter: 1000 clients retry at exactly t=1s, t=2s, t=4s...
With jitter:    1000 clients spread across [0,1s], [0,2s], [0,4s]...
```

**Always use jitter** - synchronized retries cause thundering herd.

## Language Examples

### Java (Resilience4j)

```java
// Configuration
RetryConfig config = RetryConfig.custom()
    .maxAttempts(5)
    .waitDuration(Duration.ofSeconds(1))
    .intervalFunction(IntervalFunction.ofExponentialBackoff(
        Duration.ofSeconds(1),    // Initial interval
        2,                        // Multiplier
        Duration.ofSeconds(30)    // Max interval
    ))
    .retryOnException(e -> e instanceof IOException)
    .retryOnResult(response -> response.getStatusCode() >= 500)
    .ignoreExceptions(ValidationException.class)  // Don't retry 4xx
    .build();

Retry retry = Retry.of("apiCall", config);

// Usage
String result = Retry.decorateSupplier(retry, () -> {
    return apiClient.fetchData();
}).get();

// With jitter (recommended)
RetryConfig withJitter = RetryConfig.custom()
    .maxAttempts(5)
    .intervalFunction(IntervalFunction.ofExponentialRandomBackoff(
        Duration.ofMillis(500),   // Initial
        2.0,                      // Multiplier
        0.5,                      // Randomization factor (±50%)
        Duration.ofSeconds(30)    // Max
    ))
    .build();
```

### Go

```go
package main

import (
    "context"
    "errors"
    "math"
    "math/rand"
    "time"
)

type RetryConfig struct {
    MaxAttempts int
    BaseDelay   time.Duration
    MaxDelay    time.Duration
    Multiplier  float64
    Jitter      float64 // 0.5 = ±50%
}

func DefaultConfig() RetryConfig {
    return RetryConfig{
        MaxAttempts: 5,
        BaseDelay:   time.Second,
        MaxDelay:    30 * time.Second,
        Multiplier:  2.0,
        Jitter:      0.5,
    }
}

func (c RetryConfig) delay(attempt int) time.Duration {
    delay := float64(c.BaseDelay) * math.Pow(c.Multiplier, float64(attempt))
    if delay > float64(c.MaxDelay) {
        delay = float64(c.MaxDelay)
    }

    // Add jitter
    if c.Jitter > 0 {
        jitter := delay * c.Jitter
        delay = delay - jitter + (rand.Float64() * 2 * jitter)
    }

    return time.Duration(delay)
}

func WithRetry[T any](
    ctx context.Context,
    cfg RetryConfig,
    shouldRetry func(error) bool,
    fn func() (T, error),
) (T, error) {
    var lastErr error
    var zero T

    for attempt := 0; attempt < cfg.MaxAttempts; attempt++ {
        result, err := fn()
        if err == nil {
            return result, nil
        }

        lastErr = err
        if !shouldRetry(err) {
            return zero, err
        }

        if attempt < cfg.MaxAttempts-1 {
            delay := cfg.delay(attempt)
            select {
            case <-ctx.Done():
                return zero, ctx.Err()
            case <-time.After(delay):
            }
        }
    }

    return zero, fmt.Errorf("max retries exceeded: %w", lastErr)
}

// Usage
func main() {
    ctx := context.Background()
    cfg := DefaultConfig()

    result, err := WithRetry(ctx, cfg,
        func(err error) bool {
            // Retry on network errors, not validation errors
            var netErr net.Error
            return errors.As(err, &netErr) && netErr.Temporary()
        },
        func() (string, error) {
            return apiClient.Fetch()
        },
    )
}
```

### Python

```python
import random
import time
from functools import wraps
from typing import Callable, TypeVar, Type

T = TypeVar('T')

def retry_with_backoff(
    max_attempts: int = 5,
    base_delay: float = 1.0,
    max_delay: float = 30.0,
    multiplier: float = 2.0,
    jitter: float = 0.5,
    retryable_exceptions: tuple[Type[Exception], ...] = (Exception,),
):
    """
    Decorator for retry with exponential backoff and jitter.

    Args:
        max_attempts: Maximum number of attempts
        base_delay: Initial delay in seconds
        max_delay: Maximum delay in seconds
        multiplier: Delay multiplier per attempt
        jitter: Random factor (0.5 = ±50%)
        retryable_exceptions: Exceptions that trigger retry
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        def wrapper(*args, **kwargs) -> T:
            last_exception = None

            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except retryable_exceptions as e:
                    last_exception = e

                    if attempt < max_attempts - 1:
                        delay = min(base_delay * (multiplier ** attempt), max_delay)

                        # Add jitter
                        if jitter > 0:
                            jitter_range = delay * jitter
                            delay = delay - jitter_range + (random.random() * 2 * jitter_range)

                        time.sleep(delay)

            raise last_exception

        return wrapper
    return decorator


# Usage
@retry_with_backoff(
    max_attempts=5,
    base_delay=1.0,
    retryable_exceptions=(ConnectionError, TimeoutError),
)
def fetch_data(url: str) -> dict:
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()


# Async version
import asyncio

async def retry_async(
    func: Callable[..., T],
    *args,
    max_attempts: int = 5,
    base_delay: float = 1.0,
    **kwargs,
) -> T:
    for attempt in range(max_attempts):
        try:
            return await func(*args, **kwargs)
        except Exception as e:
            if attempt < max_attempts - 1:
                delay = base_delay * (2 ** attempt)
                delay *= (0.5 + random.random())  # Jitter
                await asyncio.sleep(delay)
            else:
                raise
```

## Review Checklist

### Correct Implementation
- [ ] **[BLOCKER]** Operation is idempotent (or has idempotency key)
- [ ] **[BLOCKER]** Jitter is used (prevents thundering herd)
- [ ] **[MAJOR]** Maximum delay is capped
- [ ] **[MAJOR]** Non-retryable errors are not retried (4xx, validation)
- [ ] **[MAJOR]** Context/timeout respected (don't retry forever)

### Configuration
- [ ] **[MAJOR]** Reasonable max attempts (3-5 typical)
- [ ] **[MAJOR]** Base delay appropriate for service (~1s for APIs)
- [ ] **[MINOR]** Exponential growth, not linear
- [ ] **[MINOR]** Logging of retry attempts

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Retrying non-idempotent operations without deduplication
- [ ] **[BLOCKER]** No jitter (all clients retry simultaneously)
- [ ] **[MAJOR]** Retrying client errors (400, 401, 403, 404)
- [ ] **[MAJOR]** No maximum delay (unbounded growth)
- [ ] **[MAJOR]** Ignoring cancellation/timeout during backoff

## Common Mistakes

### 1. No Jitter (Thundering Herd)
```python
# BAD: All clients retry at exactly the same times
delay = base * (2 ** attempt)

# GOOD: Spread retries randomly
delay = base * (2 ** attempt)
delay *= (0.5 + random.random())  # ±50% jitter
```

### 2. Retrying Non-Idempotent Operations
```java
// BAD: Payment might be charged multiple times!
@Retry
public void processPayment(Payment payment) {
    paymentGateway.charge(payment);
}

// GOOD: Use idempotency key
@Retry
public void processPayment(Payment payment) {
    paymentGateway.charge(payment.getId(), payment);  // Gateway deduplicates
}

// Or make it idempotent
public void processPayment(Payment payment) {
    if (paymentRepository.exists(payment.getId())) {
        return;  // Already processed
    }
    paymentGateway.charge(payment);
    paymentRepository.save(payment);
}
```

### 3. Retrying Client Errors
```java
// BAD: Retrying 4xx errors that will never succeed
.retryOnException(e -> e instanceof HttpException)

// GOOD: Only retry server/network errors
.retryOnException(e -> {
    if (e instanceof HttpException http) {
        return http.getStatusCode() >= 500;  // Only 5xx
    }
    return e instanceof IOException;  // Network errors
})
```

### 4. Unbounded Retry
```go
// BAD: Could retry forever
for {
    err := doWork()
    if err == nil {
        break
    }
    time.Sleep(time.Second)
}

// GOOD: Bounded with context
ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
defer cancel()

for attempt := 0; attempt < maxAttempts; attempt++ {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
        if err := doWork(); err == nil {
            return nil
        }
        time.Sleep(delay)
    }
}
```

## What to Retry

| Retry | Don't Retry |
|-------|-------------|
| 500 Internal Server Error | 400 Bad Request |
| 502 Bad Gateway | 401 Unauthorized |
| 503 Service Unavailable | 403 Forbidden |
| 504 Gateway Timeout | 404 Not Found |
| Connection timeout | 422 Validation Error |
| Connection reset | Business logic errors |
| DNS resolution failure | Malformed request |
| Rate limited (429) with Retry-After | |

## Combining with Circuit Breaker

```java
// Retry INSIDE circuit breaker
// Retries happen first, then circuit breaker counts success/failure

Retry retry = Retry.of("api", retryConfig);
CircuitBreaker cb = CircuitBreaker.of("api", cbConfig);

Supplier<Response> decorated = Decorators.ofSupplier(() -> api.call())
    .withRetry(retry)           // Inner: retry transient failures
    .withCircuitBreaker(cb)     // Outer: track overall health
    .decorate();

// All retry attempts count as ONE call to circuit breaker
// If all retries fail, circuit breaker records ONE failure
```

## AWS/GCP SDK Best Practices

Most cloud SDKs have built-in retry - don't add another layer:

```java
// AWS SDK v2 - has intelligent retry built in
S3Client s3 = S3Client.builder()
    .overrideConfiguration(c -> c
        .retryPolicy(RetryPolicy.builder()
            .numRetries(5)
            .build()))
    .build();

// Google Cloud - also has retry built in
Storage storage = StorageOptions.newBuilder()
    .setRetrySettings(RetrySettings.newBuilder()
        .setMaxAttempts(5)
        .setInitialRetryDelay(Duration.ofSeconds(1))
        .setRetryDelayMultiplier(2.0)
        .setMaxRetryDelay(Duration.ofSeconds(30))
        .build())
    .build()
    .getService();
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Circuit Breaker** | Stops retrying when service is unhealthy |
| **Timeout** | Bounds individual attempts |
| **Idempotency** | Required for safe retries |
| **Queue** | Alternative: queue for later processing |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Resilience4j Retry](https://resilience4j.readme.io/docs/retry) | Configurable, composable with other policies |
| **Java** | [Failsafe](https://failsafe.dev/) | Retry, circuit breaker, bulkhead in one |
| **Java** | [Spring Retry](https://github.com/spring-projects/spring-retry) | `@Retryable` annotation support |
| **Go** | [cenkalti/backoff](https://github.com/cenkalti/backoff) | Exponential backoff with jitter |
| **Go** | [avast/retry-go](https://github.com/avast/retry-go) | Simple, functional retry library |
| **Go** | [sethvargo/go-retry](https://github.com/sethvargo/go-retry) | Context-aware, pluggable backoff |
| **Python** | [tenacity](https://github.com/jd/tenacity) | Feature-rich, async support, decorator API |
| **Python** | [backoff](https://github.com/litl/backoff) | Decorator-based exponential backoff |
| **Python** | [stamina](https://github.com/hynek/stamina) | Production-ready, opinionated defaults |
| **JavaScript** | [p-retry](https://github.com/sindresorhus/p-retry) | Promise-based retry with exponential backoff |
| **JavaScript** | [cockatiel](https://github.com/connor4312/cockatiel) | Retry, circuit breaker, bulkhead |
| **JavaScript** | [async-retry](https://github.com/vercel/async-retry) | Simple async retry by Vercel |
| **Rust** | [backoff](https://crates.io/crates/backoff) | Exponential backoff and retry |

## References

- AWS Architecture Blog: "Exponential Backoff and Jitter"
- Google Cloud: "Retry Strategy"
- Resilience4j Retry documentation
- "Release It!" by Michael Nygard
