# CQRS (Command Query Responsibility Segregation)

> Separate the read model from the write model. Use different data structures optimized for their specific purpose.

**Source**: Greg Young (2010), building on Bertrand Meyer's CQS principle

## Intent

Separate the operations that modify state (commands) from those that read state (queries). This allows independent optimization, scaling, and evolution of each side.

## Key Concepts

- **Command**: An intent to change state (write operation)
- **Query**: A request for data without side effects (read operation)
- **Write Model**: Optimized for enforcing business rules and capturing intent
- **Read Model**: Optimized for querying and displaying data
- **Eventual Consistency**: Read model may lag behind write model

## CQS vs CQRS

```
CQS (Command Query Separation):
┌─────────────────────────────────────────────┐
│              Single Model                    │
│  Commands ────────┬─────────── Queries      │
│                   │                          │
│              Same Database                   │
└─────────────────────────────────────────────┘
Methods either modify state OR return data, not both.

CQRS (Command Query Responsibility Segregation):
┌──────────────────┐        ┌──────────────────┐
│   Write Model    │        │   Read Model     │
│                  │        │                  │
│  Commands ───────┼────────┼─── Queries      │
│                  │  Sync  │                  │
│  Write Database  │◄───────│  Read Database  │
└──────────────────┘        └──────────────────┘
Completely separate models and potentially separate databases.
```

## When to Use

- Read and write patterns differ significantly
- Complex domain with different query needs
- Need to scale reads and writes independently
- Complex UI requirements (multiple projections)
- Combined with Event Sourcing

## When NOT to Use

- Simple CRUD domains
- Read/write patterns are similar
- Team unfamiliar with eventual consistency
- Single-user applications
- **Start without CQRS**, add it when needed

## Language Examples

### Java

```java
// ===== COMMAND SIDE =====

// Command
public record CreateOrderCommand(
    CustomerId customerId,
    List<OrderItemCommand> items,
    ShippingAddress shippingAddress
) {}

// Command Handler
@Service
public class CreateOrderCommandHandler {
    private final OrderRepository orderRepository;
    private final EventPublisher eventPublisher;

    @Transactional
    public OrderId handle(CreateOrderCommand command) {
        // Domain logic
        Order order = Order.create(
            OrderId.generate(),
            command.customerId(),
            command.items().stream()
                .map(item -> new OrderItem(item.productId(), item.quantity(), item.price()))
                .toList(),
            command.shippingAddress()
        );

        // Validate business rules
        order.validate();

        // Persist write model
        orderRepository.save(order);

        // Publish events for read model sync
        eventPublisher.publish(new OrderCreatedEvent(
            order.getId(),
            order.getCustomerId(),
            order.getItems(),
            order.getTotal(),
            Instant.now()
        ));

        return order.getId();
    }
}

// Write model (rich domain model)
public class Order {
    private final OrderId id;
    private final CustomerId customerId;
    private OrderStatus status;
    private final List<OrderItem> items;
    private final ShippingAddress shippingAddress;
    private Money total;

    public void validate() {
        if (items.isEmpty()) {
            throw new InvalidOrderException("Order must have items");
        }
        if (total.isLessThan(Money.of(10, "USD"))) {
            throw new InvalidOrderException("Minimum order is $10");
        }
    }

    public void ship() {
        if (status != OrderStatus.CONFIRMED) {
            throw new InvalidStateTransitionException("Cannot ship unconfirmed order");
        }
        this.status = OrderStatus.SHIPPED;
    }
}

// ===== QUERY SIDE =====

// Query
public record GetOrderSummaryQuery(OrderId orderId) {}
public record GetCustomerOrdersQuery(CustomerId customerId, int limit) {}

// Read model (DTO optimized for display)
public record OrderSummaryDto(
    String orderId,
    String customerName,
    String customerEmail,
    List<OrderItemDto> items,
    BigDecimal total,
    String status,
    Instant createdAt
) {}

// Query Handler
@Service
public class OrderQueryHandler {
    private final OrderReadRepository readRepository;

    public Optional<OrderSummaryDto> handle(GetOrderSummaryQuery query) {
        // Simple query against denormalized read model
        return readRepository.findSummaryById(query.orderId().getValue());
    }

    public List<OrderSummaryDto> handle(GetCustomerOrdersQuery query) {
        return readRepository.findByCustomerId(
            query.customerId().getValue(),
            query.limit()
        );
    }
}

// Read model repository (optimized queries)
@Repository
public class OrderReadRepository {
    private final JdbcTemplate jdbc;

    public Optional<OrderSummaryDto> findSummaryById(UUID orderId) {
        // Single query returns everything needed for display
        return jdbc.query("""
            SELECT o.id, c.name, c.email, o.total, o.status, o.created_at,
                   oi.product_name, oi.quantity, oi.price
            FROM order_summaries o
            JOIN customers c ON o.customer_id = c.id
            LEFT JOIN order_summary_items oi ON o.id = oi.order_id
            WHERE o.id = ?
            """,
            this::mapToOrderSummary,
            orderId
        );
    }
}

// ===== SYNC MECHANISM (Event Handler) =====

@Component
public class OrderReadModelSynchronizer {
    private final OrderReadRepository readRepository;

    @EventListener
    @Transactional
    public void on(OrderCreatedEvent event) {
        // Update read model when write model changes
        OrderSummaryEntity summary = new OrderSummaryEntity();
        summary.setId(event.orderId().getValue());
        summary.setCustomerId(event.customerId().getValue());
        summary.setTotal(event.total().getAmount());
        summary.setStatus("CREATED");
        summary.setCreatedAt(event.timestamp());

        // Denormalize for faster queries
        List<OrderSummaryItemEntity> items = event.items().stream()
            .map(item -> {
                var entity = new OrderSummaryItemEntity();
                entity.setOrderId(event.orderId().getValue());
                entity.setProductName(item.productName());
                entity.setQuantity(item.quantity());
                entity.setPrice(item.price().getAmount());
                return entity;
            })
            .toList();

        readRepository.save(summary, items);
    }

    @EventListener
    @Transactional
    public void on(OrderShippedEvent event) {
        readRepository.updateStatus(event.orderId().getValue(), "SHIPPED");
    }
}
```

