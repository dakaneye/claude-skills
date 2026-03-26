# Graceful Degradation

> When components fail, the system continues to function with reduced capability rather than failing completely.

**Source**: Michael Nygard, "Release It!" (2007, 2018)

## Intent

Design systems to maintain partial functionality when dependencies fail. Provide a degraded but useful experience rather than complete failure.

## Key Concepts

- **Partial Availability**: Some features work even when others don't
- **Fallback**: Alternative behavior when primary fails
- **Priority**: Protect critical functionality over non-critical
- **User Experience**: Communicate degraded state to users

## Structure

```
Normal Operation:
┌────────┐    ┌────────┐    ┌────────┐
│ Feature│───►│Feature │───►│Feature │  All features work
│   A    │    │   B    │    │   C    │
└────────┘    └────────┘    └────────┘
    ✓             ✓             ✓

Degraded Operation (Feature B fails):
┌────────┐    ┌────────┐    ┌────────┐
│ Feature│    │Feature │    │Feature │
│   A    │    │   B    │    │   C    │
└────────┘    └────────┘    └────────┘
    ✓             ✗             ✓
                  │
            ┌─────▼─────┐
            │ Fallback  │
            │  (cached  │
            │   data)   │
            └───────────┘
```

## When to Use

- External dependencies can fail
- System has critical and non-critical features
- Partial functionality is better than no functionality
- User experience matters during failures

## When NOT to Use

- All-or-nothing operations (transactions)
- Security-critical features that can't degrade
- When degraded state could cause data corruption

## Degradation Strategies

### 1. Cached Data
Return stale cached data when live data unavailable.

### 2. Default Values
Return safe defaults when service unavailable.

### 3. Feature Disable
Disable non-critical features to preserve critical ones.

### 4. Simplified Response
Return simplified response without enrichment data.

### 5. Queue for Later
Accept request and process asynchronously when service recovers.

## Language Examples

### Java

```java
// Product service with graceful degradation
@Service
public class ProductService {
    private final ProductRepository productRepository;
    private final RecommendationClient recommendationClient;
    private final InventoryClient inventoryClient;
    private final PriceClient priceClient;
    private final Cache<String, ProductDetail> productCache;

    public ProductDetail getProduct(String productId) {
        // Core data (required)
        Product product = productRepository.findById(productId)
            .orElseThrow(() -> new ProductNotFoundException(productId));

        ProductDetail.Builder builder = ProductDetail.builder()
            .id(product.getId())
            .name(product.getName())
            .description(product.getDescription());

        // Enrichments (optional, can degrade)
        enrichWithPrice(builder, productId);
        enrichWithInventory(builder, productId);
        enrichWithRecommendations(builder, productId);

        return builder.build();
    }

    private void enrichWithPrice(ProductDetail.Builder builder, String productId) {
        try {
            PriceInfo price = priceClient.getPrice(productId);
            builder.price(price.getAmount())
                   .currency(price.getCurrency())
                   .discount(price.getDiscount());
        } catch (ServiceException e) {
            log.warn("Price service unavailable for product {}, using cached price", productId);
            // Fallback to cached price
            getCachedPrice(productId).ifPresentOrElse(
                cached -> builder.price(cached.getAmount())
                                .currency(cached.getCurrency())
                                .priceStale(true),  // Indicate stale data
                () -> builder.priceUnavailable(true)
            );
        }
    }

    private void enrichWithInventory(ProductDetail.Builder builder, String productId) {
        try {
            InventoryStatus status = inventoryClient.getStatus(productId);
            builder.inStock(status.isAvailable())
                   .quantity(status.getQuantity());
        } catch (ServiceException e) {
            log.warn("Inventory service unavailable for product {}", productId);
            // Degrade: show as "Check availability" instead of stock status
            builder.inventoryUnknown(true);
        }
    }

    private void enrichWithRecommendations(ProductDetail.Builder builder, String productId) {
        try {
            List<Product> recommendations = recommendationClient.getRecommendations(productId);
            builder.recommendations(recommendations);
        } catch (ServiceException e) {
            log.info("Recommendation service unavailable for product {}", productId);
            // Degrade: no recommendations shown
            builder.recommendations(Collections.emptyList());
        }
    }
}

// Feature flags for degradation control
@Component
public class FeatureDegradationController {
    private final FeatureFlagClient featureFlags;

    public boolean isFeatureEnabled(String featureName) {
        try {
            return featureFlags.isEnabled(featureName);
        } catch (Exception e) {
            // If feature flag service is down, default to safe value
            return getDefaultForFeature(featureName);
        }
    }

    private boolean getDefaultForFeature(String featureName) {
        return switch (featureName) {
            case "recommendations" -> false;     // Non-critical, disable
            case "checkout" -> true;              // Critical, enable
            case "reviews" -> false;              // Non-critical, disable
            case "search" -> true;                // Critical, enable
            default -> false;                     // Unknown, disable
        };
    }
}

// Circuit breaker with fallback
@Service
public class PaymentService {
    private final PaymentGateway primaryGateway;
    private final PaymentGateway backupGateway;
    private final CircuitBreaker circuitBreaker;

    public PaymentResult processPayment(PaymentRequest request) {
        // Try primary gateway with circuit breaker
        try {
            return circuitBreaker.executeSupplier(() ->
                primaryGateway.charge(request)
            );
        } catch (CallNotPermittedException e) {
            // Circuit is open - primary is failing
            log.warn("Primary payment gateway circuit open, trying backup");
            return backupGateway.charge(request);
        } catch (Exception e) {
            log.error("Primary payment failed, trying backup", e);
            return backupGateway.charge(request);
        }
    }
}

// Async degradation - queue for later
@Service
public class NotificationService {
    private final EmailClient emailClient;
    private final NotificationQueue notificationQueue;

    public void sendOrderConfirmation(Order order) {
        try {
            emailClient.send(buildConfirmationEmail(order));
        } catch (ServiceException e) {
            log.warn("Email service unavailable, queueing for later");
            // Queue for retry when service recovers
            notificationQueue.enqueue(new PendingNotification(
                NotificationType.ORDER_CONFIRMATION,
                order.getId(),
                Instant.now().plus(Duration.ofMinutes(5))  // Retry in 5 min
            ));
        }
    }
}
```

