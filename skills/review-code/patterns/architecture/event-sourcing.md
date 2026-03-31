# Event Sourcing

> Store the state of a system as a sequence of events rather than as the current state. The current state is derived by replaying events.

**Source**: Martin Fowler, Greg Young

## Intent

Persist every state change as an immutable event. The current state is computed by replaying these events from the beginning. This provides a complete audit trail and enables powerful features like temporal queries and event replay.

## Key Concepts

- **Event**: An immutable fact that something happened (past tense)
- **Event Store**: Append-only log of events
- **Aggregate**: Entity whose state is built from events
- **Projection**: A read model built from events
- **Snapshot**: Cached state to avoid replaying all events

## Structure

```
Traditional CRUD:
┌─────────────┐    UPDATE    ┌─────────────┐
│   Client    │─────────────►│   Database  │
└─────────────┘              │  (Current   │
                             │   State)    │
                             └─────────────┘

Event Sourcing:
┌─────────────┐   APPEND     ┌─────────────┐   REPLAY    ┌─────────────┐
│   Client    │─────────────►│ Event Store │────────────►│  Aggregate  │
└─────────────┘              │ (Immutable) │             │  (Current   │
                             └─────────────┘             │   State)    │
                                    │                    └─────────────┘
                                    │ PROJECT
                                    ▼
                             ┌─────────────┐
                             │ Read Models │
                             │(Projections)│
                             └─────────────┘
```

## When to Use

- Need complete audit trail
- Complex domain with business value in history
- Need to query past states (temporal queries)
- Regulatory compliance requires immutability
- Combined with CQRS for complex read patterns
- Event-driven architecture

## When NOT to Use

- Simple CRUD applications
- No business value in history
- Team unfamiliar with eventual consistency
- Real-time consistency required everywhere
- **Very complex** - only use when benefits outweigh costs

## Language Examples

### Java

