# Clean Architecture

> The dependency rule: source code dependencies must point only inward, toward higher-level policies.

**Source**: Robert C. Martin, "Clean Architecture" (2017)

## Intent

Organize code into concentric layers where dependencies flow inward. Inner layers contain business logic and are independent of outer layers (frameworks, databases, UI).

## Key Principles

- **Dependency Rule**: Dependencies point inward only
- **Independence**: Business rules don't know about UI, database, or frameworks
- **Testability**: Business logic testable without external dependencies
- **Flexibility**: Easy to swap frameworks, databases, UIs

## The Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Frameworks & Drivers                      │
│  (Web, UI, Database, External Services, Devices)            │
├─────────────────────────────────────────────────────────────┤
│                    Interface Adapters                        │
│  (Controllers, Gateways, Presenters, Repositories)          │
├─────────────────────────────────────────────────────────────┤
│                    Application Business Rules                │
│  (Use Cases / Application Services)                         │
├─────────────────────────────────────────────────────────────┤
│                    Enterprise Business Rules                 │
│  (Entities / Domain Objects)                                │
└─────────────────────────────────────────────────────────────┘

Dependencies flow INWARD only (outer → inner)
```

## When to Use

- Long-lived applications expected to evolve
- Need to support multiple UIs or APIs
- Business logic is complex and valuable
- Want to defer framework decisions
- Need comprehensive testability

## When NOT to Use

- Simple CRUD applications
- Prototypes or throwaway code
- Small scripts or utilities
- When speed to market overrides maintainability
- Team unfamiliar with the pattern (adds complexity)

## Language Examples

### Java

```java
// ===== ENTITIES (Innermost - no dependencies) =====
package com.company.domain;

public class Order {
    private final OrderId id;
    private final CustomerId customerId;
    private OrderStatus status;
    private final List<OrderItem> items;
    private Money total;

    // Pure business logic - no framework annotations
    public void addItem(Product product, int quantity) {
        if (status != OrderStatus.DRAFT) {
            throw new OrderNotModifiableException(id);
        }
        items.add(new OrderItem(product.getId(), quantity, product.getPrice()));
        recalculateTotal();
    }

    public void submit() {
        if (items.isEmpty()) {
            throw new EmptyOrderException();
        }
        this.status = OrderStatus.SUBMITTED;
    }

    private void recalculateTotal() {
        this.total = items.stream()
            .map(OrderItem::getLineTotal)
            .reduce(Money.ZERO, Money::add);
    }
}

// ===== USE CASES (Application Business Rules) =====
package com.company.application;

// Input port (interface defined by application layer)
public interface PlaceOrderUseCase {
    OrderId execute(PlaceOrderCommand command);
}

// Output port (interface defined by application layer)
public interface OrderRepository {
    Optional<Order> findById(OrderId id);
    void save(Order order);
}

public interface PaymentGateway {
    PaymentResult charge(CustomerId customerId, Money amount);
}

// Use case implementation
public class PlaceOrderInteractor implements PlaceOrderUseCase {
    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;
    private final OrderPresenter presenter;

    public PlaceOrderInteractor(
            OrderRepository orderRepository,
            PaymentGateway paymentGateway,
            OrderPresenter presenter) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
        this.presenter = presenter;
    }

    @Override
    public OrderId execute(PlaceOrderCommand command) {
        // Create domain object
        Order order = new Order(
            OrderId.generate(),
            command.getCustomerId()
        );

        // Apply business logic
        for (var item : command.getItems()) {
            order.addItem(item.getProduct(), item.getQuantity());
        }

        // Process payment
        PaymentResult payment = paymentGateway.charge(
            command.getCustomerId(),
            order.getTotal()
        );

        if (!payment.isSuccessful()) {
            throw new PaymentFailedException(payment.getError());
        }

        order.submit();

        // Persist
        orderRepository.save(order);

        // Present result
        presenter.presentOrderCreated(order);

        return order.getId();
    }
}

