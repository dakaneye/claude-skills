# Idempotency Pattern

> An operation that produces the same result regardless of how many times it is performed.

**Source**: Mathematical concept applied to distributed systems

## Intent

Design operations so that executing them multiple times has the same effect as executing them once. This enables safe retries and simplifies handling of duplicate messages in distributed systems.

## Key Concepts

- **Idempotent Operation**: Multiple calls produce same result as one call
- **Idempotency Key**: Unique identifier for detecting duplicate requests
- **At-Least-Once Delivery**: Messages may be delivered multiple times
- **Exactly-Once Semantics**: Achieved via idempotency + deduplication

## Why Idempotency Matters

```
Without Idempotency:
Client ─────► Server: "Charge $100"
       ◄───── Server: (timeout, no response)
Client ─────► Server: "Charge $100" (retry)
       ◄───── Server: "OK"

Result: Customer charged $200! 💸

With Idempotency:
Client ─────► Server: "Charge $100 (key: abc123)"
       ◄───── Server: (timeout, no response)
Client ─────► Server: "Charge $100 (key: abc123)" (retry)
       ◄───── Server: "OK" (same as first request)

Result: Customer charged $100 ✓
```

## Naturally Idempotent Operations

| Operation | Idempotent? | Example |
|-----------|-------------|---------|
| GET | ✓ Yes | Fetch user profile |
| PUT | ✓ Yes | Set balance to $100 |
| DELETE | ✓ Yes | Delete user 123 |
| POST (create) | ✗ No | Create order |
| POST (action) | ✗ No | Charge payment |
| PATCH (delta) | ✗ No | Add $10 to balance |

## Language Examples

### Java