```java
// ===== EVENTS (Immutable Facts) =====

public sealed interface OrderEvent permits
    OrderCreated, ItemAdded, ItemRemoved, OrderSubmitted, OrderShipped {

    OrderId orderId();
    Instant occurredAt();
}

public record OrderCreated(
    OrderId orderId,
    CustomerId customerId,
    Instant occurredAt
) implements OrderEvent {}

public record ItemAdded(
    OrderId orderId,
    ProductId productId,
    int quantity,
    Money price,
    Instant occurredAt
) implements OrderEvent {}

public record ItemRemoved(
    OrderId orderId,
    ProductId productId,
    Instant occurredAt
) implements OrderEvent {}

public record OrderSubmitted(
    OrderId orderId,
    Money total,
    Instant occurredAt
) implements OrderEvent {}

// ===== AGGREGATE (State from Events) =====

public class Order {
    private OrderId id;
    private CustomerId customerId;
    private OrderStatus status;
    private final Map<ProductId, OrderItem> items = new HashMap<>();
    private Money total = Money.ZERO;
    private int version = 0;

    // Reconstruct from events
    public static Order fromEvents(List<OrderEvent> events) {
        Order order = new Order();
        for (OrderEvent event : events) {
            order.apply(event);
            order.version++;
        }
        return order;
    }

    // Apply event to update state (no side effects!)
    private void apply(OrderEvent event) {
        switch (event) {
            case OrderCreated e -> {
                this.id = e.orderId();
                this.customerId = e.customerId();
                this.status = OrderStatus.DRAFT;
            }
            case ItemAdded e -> {
                items.put(e.productId(), new OrderItem(
                    e.productId(), e.quantity(), e.price()
                ));
                recalculateTotal();
            }
            case ItemRemoved e -> {
                items.remove(e.productId());
                recalculateTotal();
            }
            case OrderSubmitted e -> {
                this.status = OrderStatus.SUBMITTED;
                this.total = e.total();
            }
            case OrderShipped e -> {
                this.status = OrderStatus.SHIPPED;
            }
        }
    }

    // ===== COMMAND HANDLERS (Return Events) =====

    public List<OrderEvent> addItem(ProductId productId, int quantity, Money price) {
        // Validate business rules
        if (status != OrderStatus.DRAFT) {
            throw new OrderNotModifiableException(id);
        }
        if (quantity <= 0) {
            throw new InvalidQuantityException(quantity);
        }

        // Create event (don't modify state directly!)
        ItemAdded event = new ItemAdded(id, productId, quantity, price, Instant.now());

        // Apply event to update state
        apply(event);
        version++;

        // Return events for persistence
        return List.of(event);
    }

    public List<OrderEvent> submit() {
        if (status != OrderStatus.DRAFT) {
            throw new InvalidStateTransitionException("Cannot submit non-draft order");
        }
        if (items.isEmpty()) {
            throw new EmptyOrderException(id);
        }

        OrderSubmitted event = new OrderSubmitted(id, total, Instant.now());
        apply(event);
        version++;

        return List.of(event);
    }

    private void recalculateTotal() {
        this.total = items.values().stream()
            .map(OrderItem::getLineTotal)
            .reduce(Money.ZERO, Money::add);
    }
}

// ===== EVENT STORE =====

public interface EventStore {
    void append(String streamId, List<? extends Event> events, int expectedVersion);
    List<Event> loadStream(String streamId);
    List<Event> loadStream(String streamId, int fromVersion);
}

@Repository
public class PostgresEventStore implements EventStore {
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional
    public void append(String streamId, List<? extends Event> events, int expectedVersion) {
        // Optimistic concurrency check
        int currentVersion = getCurrentVersion(streamId);
        if (currentVersion != expectedVersion) {
            throw new ConcurrencyException(
                "Expected version " + expectedVersion + " but found " + currentVersion
            );
        }

        // Append events
        int version = expectedVersion;
        for (Event event : events) {
            version++;
            jdbc.update("""
                INSERT INTO events (stream_id, version, event_type, event_data, occurred_at)
                VALUES (?, ?, ?, ?::jsonb, ?)
                """,
                streamId,
                version,
                event.getClass().getSimpleName(),
                objectMapper.writeValueAsString(event),
                event.occurredAt()
            );
        }
    }

    @Override
    public List<Event> loadStream(String streamId) {
        return jdbc.query("""
            SELECT event_type, event_data FROM events
            WHERE stream_id = ?
            ORDER BY version ASC
            """,
            this::mapEvent,
            streamId
        );
    }
}

// ===== AGGREGATE REPOSITORY =====

@Repository
public class EventSourcedOrderRepository {
    private final EventStore eventStore;

    public Order load(OrderId id) {
        List<Event> events = eventStore.loadStream("order-" + id.getValue());
        if (events.isEmpty()) {
            throw new OrderNotFoundException(id);
        }
        return Order.fromEvents(events.stream()
            .filter(e -> e instanceof OrderEvent)
            .map(e -> (OrderEvent) e)
            .toList()
        );
    }

    public void save(Order order, List<OrderEvent> newEvents) {
        eventStore.append(
            "order-" + order.getId().getValue(),
            newEvents,
            order.getVersion() - newEvents.size()  // Expected version before new events
        );
    }
}

// ===== PROJECTION (Read Model) =====

@Component
public class OrderSummaryProjection {
    private final JdbcTemplate jdbc;

    @EventListener
    public void on(OrderCreated event) {
        jdbc.update("""
            INSERT INTO order_summaries (id, customer_id, status, total, created_at)
            VALUES (?, ?, 'DRAFT', 0, ?)
            """,
            event.orderId().getValue(),
            event.customerId().getValue(),
            event.occurredAt()
        );
    }

    @EventListener
    public void on(ItemAdded event) {
        jdbc.update("""
            UPDATE order_summaries
            SET total = total + ?, item_count = item_count + 1
            WHERE id = ?
            """,
            event.price().multiply(event.quantity()).getAmount(),
            event.orderId().getValue()
        );
    }

    @EventListener
    public void on(OrderSubmitted event) {
        jdbc.update("""
            UPDATE order_summaries SET status = 'SUBMITTED' WHERE id = ?
            """,
            event.orderId().getValue()
        );
    }
}
```

### Go