// ===== INTERFACE ADAPTERS =====
package com.company.adapters.web;

// Controller - adapts HTTP to use case
@RestController
@RequestMapping("/orders")
public class OrderController {
    private final PlaceOrderUseCase placeOrderUseCase;

    @PostMapping
    public ResponseEntity<OrderResponse> placeOrder(
            @RequestBody PlaceOrderRequest request) {
        // Adapt HTTP request to use case input
        PlaceOrderCommand command = new PlaceOrderCommand(
            new CustomerId(request.getCustomerId()),
            request.getItems().stream()
                .map(this::toOrderItem)
                .collect(toList())
        );

        OrderId orderId = placeOrderUseCase.execute(command);

        return ResponseEntity
            .created(URI.create("/orders/" + orderId))
            .body(new OrderResponse(orderId.toString()));
    }
}

// Repository implementation - adapts use case to database
package com.company.adapters.persistence;

@Repository
public class JpaOrderRepository implements OrderRepository {
    private final JpaOrderEntityRepository jpaRepository;
    private final OrderMapper mapper;

    @Override
    public Optional<Order> findById(OrderId id) {
        return jpaRepository.findById(id.getValue())
            .map(mapper::toDomain);  // Convert JPA entity to domain
    }

    @Override
    public void save(Order order) {
        OrderEntity entity = mapper.toEntity(order);
        jpaRepository.save(entity);
    }
}

// ===== FRAMEWORKS & DRIVERS (Outermost) =====
package com.company.infrastructure;

// JPA Entity - framework-specific
@Entity
@Table(name = "orders")
public class OrderEntity {
    @Id
    private UUID id;

    @Column(name = "customer_id")
    private UUID customerId;

    @Enumerated(EnumType.STRING)
    private String status;

    @OneToMany(cascade = CascadeType.ALL)
    private List<OrderItemEntity> items;

    // JPA annotations, getters, setters...
}

// Spring configuration
@Configuration
public class OrderConfiguration {
    @Bean
    public PlaceOrderUseCase placeOrderUseCase(
            OrderRepository orderRepository,
            PaymentGateway paymentGateway,
            OrderPresenter presenter) {
        return new PlaceOrderInteractor(
            orderRepository,
            paymentGateway,
            presenter
        );
    }
}
```

### Go

```go
// ===== ENTITIES =====
package domain

type Order struct {
    ID         OrderID
    CustomerID CustomerID
    Status     OrderStatus
    Items      []OrderItem
    Total      Money
}

func NewOrder(id OrderID, customerID CustomerID) *Order {
    return &Order{
        ID:         id,
        CustomerID: customerID,
        Status:     OrderStatusDraft,
        Items:      make([]OrderItem, 0),
        Total:      Money{},
    }
}

func (o *Order) AddItem(product Product, quantity int) error {
    if o.Status != OrderStatusDraft {
        return ErrOrderNotModifiable
    }
    o.Items = append(o.Items, OrderItem{
        ProductID: product.ID,
        Quantity:  quantity,
        Price:     product.Price,
    })
    o.recalculateTotal()
    return nil
}

func (o *Order) Submit() error {
    if len(o.Items) == 0 {
        return ErrEmptyOrder
    }
    o.Status = OrderStatusSubmitted
    return nil
}

// ===== USE CASES =====
package application

// Ports (interfaces defined by application layer)
type OrderRepository interface {
    FindByID(ctx context.Context, id domain.OrderID) (*domain.Order, error)
    Save(ctx context.Context, order *domain.Order) error
}

type PaymentGateway interface {
    Charge(ctx context.Context, customerID domain.CustomerID, amount domain.Money) (*PaymentResult, error)
}

// Use case
type PlaceOrderUseCase struct {
    orders   OrderRepository
    payments PaymentGateway
}

func NewPlaceOrderUseCase(orders OrderRepository, payments PaymentGateway) *PlaceOrderUseCase {
    return &PlaceOrderUseCase{
        orders:   orders,
        payments: payments,
    }
}

