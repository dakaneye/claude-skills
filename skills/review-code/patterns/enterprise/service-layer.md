# Service Layer Pattern

> Defines an application's boundary with a layer of services that establishes a set of available operations and coordinates the application's response in each operation.

**Source**: Martin Fowler, "Patterns of Enterprise Application Architecture" (2002)

## Intent

Define an application's boundary and its set of available operations from the perspective of interfacing client layers. Coordinate responses and manage transactions.

## When to Use

- Multiple clients need the same operations (web, API, CLI)
- Need to coordinate multiple domain objects/repositories
- Transaction management required
- Need clear application boundary

## When NOT to Use

- Simple CRUD with single domain object
- No coordination needed (single repository call)
- Anemic domain model risk (all logic in services)

## Structure

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│   (Web, API, CLI, Message Queue)        │
└────────────────┬────────────────────────┘
                 │
┌────────────────┴────────────────────────┐
│           Service Layer                 │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │ UserService │  │ OrderService     │  │
│  └─────────────┘  └──────────────────┘  │
└────────────────┬────────────────────────┘
                 │
┌────────────────┴────────────────────────┐
│           Domain Layer                  │
│  ┌──────┐  ┌───────┐  ┌────────────┐   │
│  │ User │  │ Order │  │ Repository │   │
│  └──────┘  └───────┘  └────────────┘   │
└─────────────────────────────────────────┘
```

## Language Examples

### Java

```java
// Service Layer - Application boundary
@Service
@Transactional
public class OrderService {
    private final OrderRepository orderRepository;
    private final CustomerRepository customerRepository;
    private final InventoryService inventoryService;
    private final PaymentGateway paymentGateway;
    private final NotificationService notificationService;
    private final EventPublisher eventPublisher;

    public OrderService(
            OrderRepository orderRepository,
            CustomerRepository customerRepository,
            InventoryService inventoryService,
            PaymentGateway paymentGateway,
            NotificationService notificationService,
            EventPublisher eventPublisher) {
        this.orderRepository = orderRepository;
        this.customerRepository = customerRepository;
        this.inventoryService = inventoryService;
        this.paymentGateway = paymentGateway;
        this.notificationService = notificationService;
        this.eventPublisher = eventPublisher;
    }

    /**
     * Place an order - coordinates multiple domain objects and services.
     *
     * @param command the order command
     * @return the created order
     * @throws CustomerNotFoundException if customer not found
     * @throws InsufficientInventoryException if items not available
     * @throws PaymentFailedException if payment fails
     */
    public Order placeOrder(PlaceOrderCommand command) {
        // 1. Find customer
        Customer customer = customerRepository.findById(command.getCustomerId())
            .orElseThrow(() -> new CustomerNotFoundException(command.getCustomerId()));

        // 2. Check inventory
        for (OrderItem item : command.getItems()) {
            if (!inventoryService.isAvailable(item.getProductId(), item.getQuantity())) {
                throw new InsufficientInventoryException(item.getProductId());
            }
        }

        // 3. Create order (domain logic in Order)
        Order order = Order.create(customer, command.getItems());

        // 4. Process payment
        PaymentResult paymentResult = paymentGateway.charge(
            customer.getPaymentMethod(),
            order.getTotal()
        );

        if (!paymentResult.isSuccessful()) {
            throw new PaymentFailedException(paymentResult.getError());
        }

        order.markAsPaid(paymentResult.getTransactionId());

        // 5. Reserve inventory
        inventoryService.reserve(command.getItems());

        // 6. Persist order
        orderRepository.save(order);

        // 7. Publish event
        eventPublisher.publish(new OrderPlacedEvent(order.getId()));

        // 8. Send notification (async, don't fail order if this fails)
        try {
            notificationService.sendOrderConfirmation(customer, order);
        } catch (Exception e) {
            log.warn("Failed to send confirmation for order {}", order.getId(), e);
        }

        return order;
    }