```go
// ===== EVENTS =====

type OrderEvent interface {
    OrderID() OrderID
    OccurredAt() time.Time
}

type OrderCreated struct {
    orderID    OrderID
    customerID CustomerID
    occurredAt time.Time
}

func (e OrderCreated) OrderID() OrderID      { return e.orderID }
func (e OrderCreated) OccurredAt() time.Time { return e.occurredAt }

type ItemAdded struct {
    orderID    OrderID
    productID  ProductID
    quantity   int
    price      Money
    occurredAt time.Time
}

// ===== AGGREGATE =====

type Order struct {
    id         OrderID
    customerID CustomerID
    status     OrderStatus
    items      map[ProductID]*OrderItem
    total      Money
    version    int
}

func NewOrderFromEvents(events []OrderEvent) *Order {
    o := &Order{items: make(map[ProductID]*OrderItem)}
    for _, event := range events {
        o.apply(event)
        o.version++
    }
    return o
}

func (o *Order) apply(event OrderEvent) {
    switch e := event.(type) {
    case OrderCreated:
        o.id = e.orderID
        o.customerID = e.customerID
        o.status = OrderStatusDraft
    case ItemAdded:
        o.items[e.productID] = &OrderItem{
            ProductID: e.productID,
            Quantity:  e.quantity,
            Price:     e.price,
        }
        o.recalculateTotal()
    case OrderSubmitted:
        o.status = OrderStatusSubmitted
    }
}

// Command returns events
func (o *Order) AddItem(productID ProductID, qty int, price Money) ([]OrderEvent, error) {
    if o.status != OrderStatusDraft {
        return nil, ErrOrderNotModifiable
    }

    event := ItemAdded{
        orderID:    o.id,
        productID:  productID,
        quantity:   qty,
        price:      price,
        occurredAt: time.Now(),
    }

    o.apply(event)
    o.version++

    return []OrderEvent{event}, nil
}

// ===== EVENT STORE =====

type EventStore interface {
    Append(ctx context.Context, streamID string, events []Event, expectedVersion int) error
    LoadStream(ctx context.Context, streamID string) ([]Event, error)
}

type PostgresEventStore struct {
    db *sql.DB
}

func (s *PostgresEventStore) Append(ctx context.Context, streamID string, events []Event, expectedVersion int) error {
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback()

    // Check version
    var currentVersion int
    err = tx.QueryRowContext(ctx,
        "SELECT COALESCE(MAX(version), 0) FROM events WHERE stream_id = $1",
        streamID,
    ).Scan(&currentVersion)
    if err != nil {
        return err
    }

    if currentVersion != expectedVersion {
        return ErrConcurrencyConflict
    }

    // Append events
    version := expectedVersion
    for _, event := range events {
        version++
        data, _ := json.Marshal(event)
        _, err = tx.ExecContext(ctx, `
            INSERT INTO events (stream_id, version, event_type, event_data, occurred_at)
            VALUES ($1, $2, $3, $4, $5)
        `, streamID, version, eventType(event), data, event.OccurredAt())
        if err != nil {
            return err
        }
    }

    return tx.Commit()
}
```

## Snapshots

For aggregates with many events, store periodic snapshots:

```java
public class SnapshotStore {
    public void saveSnapshot(OrderId id, Order order) {
        // Save current state as snapshot
        jdbc.update("""
            INSERT INTO order_snapshots (order_id, version, state, created_at)
            VALUES (?, ?, ?::jsonb, NOW())
            ON CONFLICT (order_id) DO UPDATE
            SET version = ?, state = ?::jsonb, created_at = NOW()
            """,
            id.getValue(), order.getVersion(),
            objectMapper.writeValueAsString(order.toSnapshot()),
            order.getVersion(),
            objectMapper.writeValueAsString(order.toSnapshot())
        );
    }

    public Order load(OrderId id) {
        // Load snapshot if exists
        OrderSnapshot snapshot = loadLatestSnapshot(id);

        // Load events since snapshot
        List<OrderEvent> events;
        if (snapshot != null) {
            events = eventStore.loadStream(
                "order-" + id.getValue(),
                snapshot.getVersion()
            );
            Order order = Order.fromSnapshot(snapshot);
            for (OrderEvent event : events) {
                order.apply(event);
            }
            return order;
        } else {
            return Order.fromEvents(eventStore.loadStream("order-" + id.getValue()));
        }
    }
}
```

## Review Checklist

### Events
- [ ] **[BLOCKER]** Events are immutable (no setters)
- [ ] **[BLOCKER]** Events are past tense (OrderCreated, not CreateOrder)
- [ ] **[BLOCKER]** Events contain all data needed to reconstruct state
- [ ] **[MAJOR]** Events are versioned for schema evolution
- [ ] **[MINOR]** Events are serializable to/from JSON

