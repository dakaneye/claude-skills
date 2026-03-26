# Anemic Domain Model Anti-Pattern

> A domain model where the objects contain little or no business logic, serving only as data containers. All behavior lives in service classes.

**Coined by**: Martin Fowler

## The Problem

An anemic domain model:
- Domain objects are just data bags (DTOs with getters/setters)
- All business logic lives in "service" or "manager" classes
- Violates object-oriented principles (data + behavior together)
- Leads to procedural code disguised as OOP
- Makes it hard to enforce invariants

## Symptoms

```
┌─────────────────────────────────────────────────────────────┐
│                    Anemic Domain Model                       │
│                                                             │
│  ┌──────────────┐          ┌──────────────────────────┐    │
│  │    Order     │          │     OrderService         │    │
│  │  (Data only) │          │  (All the behavior)      │    │
│  ├──────────────┤          ├──────────────────────────┤    │
│  │ - id         │          │ + createOrder()          │    │
│  │ - items      │◄─────────│ + addItem()              │    │
│  │ - status     │  uses    │ + removeItem()           │    │
│  │ - total      │          │ + calculateTotal()       │    │
│  │              │          │ + validateOrder()        │    │
│  │ + getId()    │          │ + submitOrder()          │    │
│  │ + setId()    │          │ + cancelOrder()          │    │
│  │ + getItems() │          │ + checkInventory()       │    │
│  │ + setItems() │          │ + applyDiscount()        │    │
│  │ + ...        │          │ + ...                    │    │
│  └──────────────┘          └──────────────────────────┘    │
│                                                             │
│  Domain has no behavior!    Service has ALL behavior!       │
└─────────────────────────────────────────────────────────────┘
```

## Warning Signs

| Sign | Why It's a Problem |
|------|-------------------|
| **Getters and setters only** | Object can be put in invalid state |
| **Public setters for everything** | No encapsulation |
| **Validation in services** | Invariants not enforced at domain level |
| **Services manipulate object internals** | Domain doesn't protect itself |
| **"Do-nothing" domain objects** | Just data transfer objects |

## Example: Anemic Model

```java
// ANEMIC: Domain object with no behavior
public class Order {
    private Long id;
    private Long customerId;
    private List<OrderItem> items;
    private OrderStatus status;
    private BigDecimal total;
    private String shippingAddress;

    // Just getters and setters - no behavior!
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public List<OrderItem> getItems() { return items; }
    public void setItems(List<OrderItem> items) { this.items = items; }

    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { this.status = status; }

    public BigDecimal getTotal() { return total; }
    public void setTotal(BigDecimal total) { this.total = total; }

    // ... more getters/setters
}

// ALL business logic in service - procedural code!
@Service
public class OrderService {

    public void addItem(Order order, Product product, int quantity) {
        // Service manipulates order internals
        if (order.getStatus() != OrderStatus.DRAFT) {
            throw new IllegalStateException("Cannot modify non-draft order");
        }

        OrderItem item = new OrderItem();
        item.setProductId(product.getId());
        item.setQuantity(quantity);
        item.setPrice(product.getPrice());

        order.getItems().add(item);  // Direct list manipulation!

        // Recalculate total
        BigDecimal total = BigDecimal.ZERO;
        for (OrderItem i : order.getItems()) {
            total = total.add(i.getPrice().multiply(BigDecimal.valueOf(i.getQuantity())));
        }
        order.setTotal(total);
    }

    public void submitOrder(Order order) {
        // Validation in service
        if (order.getItems().isEmpty()) {
            throw new IllegalStateException("Cannot submit empty order");
        }
        if (order.getShippingAddress() == null) {
            throw new IllegalStateException("Shipping address required");
        }
        if (order.getTotal().compareTo(BigDecimal.valueOf(10)) < 0) {
            throw new IllegalStateException("Minimum order is $10");
        }

        order.setStatus(OrderStatus.SUBMITTED);
    }
}
```

## Example: Rich Domain Model