```java
// Idempotency key storage
@Entity
@Table(name = "idempotency_keys")
public class IdempotencyRecord {
    @Id
    private String key;

    @Column(columnDefinition = "jsonb")
    private String response;

    @Column(name = "created_at")
    private Instant createdAt;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Enumerated(EnumType.STRING)
    private Status status;  // PROCESSING, COMPLETED, FAILED

    public enum Status {
        PROCESSING, COMPLETED, FAILED
    }
}

@Repository
public interface IdempotencyRepository extends JpaRepository<IdempotencyRecord, String> {
    @Modifying
    @Query("DELETE FROM IdempotencyRecord r WHERE r.expiresAt < :now")
    int deleteExpired(@Param("now") Instant now);
}

// Idempotency service
@Service
public class IdempotencyService {
    private final IdempotencyRepository repository;
    private final ObjectMapper objectMapper;
    private final Duration keyTTL = Duration.ofHours(24);

    /**
     * Execute an operation idempotently.
     *
     * @param key Unique idempotency key
     * @param operation The operation to execute
     * @param responseType Type of the response
     * @return The response (either from cache or from executing the operation)
     */
    @Transactional
    public <T> T executeIdempotent(
            String key,
            Supplier<T> operation,
            Class<T> responseType) {

        // Check for existing record
        Optional<IdempotencyRecord> existing = repository.findById(key);

        if (existing.isPresent()) {
            IdempotencyRecord record = existing.get();

            switch (record.getStatus()) {
                case COMPLETED:
                    // Return cached response
                    return deserialize(record.getResponse(), responseType);

                case PROCESSING:
                    // Request in progress - conflict
                    throw new ConflictException("Request already in progress: " + key);

                case FAILED:
                    // Previous attempt failed - allow retry
                    break;
            }
        }

        // Create or update record as PROCESSING
        IdempotencyRecord record = existing.orElse(new IdempotencyRecord());
        record.setKey(key);
        record.setStatus(IdempotencyRecord.Status.PROCESSING);
        record.setCreatedAt(Instant.now());
        record.setExpiresAt(Instant.now().plus(keyTTL));
        repository.save(record);

        try {
            // Execute the operation
            T result = operation.get();

            // Store successful result
            record.setResponse(serialize(result));
            record.setStatus(IdempotencyRecord.Status.COMPLETED);
            repository.save(record);

            return result;
        } catch (Exception e) {
            // Mark as failed
            record.setStatus(IdempotencyRecord.Status.FAILED);
            record.setResponse(serialize(new ErrorResponse(e.getMessage())));
            repository.save(record);
            throw e;
        }
    }

    private <T> String serialize(T object) {
        try {
            return objectMapper.writeValueAsString(object);
        } catch (JsonProcessingException e) {
            throw new RuntimeException("Serialization failed", e);
        }
    }

    private <T> T deserialize(String json, Class<T> type) {
        try {
            return objectMapper.readValue(json, type);
        } catch (JsonProcessingException e) {
            throw new RuntimeException("Deserialization failed", e);
        }
    }
}

// Usage in API
@RestController
@RequestMapping("/api/payments")
public class PaymentController {
    private final IdempotencyService idempotencyService;
    private final PaymentService paymentService;

    @PostMapping
    public ResponseEntity<PaymentResponse> createPayment(
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @Valid @RequestBody PaymentRequest request) {

        PaymentResponse response = idempotencyService.executeIdempotent(
            idempotencyKey,
            () -> paymentService.processPayment(request),
            PaymentResponse.class
        );

        return ResponseEntity.ok(response);
    }
}

// Making a POST operation idempotent with unique business key
@Service
public class OrderService {

    @Transactional
    public Order createOrder(CreateOrderCommand command) {
        // Generate deterministic order ID from business key
        String orderKey = generateOrderKey(
            command.getCustomerId(),
            command.getCartId(),
            command.getTimestamp()
        );

        // Check if order already exists
        Optional<Order> existing = orderRepository.findByOrderKey(orderKey);
        if (existing.isPresent()) {
            return existing.get();  // Return existing order (idempotent)
        }

        // Create new order
        Order order = Order.create(command);
        order.setOrderKey(orderKey);
        return orderRepository.save(order);
    }

    private String generateOrderKey(CustomerId customerId, CartId cartId, Instant timestamp) {
        // Deterministic key based on business data
        return String.format("%s:%s:%d",
            customerId.getValue(),
            cartId.getValue(),
            timestamp.toEpochMilli()
        );
    }
}
```

### Go

