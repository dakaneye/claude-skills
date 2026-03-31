# Aggregate Pattern

> A cluster of domain objects that can be treated as a single unit. One entity is the aggregate root; external references can only refer to the root.

**Source**: Eric Evans, "Domain-Driven Design" (2003)

## Intent

Define boundaries around closely related domain objects to ensure consistency. The aggregate root controls all access and maintains invariants across the cluster.

## Key Concepts

- **Aggregate Root**: The main entity through which all access occurs
- **Boundary**: Objects inside are only accessible through the root
- **Invariants**: Business rules that must always be true
- **Transaction Boundary**: Each aggregate is a unit of consistency

## When to Use

- Group of objects that must be consistent together
- Clear business rules span multiple objects
- Need to define transaction boundaries
- Complex domain with interconnected objects

## When NOT to Use

- Simple CRUD without invariants
- Objects are independently consistent
- Premature optimization (start simple, extract aggregates)

## Structure

```
┌─────────────────────────────────────────────┐
│               Order Aggregate               │
│  ┌─────────────────────────────────────┐   │
│  │          Order (Root)               │   │
│  │  - orderId                          │   │
│  │  - customerId (reference only)      │   │
│  │  - status                           │   │
│  │  + addItem(product, qty)            │   │
│  │  + removeItem(itemId)               │   │
│  │  + submit()                         │   │
│  └─────────────────────────────────────┘   │
│                    │                        │
│         ┌─────────┴─────────┐              │
│         │                   │              │
│    ┌────┴────┐        ┌─────┴─────┐        │
│    │OrderItem│        │OrderItem  │        │
│    │(Entity) │        │(Entity)   │        │
│    └─────────┘        └───────────┘        │
│                                            │
│    ┌────────────────┐                      │
│    │ ShippingAddress│  (Value Object)      │
│    └────────────────┘                      │
└─────────────────────────────────────────────┘

External code can ONLY access Order (the root).
Cannot directly modify OrderItem or ShippingAddress.
```

## Language Examples

### Java

```java
// Value Object
public record Money(BigDecimal amount, Currency currency) {
    public Money {
        Objects.requireNonNull(amount);
        Objects.requireNonNull(currency);
        if (amount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Amount cannot be negative");
        }
    }

    public Money add(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("Currency mismatch");
        }
        return new Money(amount.add(other.amount), currency);
    }
}

// Entity within aggregate
public class OrderItem {
    private final OrderItemId id;
    private final ProductId productId;
    private final String productName;
    private int quantity;
    private final Money unitPrice;

    // Package-private constructor - only Order can create
    OrderItem(OrderItemId id, ProductId productId, String productName,
              int quantity, Money unitPrice) {
        this.id = id;
        this.productId = productId;
        this.productName = productName;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
    }

    // Package-private - only Order can modify
    void updateQuantity(int newQuantity) {
        if (newQuantity <= 0) {
            throw new IllegalArgumentException("Quantity must be positive");
        }
        this.quantity = newQuantity;
    }

    public Money getLineTotal() {
        return new Money(
            unitPrice.amount().multiply(BigDecimal.valueOf(quantity)),
            unitPrice.currency()
        );
    }

    // Getters (public)
    public OrderItemId getId() { return id; }
    public ProductId getProductId() { return productId; }
    public int getQuantity() { return quantity; }
}

// Aggregate Root
public class Order {
    private final OrderId id;
    private final CustomerId customerId;
    private OrderStatus status;
    private final List<OrderItem> items;
    private ShippingAddress shippingAddress;
    private final Instant createdAt;

    // Factory method ensures valid initial state
    public static Order create(OrderId id, CustomerId customerId) {
        return new Order(id, customerId);
    }

    private Order(OrderId id, CustomerId customerId) {
        this.id = Objects.requireNonNull(id);
        this.customerId = Objects.requireNonNull(customerId);
        this.status = OrderStatus.DRAFT;
        this.items = new ArrayList<>();
        this.createdAt = Instant.now();
    }

    // All modifications go through the root
    public void addItem(ProductId productId, String productName,
                        int quantity, Money unitPrice) {
        ensureModifiable();

        // Check invariant: no duplicate products
        items.stream()
            .filter(item -> item.getProductId().equals(productId))
            .findFirst()
            .ifPresentOrElse(
                item -> item.updateQuantity(item.getQuantity() + quantity),
                () -> items.add(new OrderItem(
                    OrderItemId.generate(),
                    productId,
                    productName,
                    quantity,
                    unitPrice
                ))
            );
    }

    public void removeItem(OrderItemId itemId) {
        ensureModifiable();
        items.removeIf(item -> item.getId().equals(itemId));
    }

    public void updateItemQuantity(OrderItemId itemId, int quantity) {
        ensureModifiable();
        OrderItem item = findItem(itemId);
        item.updateQuantity(quantity);
    }

    public void setShippingAddress(ShippingAddress address) {
        ensureModifiable();
        this.shippingAddress = Objects.requireNonNull(address);
    }

    public void submit() {
        // Invariant: must have items
        if (items.isEmpty()) {
            throw new OrderInvariantViolation("Cannot submit empty order");
        }
        // Invariant: must have shipping address
        if (shippingAddress == null) {
            throw new OrderInvariantViolation("Shipping address required");
        }
        // Invariant: minimum order amount
        if (getTotal().amount().compareTo(new BigDecimal("10.00")) < 0) {
            throw new OrderInvariantViolation("Minimum order is $10.00");
        }

        this.status = OrderStatus.SUBMITTED;
    }

    public void cancel() {
        if (status == OrderStatus.SHIPPED) {
            throw new OrderInvariantViolation("Cannot cancel shipped order");
        }
        this.status = OrderStatus.CANCELLED;
    }

    // Calculated property
    public Money getTotal() {
        return items.stream()
            .map(OrderItem::getLineTotal)
            .reduce(Money::add)
            .orElse(new Money(BigDecimal.ZERO, Currency.getInstance("USD")));
    }

    // Return unmodifiable view
    public List<OrderItem> getItems() {
        return Collections.unmodifiableList(items);
    }

    private void ensureModifiable() {
        if (status != OrderStatus.DRAFT) {
            throw new OrderInvariantViolation(
                "Cannot modify order in status: " + status
            );
        }
    }

    private OrderItem findItem(OrderItemId itemId) {
        return items.stream()
            .filter(item -> item.getId().equals(itemId))
            .findFirst()
            .orElseThrow(() -> new OrderItemNotFoundException(itemId));
    }

    // Identity
    public OrderId getId() { return id; }
    public CustomerId getCustomerId() { return customerId; }
    public OrderStatus getStatus() { return status; }
}

// Repository per aggregate root
public interface OrderRepository {
    Optional<Order> findById(OrderId id);
    void save(Order order);
    void delete(OrderId id);
}
```

