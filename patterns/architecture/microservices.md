# Microservices Architecture

> An architectural style that structures an application as a collection of loosely coupled, independently deployable services, organized around business capabilities.

**Sources**: Sam Newman, "Building Microservices" (2015); Chris Richardson, "Microservices Patterns" (2018)

## Intent

Decompose a system into small, autonomous services that can be developed, deployed, and scaled independently. Each service owns its data and communicates through well-defined APIs.

## Key Principles

- **Single Responsibility**: Each service does one thing well
- **Autonomy**: Services are independently deployable
- **Decentralized Data**: Each service owns its data store
- **Smart Endpoints, Dumb Pipes**: Logic in services, not middleware
- **Design for Failure**: Services must handle downstream failures

## Structure

```
┌──────────────────────────────────────────────────────────────────┐
│                         API Gateway                               │
│            (Authentication, Rate Limiting, Routing)               │
└───────────────────────────┬──────────────────────────────────────┘
                            │
       ┌────────────────────┼────────────────────┐
       │                    │                    │
       ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Order Service│    │ User Service │    │Inventory Svc │
│              │    │              │    │              │
│  ┌────────┐  │    │  ┌────────┐  │    │  ┌────────┐  │
│  │Order DB│  │    │  │User DB │  │    │  │Inv. DB │  │
│  └────────┘  │    │  └────────┘  │    │  └────────┘  │
└──────────────┘    └──────────────┘    └──────────────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                    ┌───────▼───────┐
                    │  Message Bus  │
                    │ (Kafka/RMQ)   │
                    └───────────────┘
```

## When to Use

- Large, complex domain that benefits from decomposition
- Different parts of system have different scaling needs
- Teams need to work independently
- Different parts need different technology stacks
- Frequent, independent deployments needed

## When NOT to Use

- Small teams (< 5 engineers)
- Simple domains
- Startups/MVPs (start with monolith)
- Don't understand the domain well yet
- **If in doubt, start with a monolith**

## Service Design Guidelines

### Service Boundaries (Domain-Driven)

```
GOOD: Services aligned with business capabilities
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Ordering    │  │   Shipping    │  │   Billing     │
│   (Orders,    │  │   (Shipments, │  │   (Invoices,  │
│    Cart)      │  │    Tracking)  │  │    Payments)  │
└───────────────┘  └───────────────┘  └───────────────┘

BAD: Services aligned with technical layers
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Data Layer  │  │ Business Layer│  │   UI Layer    │
│   Service     │  │   Service     │  │   Service     │
└───────────────┘  └───────────────┘  └───────────────┘
```

### API Design

```java
// REST API (Order Service)
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderId orderId = orderService.createOrder(request.toCommand());
        return ResponseEntity
            .created(URI.create("/api/orders/" + orderId))
            .body(new OrderResponse(orderId));
    }

    @GetMapping("/{orderId}")
    public ResponseEntity<OrderDetailResponse> getOrder(
            @PathVariable String orderId) {
        return orderService.findById(new OrderId(orderId))
            .map(order -> ResponseEntity.ok(OrderDetailResponse.from(order)))
            .orElse(ResponseEntity.notFound().build());
    }
}

// API versioning
@RestController
@RequestMapping("/api/v2/orders")
public class OrderControllerV2 {
    // New version with breaking changes
}
```

## Communication Patterns

### Synchronous (HTTP/gRPC)

```java
// Feign client (declarative HTTP)
@FeignClient(name = "inventory-service", fallback = InventoryClientFallback.class)
public interface InventoryClient {

    @GetMapping("/api/inventory/{productId}")
    InventoryResponse getInventory(@PathVariable String productId);

    @PostMapping("/api/inventory/{productId}/reserve")
    ReservationResponse reserve(
        @PathVariable String productId,
        @RequestBody ReserveRequest request
    );
}

// With Circuit Breaker
@Component
public class InventoryClientFallback implements InventoryClient {
    @Override
    public InventoryResponse getInventory(String productId) {
        // Return cached data or default
        return InventoryResponse.unknown(productId);
    }

    @Override
    public ReservationResponse reserve(String productId, ReserveRequest request) {
        throw new ServiceUnavailableException("Inventory service unavailable");
    }
}
```

### Asynchronous (Events)

```java
// Publisher (Order Service)
@Service
public class OrderService {
    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;

    @Transactional
    public OrderId createOrder(CreateOrderCommand command) {
        Order order = Order.create(command);
        orderRepository.save(order);

        // Publish event
        kafkaTemplate.send("orders", order.getId().toString(),
            new OrderCreatedEvent(order.getId(), order.getItems(), order.getTotal())
        );

        return order.getId();
    }
}

// Consumer (Inventory Service)
@Component
public class OrderEventConsumer {

    @KafkaListener(topics = "orders", groupId = "inventory-service")
    public void onOrderCreated(OrderCreatedEvent event) {
        for (OrderItem item : event.getItems()) {
            inventoryService.reserve(item.getProductId(), item.getQuantity());
        }
    }
}
```