### Aggregates
- [ ] **[BLOCKER]** State only changes through events
- [ ] **[BLOCKER]** apply() method has no side effects
- [ ] **[MAJOR]** Commands validate before creating events
- [ ] **[MAJOR]** Optimistic concurrency via version checking

### Event Store
- [ ] **[BLOCKER]** Events are append-only (never updated/deleted)
- [ ] **[MAJOR]** Concurrency control on append
- [ ] **[MAJOR]** Efficient stream loading
- [ ] **[MINOR]** Snapshot support for long streams

## Common Mistakes

### 1. Mutable Events
```java
// BAD: Event can be modified
public class OrderCreated {
    private String customerId;  // Mutable!
    public void setCustomerId(String id) { this.customerId = id; }
}

// GOOD: Immutable record
public record OrderCreated(
    OrderId orderId,
    CustomerId customerId,
    Instant occurredAt
) implements OrderEvent {}
```

### 2. Side Effects in apply()
```java
// BAD: Side effects in apply
private void apply(ItemAdded event) {
    items.put(event.productId(), ...);
    sendEmailNotification();  // Side effect!
    updateInventory();        // Side effect!
}

// GOOD: Pure state change
private void apply(ItemAdded event) {
    items.put(event.productId(), new OrderItem(...));
}
// Side effects handled separately by event handlers
```

### 3. Missing Data in Events
```java
// BAD: Event doesn't capture enough
public record ItemAdded(OrderId orderId, ProductId productId) {}
// How do we know the price at time of adding?

// GOOD: Capture all relevant data
public record ItemAdded(
    OrderId orderId,
    ProductId productId,
    int quantity,
    Money priceAtTimeOfOrder,  // Captured!
    Instant occurredAt
) {}
```

## Event Schema Evolution

```java
// Version 1
public record OrderCreated_v1(OrderId orderId, String customerName) {}

// Version 2 - added email
public record OrderCreated_v2(OrderId orderId, String customerName, String email) {}

// Upcaster transforms old events to new format
public class OrderCreatedUpcaster implements Upcaster<OrderCreated_v1, OrderCreated_v2> {
    @Override
    public OrderCreated_v2 upcast(OrderCreated_v1 old) {
        return new OrderCreated_v2(
            old.orderId(),
            old.customerName(),
            null  // Email unknown for old events
        );
    }
}
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **CQRS** | Often combined - events feed read models |
| **Domain Events** | Events are domain events |
| **Saga** | Coordinates events across aggregates |
| **Outbox Pattern** | Reliably publishes events |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Axon Framework](https://www.axoniq.io/) | Complete ES/CQRS framework |
| **Java** | [EventStoreDB Java Client](https://developers.eventstore.com/clients/java/) | EventStoreDB integration |
| **Java** | [Akka Persistence](https://doc.akka.io/docs/akka/current/typed/persistence.html) | Event sourcing with Akka actors |
| **Go** | [EventStoreDB Go Client](https://github.com/EventStore/EventStore-Client-Go) | EventStoreDB integration |
| **Go** | [go-cqrs](https://github.com/ThreeDotsLabs/watermill) | Watermill includes ES support |
| **Go** | [looplab/eventhorizon](https://github.com/looplab/eventhorizon) | CQRS/ES framework |
| **Python** | [eventsourcing](https://eventsourcing.readthedocs.io/) | Full ES library for Python |
| **Python** | [EventStoreDB Python Client](https://developers.eventstore.com/clients/python/) | EventStoreDB integration |
| **JavaScript** | [EventStoreDB Node Client](https://developers.eventstore.com/clients/node/) | EventStoreDB integration |
| **JavaScript** | [NestJS CQRS](https://docs.nestjs.com/recipes/cqrs) | ES/CQRS module for NestJS |
| **.NET** | [Marten](https://martendb.io/) | Document DB + Event Store on PostgreSQL |
| **.NET** | [EventStoreDB .NET Client](https://developers.eventstore.com/clients/dotnet/) | EventStoreDB integration |
| **Database** | [EventStoreDB](https://www.eventstore.com/) | Purpose-built event store database |

## References

- Martin Fowler, "Event Sourcing" - https://martinfowler.com/eaaDev/EventSourcing.html
- Greg Young, "Event Sourcing" (various talks)
- Vaughn Vernon, "Implementing Domain-Driven Design" Chapter 8