### Go

```go
// Value Object
type Money struct {
    amount   decimal.Decimal
    currency string
}

func NewMoney(amount decimal.Decimal, currency string) (Money, error) {
    if amount.LessThan(decimal.Zero) {
        return Money{}, errors.New("amount cannot be negative")
    }
    return Money{amount: amount, currency: currency}, nil
}

func (m Money) Add(other Money) (Money, error) {
    if m.currency != other.currency {
        return Money{}, errors.New("currency mismatch")
    }
    return Money{amount: m.amount.Add(other.amount), currency: m.currency}, nil
}

// Entity within aggregate
type OrderItem struct {
    id          OrderItemID
    productID   ProductID
    productName string
    quantity    int
    unitPrice   Money
}

func (i *OrderItem) LineTotal() Money {
    total := i.unitPrice.amount.Mul(decimal.NewFromInt(int64(i.quantity)))
    return Money{amount: total, currency: i.unitPrice.currency}
}

// Aggregate Root
type Order struct {
    id              OrderID
    customerID      CustomerID
    status          OrderStatus
    items           []*OrderItem
    shippingAddress *ShippingAddress
    createdAt       time.Time
}

func NewOrder(id OrderID, customerID CustomerID) *Order {
    return &Order{
        id:         id,
        customerID: customerID,
        status:     OrderStatusDraft,
        items:      make([]*OrderItem, 0),
        createdAt:  time.Now(),
    }
}

func (o *Order) AddItem(productID ProductID, name string, qty int, price Money) error {
    if err := o.ensureModifiable(); err != nil {
        return err
    }

    // Check for existing item
    for _, item := range o.items {
        if item.productID == productID {
            item.quantity += qty
            return nil
        }
    }

    o.items = append(o.items, &OrderItem{
        id:          NewOrderItemID(),
        productID:   productID,
        productName: name,
        quantity:    qty,
        unitPrice:   price,
    })
    return nil
}

func (o *Order) Submit() error {
    // Invariants
    if len(o.items) == 0 {
        return errors.New("cannot submit empty order")
    }
    if o.shippingAddress == nil {
        return errors.New("shipping address required")
    }

    total := o.Total()
    minOrder, _ := NewMoney(decimal.NewFromFloat(10.00), "USD")
    if total.amount.LessThan(minOrder.amount) {
        return errors.New("minimum order is $10.00")
    }

    o.status = OrderStatusSubmitted
    return nil
}

func (o *Order) Total() Money {
    total := Money{amount: decimal.Zero, currency: "USD"}
    for _, item := range o.items {
        total, _ = total.Add(item.LineTotal())
    }
    return total
}

func (o *Order) ensureModifiable() error {
    if o.status != OrderStatusDraft {
        return fmt.Errorf("cannot modify order in status: %s", o.status)
    }
    return nil
}

// Items returns a copy to prevent external modification
func (o *Order) Items() []OrderItem {
    result := make([]OrderItem, len(o.items))
    for i, item := range o.items {
        result[i] = *item
    }
    return result
}
```