### Go

```go
// ===== COMMAND SIDE =====

// Command
type CreateOrderCommand struct {
    CustomerID      CustomerID
    Items           []OrderItemCmd
    ShippingAddress Address
}

// Command Handler
type CreateOrderHandler struct {
    orders     OrderRepository
    events     EventPublisher
}

func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) (OrderID, error) {
    // Create domain object
    order, err := NewOrder(NewOrderID(), cmd.CustomerID, cmd.Items, cmd.ShippingAddress)
    if err != nil {
        return OrderID{}, fmt.Errorf("create order: %w", err)
    }

    // Validate
    if err := order.Validate(); err != nil {
        return OrderID{}, fmt.Errorf("validate: %w", err)
    }

    // Persist
    if err := h.orders.Save(ctx, order); err != nil {
        return OrderID{}, fmt.Errorf("save: %w", err)
    }

    // Publish event for read model
    h.events.Publish(ctx, OrderCreatedEvent{
        OrderID:    order.ID,
        CustomerID: order.CustomerID,
        Items:      order.Items,
        Total:      order.Total,
        CreatedAt:  time.Now(),
    })

    return order.ID, nil
}

// ===== QUERY SIDE =====

// Query
type GetOrderSummaryQuery struct {
    OrderID OrderID
}

// Read model
type OrderSummaryDTO struct {
    ID           string           `json:"id"`
    CustomerName string           `json:"customerName"`
    Items        []OrderItemDTO   `json:"items"`
    Total        float64          `json:"total"`
    Status       string           `json:"status"`
    CreatedAt    time.Time        `json:"createdAt"`
}

// Query Handler
type OrderQueryHandler struct {
    readRepo OrderReadRepository
}

func (h *OrderQueryHandler) GetOrderSummary(ctx context.Context, q GetOrderSummaryQuery) (*OrderSummaryDTO, error) {
    return h.readRepo.FindSummaryByID(ctx, q.OrderID)
}

// Read repository (optimized for queries)
type OrderReadRepository interface {
    FindSummaryByID(ctx context.Context, id OrderID) (*OrderSummaryDTO, error)
    FindByCustomer(ctx context.Context, customerID CustomerID, limit int) ([]OrderSummaryDTO, error)
}

// ===== SYNCHRONIZATION =====

type OrderReadModelSync struct {
    readRepo OrderReadRepository
}

func (s *OrderReadModelSync) OnOrderCreated(ctx context.Context, event OrderCreatedEvent) error {
    summary := &OrderSummaryEntity{
        ID:         event.OrderID.String(),
        CustomerID: event.CustomerID.String(),
        Total:      event.Total.Amount,
        Status:     "CREATED",
        CreatedAt:  event.CreatedAt,
    }

    return s.readRepo.Save(ctx, summary)
}
```

## Sync Strategies

### 1. Synchronous (Same Transaction)
```
Command ─────► Write Model ─────► Read Model
                    │                  │
                    └──────────────────┘
                      Same Transaction
```
- Pros: Strong consistency
- Cons: Slower writes, coupling