```go
// Idempotency record
type IdempotencyRecord struct {
    Key       string
    Response  []byte
    Status    string // "processing", "completed", "failed"
    CreatedAt time.Time
    ExpiresAt time.Time
}

// Idempotency service
type IdempotencyService struct {
    db     *sql.DB
    keyTTL time.Duration
}

func NewIdempotencyService(db *sql.DB) *IdempotencyService {
    return &IdempotencyService{
        db:     db,
        keyTTL: 24 * time.Hour,
    }
}

func (s *IdempotencyService) Execute(ctx context.Context, key string, operation func() (any, error)) ([]byte, error) {
    // Try to get existing record
    record, err := s.getRecord(ctx, key)
    if err != nil && !errors.Is(err, sql.ErrNoRows) {
        return nil, fmt.Errorf("get record: %w", err)
    }

    if record != nil {
        switch record.Status {
        case "completed":
            return record.Response, nil
        case "processing":
            return nil, ErrRequestInProgress
        case "failed":
            // Allow retry
        }
    }

    // Create or update record as processing
    if err := s.upsertProcessing(ctx, key); err != nil {
        // Handle race condition - another request beat us
        if isUniqueViolation(err) {
            return nil, ErrRequestInProgress
        }
        return nil, fmt.Errorf("upsert processing: %w", err)
    }

    // Execute operation
    result, err := operation()
    if err != nil {
        // Mark as failed
        _ = s.markFailed(ctx, key, err.Error())
        return nil, err
    }

    // Serialize and store result
    response, err := json.Marshal(result)
    if err != nil {
        return nil, fmt.Errorf("marshal result: %w", err)
    }

    if err := s.markCompleted(ctx, key, response); err != nil {
        return nil, fmt.Errorf("mark completed: %w", err)
    }

    return response, nil
}

func (s *IdempotencyService) upsertProcessing(ctx context.Context, key string) error {
    _, err := s.db.ExecContext(ctx, `
        INSERT INTO idempotency_keys (key, status, created_at, expires_at)
        VALUES ($1, 'processing', NOW(), NOW() + $2::interval)
        ON CONFLICT (key) DO UPDATE
        SET status = 'processing'
        WHERE idempotency_keys.status = 'failed'
    `, key, s.keyTTL.String())
    return err
}

func (s *IdempotencyService) markCompleted(ctx context.Context, key string, response []byte) error {
    _, err := s.db.ExecContext(ctx, `
        UPDATE idempotency_keys
        SET status = 'completed', response = $2
        WHERE key = $1
    `, key, response)
    return err
}

// HTTP middleware
func IdempotencyMiddleware(idempotency *IdempotencyService) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Only apply to POST/PUT/PATCH
            if r.Method != http.MethodPost && r.Method != http.MethodPut && r.Method != http.MethodPatch {
                next.ServeHTTP(w, r)
                return
            }

            key := r.Header.Get("Idempotency-Key")
            if key == "" {
                next.ServeHTTP(w, r)
                return
            }

            // Wrap response writer to capture response
            recorder := &responseRecorder{ResponseWriter: w, statusCode: http.StatusOK}

            // Execute with idempotency
            response, err := idempotency.Execute(r.Context(), key, func() (any, error) {
                next.ServeHTTP(recorder, r)
                if recorder.statusCode >= 400 {
                    return nil, fmt.Errorf("request failed with status %d", recorder.statusCode)
                }
                return recorder.body.Bytes(), nil
            })

            if err != nil {
                if errors.Is(err, ErrRequestInProgress) {
                    http.Error(w, "Request in progress", http.StatusConflict)
                    return
                }
                // Let the original error response through
                return
            }

            w.Write(response)
        })
    }
}

// Making operations idempotent with business keys
type OrderService struct {
    repo OrderRepository
}

func (s *OrderService) CreateOrder(ctx context.Context, cmd CreateOrderCommand) (*Order, error) {
    // Generate deterministic key from business data
    orderKey := fmt.Sprintf("%s:%s:%d",
        cmd.CustomerID,
        cmd.CartID,
        cmd.Timestamp.UnixMilli(),
    )

    // Check for existing order
    existing, err := s.repo.FindByKey(ctx, orderKey)
    if err != nil && !errors.Is(err, ErrNotFound) {
        return nil, fmt.Errorf("find existing: %w", err)
    }
    if existing != nil {
        return existing, nil // Idempotent return
    }

    // Create new order
    order := &Order{
        ID:        uuid.New().String(),
        Key:       orderKey,
        CustomerID: cmd.CustomerID,
        Items:     cmd.Items,
        CreatedAt: time.Now(),
    }

    if err := s.repo.Create(ctx, order); err != nil {
        // Handle race condition
        if isUniqueViolation(err) {
            return s.repo.FindByKey(ctx, orderKey)
        }
        return nil, fmt.Errorf("create order: %w", err)
    }

    return order, nil
}
```

## Idempotency Key Strategies