## Review Checklist

### Design
- [ ] **[BLOCKER]** Single aggregate root identified
- [ ] **[BLOCKER]** Clear consistency boundary defined
- [ ] **[MAJOR]** Invariants enforced through root
- [ ] **[MAJOR]** External references only to root

### Implementation
- [ ] **[BLOCKER]** Root controls all modifications
- [ ] **[BLOCKER]** Internal entities not directly accessible
- [ ] **[MAJOR]** Repository per aggregate root
- [ ] **[MINOR]** Factory method for creation

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Aggregate too large (>10 entities)
- [ ] **[BLOCKER]** Cross-aggregate transactions
- [ ] **[MAJOR]** Direct access to internal entities
- [ ] **[MAJOR]** Mutable getters (return copies or immutable)

## Common Mistakes

### 1. Aggregate Too Large
```java
// BAD: Too many things in one aggregate
class Customer {
    List<Order> orders;        // Could be millions!
    List<Address> addresses;
    List<PaymentMethod> paymentMethods;
    List<Review> reviews;
}

// GOOD: Separate aggregates with references
class Customer {
    CustomerId id;
    // ... customer-specific data
}

class Order {
    CustomerId customerId;  // Reference, not contained
    // ... order-specific data
}
```

### 2. Cross-Aggregate Transactions
```java
// BAD: Modifying multiple aggregates in one transaction
@Transactional
void transferMoney(AccountId from, AccountId to, Money amount) {
    Account fromAccount = accountRepo.findById(from);
    Account toAccount = accountRepo.findById(to);
    fromAccount.debit(amount);
    toAccount.credit(amount);  // Two aggregates!
}

// GOOD: Eventual consistency with domain events
void initiateTransfer(AccountId from, AccountId to, Money amount) {
    Account fromAccount = accountRepo.findById(from);
    fromAccount.initiateTransfer(to, amount);  // Publishes TransferInitiated event
    accountRepo.save(fromAccount);
    // Event handler credits the other account
}
```

## Aggregate Sizing Guidelines

| Sign | Meaning |
|------|---------|
| >10 entities | Too large, split it |
| Frequent cross-aggregate refs | Consider merging or redesigning |
| Performance issues loading | Too large |
| Contention on updates | Too large |
| Difficulty maintaining invariants | Boundary wrong |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Repository** | One repository per aggregate root |
| **Factory** | Creates aggregates in valid state |
| **Domain Events** | Communicate between aggregates |
| **Entity** | Aggregate root is an entity |
| **Value Object** | Often contained in aggregates |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [jMolecules](https://github.com/xmolecules/jmolecules) | DDD annotations and interfaces (`@AggregateRoot`, `@Entity`, `@ValueObject`) |
| **Java** | [Axon Framework](https://www.axoniq.io/) | Full DDD/CQRS/ES framework with aggregate support |
| **Java** | [Spring Data DDD](https://spring.io/projects/spring-data) | Repository per aggregate, `@DomainEvents` |
| **Go** | Standard Library | Go favors explicit modeling; no dominant DDD library |
| **Python** | [eventsourcing](https://eventsourcing.readthedocs.io/) | Aggregate base classes with event sourcing |
| **.NET** | [EventFlow](https://github.com/eventflow/EventFlow) | DDD + CQRS + ES with aggregate roots |
| **.NET** | [MediatR](https://github.com/jbogard/MediatR) | Supports domain event dispatch from aggregates |
| **TypeScript** | [NestJS CQRS](https://docs.nestjs.com/recipes/cqrs) | Aggregate roots with command handlers |

**Note**: DDD Aggregates are primarily a modeling pattern. Libraries provide annotations/interfaces for documentation and infrastructure (repositories, events), but the core aggregate logic is hand-coded.

## References

- Eric Evans, "Domain-Driven Design" Chapter 6
- Vaughn Vernon, "Implementing Domain-Driven Design" Chapter 10
- https://martinfowler.com/bliki/DDD_Aggregate.html