### 2. Asynchronous (Events)
```
Command ─────► Write Model ─────► Event
                                    │
                                    ▼ (async)
                               Read Model
```
- Pros: Fast writes, scalable
- Cons: Eventual consistency, complexity

### 3. Hybrid (Event Sourcing)
```
Command ─────► Event Store ─────► Projection
                    │                  │
              (Source of Truth)   (Read Model)
```
- Pros: Full audit trail, replay
- Cons: Highest complexity

## Review Checklist

### Commands
- [ ] **[BLOCKER]** Commands are imperative, named for intent (CreateOrder, not SaveOrder)
- [ ] **[MAJOR]** Commands validated before processing
- [ ] **[MAJOR]** Commands don't return data (fire-and-forget or return ID only)
- [ ] **[MINOR]** Command handlers are focused and small

### Queries
- [ ] **[BLOCKER]** Queries have no side effects
- [ ] **[MAJOR]** Read models are denormalized for specific use cases
- [ ] **[MAJOR]** Queries bypass domain model (read directly from read DB)
- [ ] **[MINOR]** Multiple read models for different query patterns

### Synchronization
- [ ] **[BLOCKER]** Sync mechanism exists (events, triggers, etc.)
- [ ] **[MAJOR]** Eventual consistency handled in UI
- [ ] **[MAJOR]** Failed syncs have retry/recovery
- [ ] **[MINOR]** Monitoring for sync lag

## Common Mistakes

### 1. Querying Through Write Model
```java
// BAD: Using domain model for queries
public OrderDto getOrder(OrderId id) {
    Order order = orderRepository.findById(id);  // Loads full aggregate!
    return new OrderDto(order);  // Complex mapping
}

// GOOD: Direct query to read model
public OrderDto getOrder(OrderId id) {
    return jdbcTemplate.queryForObject(
        "SELECT * FROM order_summaries WHERE id = ?",
        OrderDto.class,
        id
    );
}
```

### 2. Commands Returning Data
```java
// BAD: Command returns full object
public Order createOrder(CreateOrderCommand cmd) {
    Order order = ...;
    return order;  // Queries should return data, not commands
}

// GOOD: Command returns minimal info
public OrderId createOrder(CreateOrderCommand cmd) {
    Order order = ...;
    return order.getId();
}

// Client queries if needed
OrderDto details = orderQueryHandler.getOrder(orderId);
```

### 3. Ignoring Eventual Consistency
```java
// BAD: Assuming immediate consistency
orderCommandHandler.create(createCmd);
OrderDto order = orderQueryHandler.getOrder(orderId);  // May not exist yet!

// GOOD: Handle eventual consistency
orderCommandHandler.create(createCmd);
// Option 1: Return created ID, let client poll
// Option 2: Use websockets for notification
// Option 3: Show "pending" state in UI
```

## When to Add CQRS

| Signal | Meaning |
|--------|---------|
| Slow queries | Read model optimization needed |
| Complex reporting | Multiple projections needed |
| Different scaling needs | Reads >> Writes or vice versa |
| Event Sourcing in use | Natural fit for CQRS |
| Query complexity growing | Denormalized views help |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Event Sourcing** | Often combined with CQRS |
| **Domain Events** | Used for sync between models |
| **Repository** | Separate repos for read/write |
| **Mediator** | Often used to dispatch commands/queries |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Axon Framework](https://www.axoniq.io/) | Complete CQRS/ES framework |
| **Java** | [Spring Modulith](https://spring.io/projects/spring-modulith) | Modular Spring with CQRS support |
| **Java** | [Lagom](https://www.lagomframework.com/) | Reactive microservices with CQRS |
| **Go** | [looplab/eventhorizon](https://github.com/looplab/eventhorizon) | CQRS/ES framework |
| **Go** | [ThreeDotsLabs/watermill](https://watermill.io/) | Message-driven CQRS |
| **Python** | [eventsourcing](https://eventsourcing.readthedocs.io/) | CQRS/ES library |
| **JavaScript** | [NestJS CQRS](https://docs.nestjs.com/recipes/cqrs) | CQRS module with commands/queries |
| **JavaScript** | [Wolkenkit](https://www.wolkenkit.io/) | CQRS/ES platform |
| **.NET** | [MediatR](https://github.com/jbogard/MediatR) | Mediator for commands/queries |
| **.NET** | [Wolverine](https://wolverine.netlify.app/) | Message handling with CQRS |
| **.NET** | [Marten](https://martendb.io/) | CQRS with PostgreSQL |

## References

- Greg Young, "CQRS Documents" (2010)
- Martin Fowler, "CQRS" - https://martinfowler.com/bliki/CQRS.html
- Microsoft, "CQRS Pattern" - Azure Architecture Patterns