### 1. Client-Generated UUID
```
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

### 2. Business Key Hash
```java
String key = sha256(customerId + ":" + cartId + ":" + timestamp);
```

### 3. Request Content Hash
```java
String key = sha256(objectMapper.writeValueAsString(request));
```

## Review Checklist

### Design
- [ ] **[BLOCKER]** State-changing operations have idempotency keys
- [ ] **[MAJOR]** Keys have appropriate TTL (not too short, not forever)
- [ ] **[MAJOR]** Concurrent duplicate handling (409 Conflict)
- [ ] **[MINOR]** Failed requests allow retry

### Implementation
- [ ] **[BLOCKER]** Key checked BEFORE operation starts
- [ ] **[BLOCKER]** Response cached with the key
- [ ] **[MAJOR]** Atomic record creation (handle race conditions)
- [ ] **[MINOR]** Old keys are expired/cleaned up

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Idempotency check after operation starts
- [ ] **[MAJOR]** Using non-deterministic keys (random per retry)
- [ ] **[MAJOR]** No handling for "processing" state
- [ ] **[MINOR]** Keys never expire (table grows forever)

## Common Mistakes

### 1. Checking After Operation
```java
// BAD: Check after operation - already charged twice!
paymentGateway.charge(amount);
if (idempotencyStore.exists(key)) {
    return cachedResult;
}

// GOOD: Check before operation
if (idempotencyStore.exists(key)) {
    return cachedResult;
}
idempotencyStore.markProcessing(key);
paymentGateway.charge(amount);
idempotencyStore.markCompleted(key, result);
```

### 2. Non-Deterministic Keys
```java
// BAD: New UUID each retry - defeats the purpose
String key = UUID.randomUUID().toString();

// GOOD: Same key for same logical request
String key = request.getClientGeneratedKey();
// or
String key = hash(customerId + orderId + timestamp);
```

### 3. Ignoring Race Conditions
```java
// BAD: Race condition between check and insert
if (!exists(key)) {
    // Another thread can insert here!
    insert(key, "processing");
}

// GOOD: Atomic upsert
INSERT INTO keys (key, status)
VALUES (?, 'processing')
ON CONFLICT (key) DO NOTHING
RETURNING *;  -- Returns null if conflict
```

## HTTP API Design

```
Request:
POST /api/payments HTTP/1.1
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json

{ "amount": 100, "currency": "USD" }

First Response (or any retry):
HTTP/1.1 200 OK
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000

{ "payment_id": "pay_123", "status": "completed" }

Concurrent Request (same key):
HTTP/1.1 409 Conflict

{ "error": "Request with this idempotency key is already in progress" }
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Retry** | Idempotency makes retries safe |
| **Outbox** | Ensures idempotent event publishing |
| **Deduplication** | Consumer-side idempotency |
| **Exactly-Once Delivery** | Requires idempotency + dedup |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Retry](https://github.com/spring-projects/spring-retry) | `@Retryable` with idempotent semantics |
| **Java** | [Axon Framework](https://www.axoniq.io/) | Command idempotency via aggregate identifiers |
| **Go** | [ksuid](https://github.com/segmentio/ksuid) | K-Sortable UIDs for idempotency keys |
| **Go** | [hashicorp/go-memdb](https://github.com/hashicorp/go-memdb) | In-memory deduplication store |
| **Python** | [idempotence](https://pypi.org/project/idempotence/) | Decorators for idempotent functions |
| **Python** | [aws-lambda-powertools](https://awslabs.github.io/aws-lambda-powertools-python/) | Built-in idempotency handler |
| **JavaScript** | [idempotent-request](https://www.npmjs.com/package/idempotent-request) | Express middleware for idempotency |
| **AWS** | [Lambda Powertools](https://docs.powertools.aws.dev/lambda/python/latest/utilities/idempotency/) | Native idempotency for Lambda (Python, Java, TypeScript) |
| **Multi** | [Redis](https://redis.io/) | Often used as idempotency key store with TTL |

**Note**: Most idempotency implementations are custom due to application-specific storage and key strategies. Libraries help with key generation and storage patterns.

## References

- Stripe API Idempotency: https://stripe.com/docs/api/idempotent_requests
- AWS Lambda Idempotency: https://docs.aws.amazon.com/lambda/latest/operatorguide/idempotency.html
- Martin Kleppmann, "Designing Data-Intensive Applications" Chapter 11