func (uc *PlaceOrderUseCase) Execute(ctx context.Context, cmd PlaceOrderCommand) (domain.OrderID, error) {
    order := domain.NewOrder(domain.NewOrderID(), cmd.CustomerID)

    for _, item := range cmd.Items {
        if err := order.AddItem(item.Product, item.Quantity); err != nil {
            return domain.OrderID{}, fmt.Errorf("add item: %w", err)
        }
    }

    result, err := uc.payments.Charge(ctx, cmd.CustomerID, order.Total)
    if err != nil {
        return domain.OrderID{}, fmt.Errorf("charge payment: %w", err)
    }
    if !result.Successful {
        return domain.OrderID{}, ErrPaymentFailed
    }

    if err := order.Submit(); err != nil {
        return domain.OrderID{}, fmt.Errorf("submit order: %w", err)
    }

    if err := uc.orders.Save(ctx, order); err != nil {
        return domain.OrderID{}, fmt.Errorf("save order: %w", err)
    }

    return order.ID, nil
}

// ===== ADAPTERS =====
package adapters

// HTTP handler adapts HTTP to use case
type OrderHandler struct {
    placeOrder *application.PlaceOrderUseCase
}

func (h *OrderHandler) HandlePlaceOrder(w http.ResponseWriter, r *http.Request) {
    var req PlaceOrderRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    cmd := application.PlaceOrderCommand{
        CustomerID: domain.CustomerID(req.CustomerID),
        Items:      mapItems(req.Items),
    }

    orderID, err := h.placeOrder.Execute(r.Context(), cmd)
    if err != nil {
        // Handle error appropriately
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(PlaceOrderResponse{
        OrderID: orderID.String(),
    })
}

// Repository adapter
type PostgresOrderRepository struct {
    db *sql.DB
}

func (r *PostgresOrderRepository) Save(ctx context.Context, order *domain.Order) error {
    // Convert domain to database representation and save
    _, err := r.db.ExecContext(ctx, `
        INSERT INTO orders (id, customer_id, status, total_amount)
        VALUES ($1, $2, $3, $4)
    `, order.ID, order.CustomerID, order.Status, order.Total.Amount)
    return err
}
```

## Package Structure

```
src/
├── domain/                 # Entities (innermost)
│   ├── order.go
│   ├── customer.go
│   └── money.go
│
├── application/           # Use Cases
│   ├── ports/            # Interfaces (input & output)
│   │   ├── input/
│   │   │   └── place_order.go
│   │   └── output/
│   │       ├── order_repository.go
│   │       └── payment_gateway.go
│   └── usecases/
│       └── place_order_interactor.go
│
├── adapters/              # Interface Adapters
│   ├── web/              # HTTP controllers
│   ├── persistence/      # Repository implementations
│   └── external/         # External service clients
│
└── infrastructure/        # Frameworks & Drivers
    ├── config/
    ├── database/
    └── web/
```

## Review Checklist

### Dependency Rule
- [ ] **[BLOCKER]** Inner layers have no imports from outer layers
- [ ] **[BLOCKER]** Entities have no framework dependencies
- [ ] **[MAJOR]** Use cases define their own interfaces (ports)
- [ ] **[MAJOR]** Adapters implement ports, not the other way around

### Layer Responsibilities
- [ ] **[BLOCKER]** Business logic only in Entities and Use Cases
- [ ] **[MAJOR]** Controllers only translate and delegate
- [ ] **[MAJOR]** Repositories only handle persistence, no business logic
- [ ] **[MINOR]** Each layer has clear, single responsibility

### Testability
- [ ] **[MAJOR]** Use cases testable with mock ports
- [ ] **[MAJOR]** Entities testable in isolation
- [ ] **[MINOR]** Integration tests for adapters

## Common Mistakes

### 1. Framework Annotations in Domain
```java
// BAD: Domain polluted with framework
@Entity
public class Order {
    @Id
    private UUID id;

    @Column
    private String status;
}

// GOOD: Pure domain object
public class Order {
    private final OrderId id;
    private OrderStatus status;
}

// Separate JPA entity in adapters layer
@Entity
public class OrderEntity { ... }
```

### 2. Use Case Depends on Controller
```java
// BAD: Use case knows about HTTP
public class PlaceOrderInteractor {
    public ResponseEntity<OrderResponse> execute(...) { }  // HTTP type!
}

// GOOD: Use case returns domain/application types
public class PlaceOrderInteractor {
    public OrderId execute(PlaceOrderCommand command) { }
}
```

### 3. Business Logic in Controllers
```java
// BAD: Business logic in controller
@PostMapping("/orders")
public ResponseEntity<?> placeOrder(@RequestBody OrderRequest request) {
    // Business rules in controller!
    if (request.getItems().isEmpty()) {
        return ResponseEntity.badRequest().build();
    }
    if (calculateTotal(request) < 10.00) {
        return ResponseEntity.badRequest().body("Minimum order is $10");
    }
    // ...
}

// GOOD: Controller only translates and delegates
@PostMapping("/orders")
public ResponseEntity<?> placeOrder(@RequestBody OrderRequest request) {
    try {
        OrderId id = placeOrderUseCase.execute(toCommand(request));
        return ResponseEntity.created(URI.create("/orders/" + id)).build();
    } catch (EmptyOrderException e) {
        return ResponseEntity.badRequest().build();
    }
}
```

## Clean Architecture vs. Hexagonal

| Aspect | Clean Architecture | Hexagonal |
|--------|-------------------|-----------|
| Layers | 4 concentric circles | 3 (domain, ports, adapters) |
| Focus | Dependency direction | Ports and adapters |
| Terminology | Entities, Use Cases, Adapters | Domain, Ports, Adapters |
| Origin | Robert Martin | Alistair Cockburn |
| Essentially | Same concepts, different framing |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Hexagonal Architecture** | Alternative/complementary framing |
| **Repository** | Used in adapters layer |
| **Dependency Injection** | Required for wiring layers |
| **Adapter** | Core structural pattern used |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [ArchUnit](https://www.archunit.org/) | Architecture testing to enforce dependency rules |
| **Java** | [jMolecules](https://github.com/xmolecules/jmolecules) | Annotations for architectural concepts (`@Entity`, `@UseCase`) |
| **Java** | [Spring Modulith](https://spring.io/projects/spring-modulith) | Module boundary verification |
| **Java** | [MapStruct](https://mapstruct.org/) | Compile-time mappers between layers |
| **Go** | Standard Library | Interfaces enforce dependency inversion naturally |
| **Go** | [Wire](https://github.com/google/wire) | Compile-time DI for layer wiring |
| **Go** | [go-cleanarch](https://github.com/roblaszczak/go-cleanarch) | Linter for clean architecture rules |
| **Python** | [dependency-injector](https://python-dependency-injector.ets-labs.org/) | DI container for use case injection |
| **Python** | [import-linter](https://import-linter.readthedocs.io/) | Enforce import rules between layers |
| **JavaScript** | [InversifyJS](https://inversify.io/) | IoC container for dependency inversion |
| **JavaScript** | [ESLint](https://eslint.org/) + [eslint-plugin-import](https://github.com/import-js/eslint-plugin-import) | Import boundary enforcement |
| **.NET** | [MediatR](https://github.com/jbogard/MediatR) | Mediator pattern for use case dispatch |
| **.NET** | [NetArchTest](https://github.com/BenMorris/NetArchTest) | Architecture testing for .NET |

**Note**: Clean Architecture is enforced through code organization and dependency direction, not libraries. These tools help with dependency injection, layer mapping, and architecture verification but the pattern itself is implemented through interface definitions and package structure.

## References

- Robert C. Martin, "Clean Architecture" (2017)
- https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
