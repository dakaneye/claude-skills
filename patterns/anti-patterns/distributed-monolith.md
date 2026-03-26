# Distributed Monolith Anti-Pattern

> A system that has the complexity of microservices but none of the benefits. Services are technically separate but tightly coupled, requiring coordinated deployment and changes.

## The Problem

A distributed monolith:
- Has all the complexity of distributed systems (network failures, latency, consistency)
- Has none of the benefits (independent deployment, team autonomy, scaling)
- Services can't be deployed independently
- Changes require coordinated releases across services
- Failure in one service cascades to others

## Symptoms

```
Distributed Monolith:
┌─────────┐ sync  ┌─────────┐ sync  ┌─────────┐
│Service A│──────►│Service B│──────►│Service C│
└────┬────┘       └────┬────┘       └────┬────┘
     │                 │                 │
     └─────────────────┴─────────────────┘
                       │
              ┌────────┴────────┐
              │  Shared Database │
              └─────────────────┘

All services must be deployed together!
Shared database creates coupling!
Synchronous chains create fragility!

Actual Microservices:
┌─────────┐       ┌─────────┐       ┌─────────┐
│Service A│       │Service B│       │Service C│
└────┬────┘       └────┬────┘       └────┬────┘
     │                 │                 │
┌────┴────┐       ┌────┴────┐       ┌────┴────┐
│   DB A  │       │   DB B  │       │   DB C  │
└─────────┘       └─────────┘       └─────────┘
     │                 │                 │
     └─────────────────┼─────────────────┘
                       │
              ┌────────▼────────┐
              │   Event Bus     │
              └─────────────────┘

Independent databases!
Async communication!
Deploy independently!
```

## Warning Signs

| Sign | Why It's a Problem |
|------|-------------------|
| **Shared database** | Schema changes affect all services |
| **Synchronous call chains** | Latency adds up, any failure breaks chain |
| **Coordinated deployments** | Can't release one service alone |
| **Shared libraries with domain logic** | Changes require redeploying all consumers |
| **Direct database access** | Service B reads Service A's tables |
| **Distributed transactions** | Services can't operate independently |
| **All-or-nothing availability** | One service down = system down |

## Example: Distributed Monolith

```java
// Service A - Order Service
@RestController
public class OrderController {

    @PostMapping("/orders")
    public ResponseEntity<Order> createOrder(@RequestBody CreateOrderRequest request) {
        // Sync call to User Service (blocks)
        User user = userServiceClient.getUser(request.getUserId());

        // Sync call to Inventory Service (blocks)
        for (OrderItem item : request.getItems()) {
            inventoryServiceClient.reserve(item.getProductId(), item.getQuantity());
        }

        // Sync call to Pricing Service (blocks)
        Money total = pricingServiceClient.calculateTotal(request.getItems());

        // Sync call to Payment Service (blocks)
        PaymentResult payment = paymentServiceClient.charge(user.getId(), total);

        // Create order (finally!)
        Order order = new Order(user, request.getItems(), payment);
        orderRepository.save(order);

        // Sync call to Notification Service (blocks)
        notificationServiceClient.sendConfirmation(user.getEmail(), order);

        return ResponseEntity.ok(order);
    }
}

// Service B - Shares database with Service A
@Repository
public class InventoryRepository {
    // Directly queries the ORDERS table - tight coupling!
    @Query("SELECT sum(oi.quantity) FROM order_items oi " +
           "JOIN orders o ON oi.order_id = o.id " +
           "WHERE o.status = 'PENDING' AND oi.product_id = :productId")
    int getReservedQuantity(@Param("productId") Long productId);
}

// Shared library with domain logic
// All services depend on this - can't deploy independently
public class OrderValidator {
    public ValidationResult validate(Order order) {
        // Business logic in shared library
        // Change here requires redeploying ALL services
    }
}
```

## Example: Proper Microservices