    /**
     * Cancel an order.
     */
    public void cancelOrder(OrderId orderId, String reason) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));

        // Domain logic - Order decides if cancellable
        order.cancel(reason);

        // Coordinate side effects
        inventoryService.release(order.getItems());

        if (order.isPaid()) {
            paymentGateway.refund(order.getPaymentTransactionId());
        }

        orderRepository.save(order);

        eventPublisher.publish(new OrderCancelledEvent(orderId, reason));
    }

    /**
     * Query method - no coordination, just retrieval.
     */
    @Transactional(readOnly = true)
    public Optional<OrderDto> findOrder(OrderId orderId) {
        return orderRepository.findById(orderId)
            .map(OrderDto::fromDomain);
    }

    @Transactional(readOnly = true)
    public List<OrderDto> findOrdersByCustomer(CustomerId customerId) {
        return orderRepository.findByCustomerId(customerId)
            .stream()
            .map(OrderDto::fromDomain)
            .collect(Collectors.toList());
    }
}
```

### Go

```go
// Service layer
type OrderService struct {
    orders        OrderRepository
    customers     CustomerRepository
    inventory     InventoryService
    payments      PaymentGateway
    notifications NotificationService
    events        EventPublisher
    logger        *slog.Logger
}

func NewOrderService(
    orders OrderRepository,
    customers CustomerRepository,
    inventory InventoryService,
    payments PaymentGateway,
    notifications NotificationService,
    events EventPublisher,
    logger *slog.Logger,
) *OrderService {
    return &OrderService{
        orders:        orders,
        customers:     customers,
        inventory:     inventory,
        payments:      payments,
        notifications: notifications,
        events:        events,
        logger:        logger,
    }
}

// PlaceOrder coordinates the order placement workflow
func (s *OrderService) PlaceOrder(ctx context.Context, cmd PlaceOrderCommand) (*Order, error) {
    // Find customer
    customer, err := s.customers.FindByID(ctx, cmd.CustomerID)
    if err != nil {
        return nil, fmt.Errorf("find customer: %w", err)
    }

    // Check inventory
    for _, item := range cmd.Items {
        available, err := s.inventory.IsAvailable(ctx, item.ProductID, item.Quantity)
        if err != nil {
            return nil, fmt.Errorf("check inventory: %w", err)
        }
        if !available {
            return nil, ErrInsufficientInventory{ProductID: item.ProductID}
        }
    }

    // Create order (domain logic in Order)
    order, err := NewOrder(customer, cmd.Items)
    if err != nil {
        return nil, fmt.Errorf("create order: %w", err)
    }

    // Process payment
    paymentResult, err := s.payments.Charge(ctx, customer.PaymentMethod, order.Total())
    if err != nil {
        return nil, fmt.Errorf("charge payment: %w", err)
    }

    order.MarkAsPaid(paymentResult.TransactionID)

    // Reserve inventory
    if err := s.inventory.Reserve(ctx, cmd.Items); err != nil {
        // Refund on failure
        _ = s.payments.Refund(ctx, paymentResult.TransactionID)
        return nil, fmt.Errorf("reserve inventory: %w", err)
    }

    // Persist order
    if err := s.orders.Save(ctx, order); err != nil {
        // Release inventory on failure
        _ = s.inventory.Release(ctx, cmd.Items)
        _ = s.payments.Refund(ctx, paymentResult.TransactionID)
        return nil, fmt.Errorf("save order: %w", err)
    }

    // Publish event
    s.events.Publish(ctx, OrderPlacedEvent{OrderID: order.ID})

    // Send notification (don't fail order)
    go func() {
        if err := s.notifications.SendOrderConfirmation(ctx, customer, order); err != nil {
            s.logger.Warn("failed to send confirmation",
                "order_id", order.ID,
                "error", err,
            )
        }
    }()

    return order, nil
}
```

### Python

```python
from dataclasses import dataclass
from typing import List, Optional

@dataclass
class PlaceOrderCommand:
    customer_id: str
    items: List[OrderItem]

class OrderService:
    """Application service coordinating order operations."""

    def __init__(
        self,
        order_repo: OrderRepository,
        customer_repo: CustomerRepository,
        inventory: InventoryService,
        payments: PaymentGateway,
        notifications: NotificationService,
        events: EventPublisher,
    ):
        self._orders = order_repo
        self._customers = customer_repo
        self._inventory = inventory
        self._payments = payments
        self._notifications = notifications
        self._events = events

    def place_order(self, command: PlaceOrderCommand) -> Order:
        """
        Place an order - coordinates multiple services.

        Raises:
            CustomerNotFoundError: If customer doesn't exist
            InsufficientInventoryError: If items not available
            PaymentFailedError: If payment fails
        """
        # Find customer
        customer = self._customers.find_by_id(command.customer_id)
        if not customer:
            raise CustomerNotFoundError(command.customer_id)

        # Check inventory
        for item in command.items:
            if not self._inventory.is_available(item.product_id, item.quantity):
                raise InsufficientInventoryError(item.product_id)

        # Create order (domain logic)
        order = Order.create(customer, command.items)

        # Process payment
        payment_result = self._payments.charge(
            customer.payment_method,
            order.total
        )

        if not payment_result.successful:
            raise PaymentFailedError(payment_result.error)

        order.mark_as_paid(payment_result.transaction_id)

        # Reserve inventory
        self._inventory.reserve(command.items)

        # Persist
        self._orders.save(order)

        # Publish event
        self._events.publish(OrderPlacedEvent(order.id))

        return order
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Service coordinates multiple domain objects/repositories
- [ ] **[MAJOR]** Multiple clients need same operations
- [ ] **[MINOR]** Transaction boundaries needed