```java
// RICH: Domain object with behavior and invariants
public class Order {
    private final OrderId id;
    private final CustomerId customerId;
    private final List<OrderItem> items;
    private OrderStatus status;
    private ShippingAddress shippingAddress;

    // Private constructor - use factory method
    private Order(OrderId id, CustomerId customerId) {
        this.id = Objects.requireNonNull(id);
        this.customerId = Objects.requireNonNull(customerId);
        this.items = new ArrayList<>();
        this.status = OrderStatus.DRAFT;
    }

    // Factory method ensures valid initial state
    public static Order create(OrderId id, CustomerId customerId) {
        return new Order(id, customerId);
    }

    // Behavior WITH invariant enforcement
    public void addItem(Product product, int quantity) {
        ensureDraft();

        if (quantity <= 0) {
            throw new InvalidQuantityException(quantity);
        }

        // Check for existing item
        items.stream()
            .filter(item -> item.getProductId().equals(product.getId()))
            .findFirst()
            .ifPresentOrElse(
                existing -> existing.increaseQuantity(quantity),
                () -> items.add(OrderItem.create(product, quantity))
            );
    }

    public void removeItem(ProductId productId) {
        ensureDraft();
        items.removeIf(item -> item.getProductId().equals(productId));
    }

    public void setShippingAddress(ShippingAddress address) {
        ensureDraft();
        this.shippingAddress = Objects.requireNonNull(address);
    }

    // Behavior with complex validation
    public void submit() {
        ensureDraft();

        if (items.isEmpty()) {
            throw new EmptyOrderException(id);
        }
        if (shippingAddress == null) {
            throw new MissingShippingAddressException(id);
        }
        if (getTotal().isLessThan(Money.of(10, "USD"))) {
            throw new MinimumOrderAmountException(id, getTotal());
        }

        this.status = OrderStatus.SUBMITTED;
    }

    public void cancel(String reason) {
        if (status == OrderStatus.SHIPPED) {
            throw new CannotCancelShippedException(id);
        }
        this.status = OrderStatus.CANCELLED;
    }

    // Calculated property - encapsulated
    public Money getTotal() {
        return items.stream()
            .map(OrderItem::getLineTotal)
            .reduce(Money.ZERO, Money::add);
    }

    // Protected state - no public setters
    public OrderStatus getStatus() {
        return status;
    }

    // Return defensive copy
    public List<OrderItem> getItems() {
        return Collections.unmodifiableList(items);
    }

    private void ensureDraft() {
        if (status != OrderStatus.DRAFT) {
            throw new OrderNotModifiableException(id, status);
        }
    }
}

// Service now coordinates, doesn't contain business logic
@Service
public class OrderApplicationService {
    private final OrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final EventPublisher events;

    public OrderId createOrder(CreateOrderCommand command) {
        Order order = Order.create(OrderId.generate(), command.getCustomerId());

        for (var item : command.getItems()) {
            Product product = productRepository.findById(item.getProductId())
                .orElseThrow(() -> new ProductNotFoundException(item.getProductId()));

            order.addItem(product, item.getQuantity());  // Domain handles logic
        }

        if (command.getShippingAddress() != null) {
            order.setShippingAddress(command.getShippingAddress());
        }

        orderRepository.save(order);
        events.publish(new OrderCreatedEvent(order.getId()));

        return order.getId();
    }

    public void submitOrder(OrderId orderId) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));

        order.submit();  // Domain handles validation and state change

        orderRepository.save(order);
        events.publish(new OrderSubmittedEvent(order.getId()));
    }
}
```

## Key Differences

| Aspect | Anemic Model | Rich Domain Model |
|--------|-------------|-------------------|
| **Data** | Public getters/setters | Private with controlled access |
| **Behavior** | In services | In domain objects |
| **Validation** | In services | At domain boundaries |
| **Invariants** | Not enforced | Always enforced |
| **Testing** | Test services | Test domain objects |
| **Object state** | Can be invalid | Always valid |

## Detection Checklist

When reviewing code, flag Anemic Domain Models if:

- [ ] **[BLOCKER]** Domain objects have only getters/setters
- [ ] **[BLOCKER]** Services manipulate object internals directly
- [ ] **[BLOCKER]** Business rules are only in service classes
- [ ] **[MAJOR]** Public setters allow invalid state
- [ ] **[MAJOR]** Collections exposed directly (not defensive copies)
- [ ] **[MINOR]** No factory methods or builders for complex objects

## When Anemic is Acceptable

Not every application needs a rich domain model:

- **Simple CRUD applications**: No complex business rules
- **Data transformation pipelines**: Data flows through, not much logic
- **Integration layers**: Just moving data between systems
- **Prototypes**: Exploring the problem space

## Refactoring Steps

1. **Identify behaviors in services** that operate on a single domain object
2. **Move methods to domain object** (Extract Method + Move Method)
3. **Make setters private** or remove them
4. **Add validation in constructors/methods**
5. **Use factory methods** for complex construction
6. **Return defensive copies** for collections

```java
// Step 1: Identify
orderService.addItem(order, product, qty);

// Step 2: Move to domain
order.addItem(product, qty);

// Step 3: Make setter private
private void setStatus(OrderStatus status) { this.status = status; }

// Step 4: Add validation
public void addItem(Product product, int qty) {
    if (qty <= 0) throw new InvalidQuantityException(qty);
    ...
}

// Step 5: Factory method
public static Order create(OrderId id, CustomerId customerId) { ... }

// Step 6: Defensive copy
public List<OrderItem> getItems() {
    return Collections.unmodifiableList(items);
}
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Rich Domain Model** | The solution to anemic domain |
| **Domain-Driven Design** | Emphasizes rich domain models |
| **Service Layer** | Coordinates domain, doesn't contain logic |
| **Value Objects** | Part of rich domain model |

## References

- Martin Fowler, "AnemicDomainModel" - https://martinfowler.com/bliki/AnemicDomainModel.html
- Eric Evans, "Domain-Driven Design"
- Vaughn Vernon, "Implementing Domain-Driven Design"