### Go

```go
// Product service with graceful degradation
type ProductService struct {
    repo            ProductRepository
    prices          PriceClient
    inventory       InventoryClient
    recommendations RecommendationClient
    cache           *cache.Cache
    logger          *slog.Logger
}

type ProductDetail struct {
    ID                string
    Name              string
    Description       string
    Price             *Money
    PriceStale        bool
    PriceUnavailable  bool
    InStock           *bool
    InventoryUnknown  bool
    Recommendations   []Product
}

func (s *ProductService) GetProduct(ctx context.Context, productID string) (*ProductDetail, error) {
    // Core data (required - no degradation)
    product, err := s.repo.FindByID(ctx, productID)
    if err != nil {
        return nil, fmt.Errorf("find product: %w", err)
    }

    detail := &ProductDetail{
        ID:          product.ID,
        Name:        product.Name,
        Description: product.Description,
    }

    // Enrichments (optional, can degrade)
    // Run in parallel with independent timeout
    var wg sync.WaitGroup
    wg.Add(3)

    go func() {
        defer wg.Done()
        s.enrichWithPrice(ctx, detail, productID)
    }()

    go func() {
        defer wg.Done()
        s.enrichWithInventory(ctx, detail, productID)
    }()

    go func() {
        defer wg.Done()
        s.enrichWithRecommendations(ctx, detail, productID)
    }()

    wg.Wait()
    return detail, nil
}

func (s *ProductService) enrichWithPrice(ctx context.Context, detail *ProductDetail, productID string) {
    ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
    defer cancel()

    price, err := s.prices.GetPrice(ctx, productID)
    if err != nil {
        s.logger.Warn("price service unavailable, using cache",
            "product_id", productID,
            "error", err,
        )

        // Try cache
        if cached, ok := s.cache.Get("price:" + productID); ok {
            detail.Price = cached.(*Money)
            detail.PriceStale = true
            return
        }

        detail.PriceUnavailable = true
        return
    }

    detail.Price = price
}

func (s *ProductService) enrichWithInventory(ctx context.Context, detail *ProductDetail, productID string) {
    ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
    defer cancel()

    status, err := s.inventory.GetStatus(ctx, productID)
    if err != nil {
        s.logger.Warn("inventory service unavailable",
            "product_id", productID,
            "error", err,
        )
        detail.InventoryUnknown = true
        return
    }

    detail.InStock = &status.Available
}

func (s *ProductService) enrichWithRecommendations(ctx context.Context, detail *ProductDetail, productID string) {
    ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
    defer cancel()

    recs, err := s.recommendations.Get(ctx, productID)
    if err != nil {
        s.logger.Info("recommendation service unavailable",
            "product_id", productID,
            "error", err,
        )
        detail.Recommendations = []Product{} // Empty, not nil
        return
    }

    detail.Recommendations = recs
}

// Feature degradation controller
type DegradationController struct {
    flags         FeatureFlagClient
    defaultStates map[string]bool
}

func NewDegradationController(flags FeatureFlagClient) *DegradationController {
    return &DegradationController{
        flags: flags,
        defaultStates: map[string]bool{
            "recommendations": false, // Non-critical, disable when unknown
            "checkout":        true,  // Critical, enable when unknown
            "reviews":         false,
            "search":          true,
        },
    }
}

func (c *DegradationController) IsEnabled(ctx context.Context, feature string) bool {
    enabled, err := c.flags.IsEnabled(ctx, feature)
    if err != nil {
        // Service unavailable, use safe default
        if defaultVal, ok := c.defaultStates[feature]; ok {
            return defaultVal
        }
        return false // Unknown features disabled by default
    }
    return enabled
}

// Queue for later processing
type NotificationService struct {
    email  EmailClient
    queue  NotificationQueue
    logger *slog.Logger
}

func (s *NotificationService) SendOrderConfirmation(ctx context.Context, order *Order) {
    err := s.email.Send(ctx, buildConfirmationEmail(order))
    if err != nil {
        s.logger.Warn("email service unavailable, queueing for later",
            "order_id", order.ID,
            "error", err,
        )

        // Queue for retry
        s.queue.Enqueue(ctx, PendingNotification{
            Type:      NotificationTypeOrderConfirmation,
            OrderID:   order.ID,
            ScheduledFor: time.Now().Add(5 * time.Minute),
        })
    }
}
```