### Correct Implementation
- [ ] **[BLOCKER]** Service doesn't contain domain logic (delegates to domain)
- [ ] **[BLOCKER]** Service methods represent use cases, not CRUD
- [ ] **[MAJOR]** Proper error handling and transaction management
- [ ] **[MAJOR]** Clear interface for clients

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** All business logic in service (anemic domain)
- [ ] **[MAJOR]** Services calling other services (create shared dependency)
- [ ] **[MAJOR]** Service per entity (should be per use case/aggregate)
- [ ] **[MINOR]** Mixing command and query responsibilities

## Common Mistakes

### 1. Anemic Domain Model
```java
// BAD: All logic in service, domain is just data
class OrderService {
    void placeOrder(Order order) {
        // Business rules in service!
        if (order.getTotal().compareTo(maxOrderAmount) > 0) {
            throw new OrderTooLargeException();
        }
        if (order.getItems().isEmpty()) {
            throw new EmptyOrderException();
        }
        // ... more rules
    }
}

// GOOD: Domain contains business logic
class Order {
    static Order create(Customer customer, List<OrderItem> items) {
        if (items.isEmpty()) {
            throw new EmptyOrderException();
        }
        // Domain logic here
        return new Order(customer, items);
    }
}

class OrderService {
    Order placeOrder(PlaceOrderCommand cmd) {
        // Service only coordinates
        Customer customer = customerRepo.findById(cmd.getCustomerId());
        Order order = Order.create(customer, cmd.getItems());  // Domain logic
        orderRepo.save(order);
        return order;
    }
}
```

### 2. Service per Entity
```java
// BAD: Service per entity (CRUD wrapper)
class UserService { /* CRUD for User */ }
class AddressService { /* CRUD for Address */ }
class ProfileService { /* CRUD for Profile */ }

// GOOD: Service per use case / aggregate
class UserRegistrationService {
    void registerUser(RegisterUserCommand cmd) {
        // Coordinates User, Address, Profile
    }
}

class UserProfileService {
    void updateProfile(UpdateProfileCommand cmd) {
        // Coordinates related changes
    }
}
```

## Service Layer vs. Domain Service

| Service Layer | Domain Service |
|---------------|----------------|
| Application boundary | Pure domain logic |
| Coordinates use cases | Stateless domain operations |
| Handles transactions | No infrastructure concerns |
| Works with DTOs at edges | Works with domain objects |
| One per use case area | One per domain concept |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Repository** | Service uses repositories for persistence |
| **Unit of Work** | Service may manage unit of work |
| **Domain Events** | Service publishes events |
| **CQRS** | Separates command services from query services |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Framework](https://spring.io/projects/spring-framework) | `@Service`, `@Transactional` annotations for service layer |
| **Java** | [Jakarta EE](https://jakarta.ee/) | `@Stateless`, `@TransactionAttribute` for EJB services |
| **Java** | [Micronaut](https://micronaut.io/) | `@Singleton` services with compile-time DI |
| **Go** | Standard Library | Interfaces and structs - no framework needed |
| **Go** | [Wire](https://github.com/google/wire) | Compile-time dependency injection for service wiring |
| **Python** | [FastAPI](https://fastapi.tiangolo.com/) | Dependency injection for service classes |
| **Python** | [injector](https://injector.readthedocs.io/) | Dependency injection framework for service composition |
| **JavaScript** | [NestJS](https://nestjs.com/) | `@Injectable()` services with decorators |
| **JavaScript** | [TypeDI](https://github.com/typestack/typedi) | Dependency injection for service layer organization |
| **.NET** | [ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/) | Built-in DI container for service registration |

**Note**: The Service Layer is an organizational pattern more than something requiring a library. Frameworks help with dependency injection, transaction management, and service lifecycle, but the pattern itself is implemented through code structure.

## References

- Fowler, "Patterns of Enterprise Application Architecture" p.133
- https://martinfowler.com/eaaCatalog/serviceLayer.html