### Saga Pattern (Distributed Transactions)

```java
// Choreography-based Saga
// Step 1: Order Service creates order
@Service
public class OrderService {
    public void createOrder(CreateOrderCommand cmd) {
        Order order = Order.create(cmd);
        order.setStatus(OrderStatus.PENDING);
        orderRepository.save(order);
        eventPublisher.publish(new OrderCreatedEvent(order));
    }

    @EventListener
    public void onPaymentCompleted(PaymentCompletedEvent event) {
        Order order = orderRepository.findById(event.orderId());
        order.confirmPayment();
        orderRepository.save(order);
        eventPublisher.publish(new OrderConfirmedEvent(order));
    }

    @EventListener
    public void onPaymentFailed(PaymentFailedEvent event) {
        Order order = orderRepository.findById(event.orderId());
        order.cancel("Payment failed: " + event.reason());
        orderRepository.save(order);
        eventPublisher.publish(new OrderCancelledEvent(order));
    }
}

// Step 2: Payment Service processes payment
@Service
public class PaymentService {
    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        try {
            Payment payment = paymentGateway.charge(event.customerId(), event.total());
            eventPublisher.publish(new PaymentCompletedEvent(event.orderId(), payment));
        } catch (PaymentException e) {
            eventPublisher.publish(new PaymentFailedEvent(event.orderId(), e.getMessage()));
        }
    }
}

// Step 3: Inventory Service reserves stock
@Service
public class InventoryService {
    @EventListener
    public void onOrderConfirmed(OrderConfirmedEvent event) {
        try {
            inventoryRepository.reserve(event.items());
            eventPublisher.publish(new InventoryReservedEvent(event.orderId()));
        } catch (InsufficientStockException e) {
            eventPublisher.publish(new InventoryReservationFailedEvent(event.orderId()));
            // Triggers compensation in Order Service
        }
    }

    @EventListener
    public void onOrderCancelled(OrderCancelledEvent event) {
        // Compensating action
        inventoryRepository.release(event.orderId());
    }
}
```

## Go Implementation

```go
// Service structure
type OrderService struct {
    repo       OrderRepository
    inventory  InventoryClient
    events     EventPublisher
    logger     *slog.Logger
}

// HTTP handler
func (s *OrderService) HandleCreateOrder(w http.ResponseWriter, r *http.Request) {
    var req CreateOrderRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    // Check inventory (sync call with timeout)
    ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
    defer cancel()

    available, err := s.inventory.CheckAvailability(ctx, req.Items)
    if err != nil {
        s.logger.Error("inventory check failed", "error", err)
        http.Error(w, "service unavailable", http.StatusServiceUnavailable)
        return
    }
    if !available {
        http.Error(w, "items not available", http.StatusConflict)
        return
    }

    // Create order
    order, err := s.repo.Create(ctx, req.ToOrder())
    if err != nil {
        s.logger.Error("create order failed", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    // Publish event (async)
    s.events.Publish(ctx, OrderCreatedEvent{
        OrderID:    order.ID,
        CustomerID: order.CustomerID,
        Items:      order.Items,
        Total:      order.Total,
        CreatedAt:  time.Now(),
    })

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(OrderResponse{ID: order.ID.String()})
}

// Event consumer
type OrderEventHandler struct {
    inventory InventoryService
}

func (h *OrderEventHandler) HandleOrderCreated(ctx context.Context, event OrderCreatedEvent) error {
    for _, item := range event.Items {
        if err := h.inventory.Reserve(ctx, item.ProductID, item.Quantity); err != nil {
            return fmt.Errorf("reserve inventory: %w", err)
        }
    }
    return nil
}
```

## Data Management

### Database per Service

```
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Order Service │    │ User Service  │    │Payment Service│
│     API       │    │     API       │    │     API       │
└───────┬───────┘    └───────┬───────┘    └───────┬───────┘
        │                    │                    │
        ▼                    ▼                    ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │PostgreSQL│          │ MongoDB │          │PostgreSQL│
   │ (Orders) │          │ (Users) │          │(Payments)│
   └─────────┘          └─────────┘          └─────────┘
```

### Data Consistency Strategies

| Strategy | Consistency | Complexity | Use When |
|----------|-------------|------------|----------|
| Saga | Eventual | High | Cross-service transactions |
| Event Sourcing | Eventual | High | Audit trail needed |
| API Composition | Strong | Low | Read-only aggregation |
| Shared Database | Strong | Low | **Avoid** (anti-pattern) |

## Review Checklist

### Service Design
- [ ] **[BLOCKER]** Each service has single, clear responsibility
- [ ] **[BLOCKER]** Services are independently deployable
- [ ] **[BLOCKER]** Each service owns its data
- [ ] **[MAJOR]** Service boundaries align with business capabilities
- [ ] **[MAJOR]** Services communicate via well-defined APIs