## Response Design for Degradation

```json
// Normal response
{
  "product": {
    "id": "123",
    "name": "Widget",
    "price": 29.99,
    "inStock": true,
    "recommendations": ["456", "789"]
  }
}

// Degraded response (with indicators)
{
  "product": {
    "id": "123",
    "name": "Widget",
    "price": 29.99,
    "priceStale": true,        // Indicates cached price
    "inventoryUnknown": true,  // Can't determine stock
    "recommendations": []       // Service unavailable
  },
  "degraded": {
    "services": ["inventory", "recommendations"],
    "message": "Some information may be incomplete"
  }
}
```

## Review Checklist

### Design
- [ ] **[BLOCKER]** Critical vs non-critical features identified
- [ ] **[MAJOR]** Fallback strategy defined for each dependency
- [ ] **[MAJOR]** Degraded state communicated to users
- [ ] **[MINOR]** Degradation metrics tracked

### Implementation
- [ ] **[BLOCKER]** Critical path protected from non-critical failures
- [ ] **[MAJOR]** Timeouts on all optional enrichments
- [ ] **[MAJOR]** Cached fallbacks where appropriate
- [ ] **[MINOR]** Feature flags for manual degradation

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Non-critical failure causes complete failure
- [ ] **[MAJOR]** Silent degradation (user not informed)
- [ ] **[MAJOR]** Stale data served as fresh
- [ ] **[MINOR]** No recovery mechanism from degraded state

## Common Mistakes

### 1. All-or-Nothing Failure
```java
// BAD: One failure breaks everything
public ProductDetail getProduct(String id) {
    Product product = productRepo.findById(id);
    Price price = priceService.getPrice(id);      // If this fails...
    Inventory inv = inventoryService.get(id);     // ...this never runs
    return new ProductDetail(product, price, inv);
}

// GOOD: Independent enrichment with fallback
public ProductDetail getProduct(String id) {
    Product product = productRepo.findById(id);

    Price price = safeGetPrice(id);
    Inventory inv = safeGetInventory(id);

    return new ProductDetail(product, price, inv);
}
```

### 2. Silent Degradation
```java
// BAD: User thinks price is current but it's stale
builder.price(cachedPrice);

// GOOD: Indicate stale data
builder.price(cachedPrice)
       .priceLastUpdated(cachedAt)
       .priceStale(true);
```

### 3. No Recovery
```java
// BAD: Once degraded, never recovers
if (serviceDown) {
    return cachedData;  // Forever?
}

// GOOD: Periodic retry with circuit breaker
return circuitBreaker.executeSupplier(() -> {
    return liveService.getData();
}).onFailure(e -> {
    return cachedData;  // Temporary fallback
});
```

## Degradation Levels

| Level | Description | Example |
|-------|-------------|---------|
| **Full** | All features working | Normal operation |
| **Partial** | Non-critical disabled | No recommendations |
| **Minimal** | Only critical features | View only, no purchase |
| **Maintenance** | Read-only mode | Browse catalog only |
| **Emergency** | Static content only | Cached pages |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Circuit Breaker** | Triggers degradation |
| **Fallback** | Specific degradation strategy |
| **Cache-Aside** | Provides cached fallback data |
| **Feature Flags** | Controls degradation manually |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Resilience4j](https://resilience4j.readme.io/) | Circuit breakers, fallbacks for degradation |
| **Java** | [Spring Cloud Circuit Breaker](https://spring.io/projects/spring-cloud-circuitbreaker) | Abstraction over circuit breaker implementations |
| **Java** | [Failsafe](https://failsafe.dev/) | Fallback policies for degraded responses |
| **Go** | [sony/gobreaker](https://github.com/sony/gobreaker) | Circuit breaker with fallback support |
| **Go** | Standard Library | `context` for timeout-based degradation |
| **Python** | [pybreaker](https://pypi.org/project/pybreaker/) | Circuit breaker with fallback |
| **Python** | [tenacity](https://tenacity.readthedocs.io/) | Retry with fallback on exhaustion |
| **JavaScript** | [opossum](https://github.com/nodeshift/opossum) | Circuit breaker with fallback functions |
| **JavaScript** | [cockatiel](https://github.com/connor4312/cockatiel) | Composable resilience policies |
| **Multi** | [Feature Flag Services](https://launchdarkly.com/) | LaunchDarkly, Split.io for manual degradation control |

**Note**: Graceful degradation is an architectural approach. Libraries provide the building blocks (circuit breakers, feature flags) but the degradation strategy is application-specific.

## References

- Michael Nygard, "Release It!" Chapter 5
- Netflix, "Fault Tolerance in a High Volume, Distributed System"
- AWS Well-Architected Framework - Reliability Pillar