```java
// Service A - Order Service (independent)
@Service
public class OrderService {
    private final OrderRepository orderRepository;
    private final EventPublisher eventPublisher;

    @Transactional
    public OrderId createOrder(CreateOrderCommand command) {
        // Create order with local data only
        Order order = Order.create(
            OrderId.generate(),
            command.getCustomerId(),
            command.getItems()
        );

        order.setStatus(OrderStatus.PENDING);
        orderRepository.save(order);

        // Publish event - async communication
        eventPublisher.publish(new OrderCreatedEvent(
            order.getId(),
            order.getCustomerId(),
            order.getItems(),
            order.getTotal()
        ));

        return order.getId();
    }

    // Handle events from other services
    @EventListener
    public void on(PaymentCompletedEvent event) {
        Order order = orderRepository.findById(event.getOrderId())
            .orElseThrow();
        order.confirmPayment();
        orderRepository.save(order);
    }

    @EventListener
    public void on(PaymentFailedEvent event) {
        Order order = orderRepository.findById(event.getOrderId())
            .orElseThrow();
        order.cancel("Payment failed");
        orderRepository.save(order);
    }
}

// Service B - Inventory Service (independent)
@Service
public class InventoryService {
    private final InventoryRepository inventoryRepository;
    private final EventPublisher eventPublisher;

    // React to order events
    @EventListener
    public void on(OrderCreatedEvent event) {
        try {
            for (var item : event.getItems()) {
                inventoryRepository.reserve(item.getProductId(), item.getQuantity());
            }
            eventPublisher.publish(new InventoryReservedEvent(event.getOrderId()));
        } catch (InsufficientStockException e) {
            eventPublisher.publish(new InventoryReservationFailedEvent(
                event.getOrderId(),
                e.getMessage()
            ));
        }
    }

    @EventListener
    public void on(OrderCancelledEvent event) {
        // Release reserved inventory
        inventoryRepository.releaseForOrder(event.getOrderId());
    }
}

// Service C - Payment Service (independent)
@Service
public class PaymentService {
    private final PaymentGateway paymentGateway;
    private final EventPublisher eventPublisher;

    @EventListener
    public void on(InventoryReservedEvent event) {
        // Only charge after inventory is reserved
        try {
            PaymentResult result = paymentGateway.charge(event.getCustomerId(), event.getAmount());
            eventPublisher.publish(new PaymentCompletedEvent(event.getOrderId(), result));
        } catch (PaymentException e) {
            eventPublisher.publish(new PaymentFailedEvent(event.getOrderId(), e.getMessage()));
        }
    }
}
```

## Detection Checklist

When reviewing architecture, flag Distributed Monolith if:

- [ ] **[BLOCKER]** Services share a database
- [ ] **[BLOCKER]** Services directly read each other's tables
- [ ] **[BLOCKER]** Deployment requires coordinating multiple services
- [ ] **[MAJOR]** Synchronous call chains >3 services deep
- [ ] **[MAJOR]** Shared library contains business logic
- [ ] **[MAJOR]** Distributed transactions span services
- [ ] **[MINOR]** All services maintained by same team

## Refactoring Strategies

### 1. Split the Database
```
Before:
Service A ─┐
           ├──► Shared Database
Service B ─┘

After:
Service A ──► Database A
           │
           └──► Event Bus ──► Service B ──► Database B
```

### 2. Replace Sync with Async
```
Before:
A ──sync──► B ──sync──► C ──sync──► D

After:
A ──publish──► Event Bus
               │
        ┌──────┼──────┬──────┐
        ▼      ▼      ▼      ▼
        B      C      D      E
```

### 3. Introduce API Gateway
```
Before:
Client ──► A ──► B ──► C

After:
Client ──► API Gateway ──┬──► A
                         ├──► B
                         └──► C
(Compose at the edge, not in services)
```

### 4. Saga Pattern for Coordination
```
// Instead of distributed transaction
@Transactional  // Spans multiple services - BAD!
void createOrder() {
    orderService.create();
    inventoryService.reserve();
    paymentService.charge();
}

// Use saga with compensating actions
orderService.create() ──► OrderCreatedEvent
                          │
inventoryService ◄────────┘
  reserve() ──► InventoryReservedEvent
                │
paymentService ◄┘
  charge() ──► PaymentCompletedEvent (success)
          └──► PaymentFailedEvent (failure)
                │
inventoryService ◄┘
  release() // Compensating action
```

## Comparison

| Aspect | Monolith | Distributed Monolith | Microservices |
|--------|----------|---------------------|---------------|
| **Deployment** | Single unit | Coordinated | Independent |
| **Database** | Single | Shared | Per-service |
| **Communication** | In-process | Sync HTTP | Async events |
| **Failure** | All or nothing | Cascading | Isolated |
| **Complexity** | Low | High | High |
| **Benefits** | Simple | None | Autonomy, scaling |

## Prevention

1. **Database per service**: Each service owns its data
2. **Async by default**: Use events, not sync calls
3. **Independent deployment**: If you can't deploy alone, it's not independent
4. **Team ownership**: Service boundaries = team boundaries
5. **Contract testing**: Validate interfaces, not implementations

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Saga** | Coordinates without distributed transactions |
| **Event-Driven** | Async communication between services |
| **Database per Service** | Prevents data coupling |
| **API Gateway** | Aggregates at edge, not in services |

## References

- Sam Newman, "Building Microservices" Chapter 4
- Fowler, "Microservices Prerequisites"
- Chris Richardson, "Microservices Patterns"