### Resilience
- [ ] **[BLOCKER]** Circuit breakers for synchronous calls
- [ ] **[BLOCKER]** Timeouts on all external calls
- [ ] **[MAJOR]** Graceful degradation when dependencies fail
- [ ] **[MAJOR]** Idempotent operations for retry safety
- [ ] **[MINOR]** Health checks exposed

### Operations
- [ ] **[BLOCKER]** Centralized logging with correlation IDs
- [ ] **[MAJOR]** Distributed tracing enabled
- [ ] **[MAJOR]** Service discovery mechanism
- [ ] **[MAJOR]** API versioning strategy defined
- [ ] **[MINOR]** Deployment automation (CI/CD)

## Common Mistakes

### 1. Distributed Monolith
```
BAD: Services tightly coupled
┌─────────┐ sync ┌─────────┐ sync ┌─────────┐
│Service A│─────►│Service B│─────►│Service C│
└─────────┘      └─────────┘      └─────────┘
All must be deployed together, defeating the purpose.

GOOD: Loosely coupled via events
┌─────────┐      ┌─────────┐      ┌─────────┐
│Service A│─────►│Event Bus│◄─────│Service B│
└─────────┘      └─────────┘      └─────────┘
```

### 2. Shared Database
```
BAD: Services share database
┌─────────┐  ┌─────────┐
│Service A│  │Service B│
└────┬────┘  └────┬────┘
     │            │
     └─────┬──────┘
           ▼
     ┌──────────┐
     │ Shared DB│  ← Coupling!
     └──────────┘

GOOD: Database per service
┌─────────┐       ┌─────────┐
│Service A│       │Service B│
└────┬────┘       └────┬────┘
     │                 │
     ▼                 ▼
┌─────────┐       ┌─────────┐
│   DB A  │       │   DB B  │
└─────────┘       └─────────┘
```

### 3. Synchronous Chain
```java
// BAD: Chain of synchronous calls
public Order createOrder(CreateOrderCommand cmd) {
    User user = userService.getUser(cmd.userId);           // Call 1
    List<Product> products = productService.getProducts(); // Call 2
    boolean available = inventoryService.check(products);  // Call 3
    Payment payment = paymentService.charge(user, total);  // Call 4
    Shipment shipment = shippingService.create(order);     // Call 5
    // If any fails, entire request fails
}

// GOOD: Async choreography
public Order createOrder(CreateOrderCommand cmd) {
    Order order = Order.create(cmd);
    order.setStatus(PENDING);
    orderRepository.save(order);
    eventPublisher.publish(new OrderCreatedEvent(order));
    return order;
    // Other services react to event independently
}
```

## Service Size Guidelines

| Signal | Too Small | Too Large |
|--------|-----------|-----------|
| Team size | < 1 person | > 8 people |
| Deployments | Daily for minor changes | Months between deploys |
| Understanding | Trivial | Takes weeks |
| Cross-service calls | > 10 per request | 0 |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **API Gateway** | Single entry point for clients |
| **Circuit Breaker** | Resilience for sync calls |
| **Saga** | Distributed transactions |
| **Event Sourcing** | Event-based state management |
| **CQRS** | Separate read/write models |
| **Strangler Fig** | Migrating from monolith |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Cloud](https://spring.io/projects/spring-cloud) | Full microservices toolkit (discovery, config, gateway, circuit breaker) |
| **Java** | [Micronaut](https://micronaut.io/) | Low-overhead microservices framework |
| **Java** | [Quarkus](https://quarkus.io/) | Kubernetes-native Java for fast startup |
| **Java** | [Axon Framework](https://www.axoniq.io/) | Event-driven microservices with CQRS/Event Sourcing |
| **Go** | [go-kit](https://gokit.io/) | Microservices toolkit with transport/endpoint/service abstraction |
| **Go** | [go-micro](https://go-micro.dev/) | Pluggable microservices framework |
| **Go** | [Kratos](https://github.com/go-kratos/kratos) | Microservices framework with built-in best practices |
| **Python** | [FastAPI](https://fastapi.tiangolo.com/) | Modern async framework suitable for microservices |
| **Python** | [Nameko](https://nameko.readthedocs.io/) | Microservices framework with RPC and events |
| **JavaScript** | [NestJS](https://nestjs.com/) | Enterprise-grade Node.js microservices |
| **JavaScript** | [Moleculer](https://moleculer.services/) | Progressive microservices framework |
| **Multi** | [gRPC](https://grpc.io/) | High-performance RPC for service communication |
| **Multi** | [Dapr](https://dapr.io/) | Runtime for building microservices (any language) |
| **Multi** | [Istio](https://istio.io/) | Service mesh for traffic management, security, observability |

**Note**: Microservices is an architectural style, not a library choice. These tools help with common patterns (service discovery, resilience, communication) but the architecture itself is about service boundaries, team organization, and deployment independence.

## References

- Sam Newman, "Building Microservices" (2015, 2021)
- Chris Richardson, "Microservices Patterns" (2018)
- https://microservices.io/
- Martin Fowler, "Microservices" - https://martinfowler.com/articles/microservices.html
