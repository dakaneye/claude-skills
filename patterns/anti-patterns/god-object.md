# God Object Anti-Pattern

> A class that knows too much or does too much. It has grown to become the center of the system, violating the Single Responsibility Principle.

## The Problem

A God Object:
- Has too many responsibilities
- Knows about too many other classes
- Is required by most of the system
- Grows continuously as features are added
- Is difficult to test, maintain, or reason about

## Symptoms

```
┌─────────────────────────────────────────────────────────────┐
│                     ApplicationManager                       │
│                                                             │
│  + loadConfiguration()                                      │
│  + saveConfiguration()                                      │
│  + connectToDatabase()                                      │
│  + executeQuery(sql)                                        │
│  + createUser(name, email)                                  │
│  + deleteUser(id)                                           │
│  + sendEmail(to, subject, body)                            │
│  + processPayment(amount, card)                            │
│  + generateReport()                                         │
│  + validateInput(data)                                      │
│  + formatOutput(data)                                       │
│  + handleError(error)                                       │
│  + logMessage(level, message)                              │
│  + ... 200 more methods ...                                │
│                                                             │
│  - config: Configuration                                    │
│  - dbConnection: Connection                                 │
│  - users: List<User>                                        │
│  - emailClient: EmailClient                                 │
│  - paymentGateway: PaymentGateway                          │
│  - ... 50 more fields ...                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                         ▲
     ┌───────────────────┼───────────────────┐
     │                   │                   │
  UserController    ReportService      PaymentProcessor
     │                   │                   │
     └───────────────────┴───────────────────┘
            Everyone depends on it!
```

## Warning Signs

| Sign | Example |
|------|---------|
| **Large file** | 2000+ lines of code |
| **Many dependencies** | 20+ imports/fields |
| **Generic name** | "Manager", "Helper", "Processor", "Handler" |
| **Difficult to test** | Needs 50 mocks to test one method |
| **Frequent changes** | Modified in every PR |
| **Circular dependencies** | A depends on God, God depends on A |

## Example: Before (God Object)

```java
// BAD: God Object
public class OrderManager {
    private DatabaseConnection db;
    private EmailService email;
    private PaymentGateway payments;
    private InventorySystem inventory;
    private ShippingService shipping;
    private TaxCalculator tax;
    private DiscountEngine discounts;
    private AuditLogger audit;
    private MetricsCollector metrics;
    private ConfigurationManager config;

    // Creates orders
    public Order createOrder(CreateOrderRequest request) { ... }

    // Validates orders
    public ValidationResult validateOrder(Order order) { ... }

    // Calculates pricing
    public Money calculateTotal(Order order) { ... }
    public Money calculateTax(Order order, Address address) { ... }
    public Money applyDiscounts(Order order, List<Coupon> coupons) { ... }

    // Processes payments
    public PaymentResult processPayment(Order order, PaymentMethod method) { ... }
    public void refundPayment(Order order) { ... }

    // Manages inventory
    public boolean checkInventory(List<OrderItem> items) { ... }
    public void reserveInventory(Order order) { ... }
    public void releaseInventory(Order order) { ... }

    // Handles shipping
    public ShippingQuote getShippingQuote(Order order, Address destination) { ... }
    public void scheduleShipment(Order order) { ... }
    public void trackShipment(Order order) { ... }

    // Sends notifications
    public void sendConfirmationEmail(Order order) { ... }
    public void sendShippingNotification(Order order) { ... }
    public void sendInvoice(Order order) { ... }

    // Generates reports
    public Report generateDailyReport() { ... }
    public Report generateMonthlyReport() { ... }

    // ... 50 more methods
}
```

## Example: After (Refactored)

```java
// GOOD: Single Responsibility classes

// Order creation and lifecycle
public class OrderService {
    private final OrderRepository orderRepository;
    private final OrderValidator validator;
    private final PricingService pricing;
    private final EventPublisher events;

    public Order createOrder(CreateOrderCommand command) {
        ValidationResult validation = validator.validate(command);
        if (!validation.isValid()) {
            throw new ValidationException(validation.getErrors());
        }

        Order order = Order.create(command);
        order.calculateTotal(pricing);

        orderRepository.save(order);
        events.publish(new OrderCreatedEvent(order));

        return order;
    }
}

// Pricing calculations only
public class PricingService {
    private final TaxCalculator taxCalculator;
    private final DiscountEngine discountEngine;

    public Money calculateTotal(Order order) {
        Money subtotal = order.getItemsTotal();
        Money discount = discountEngine.calculate(order);
        Money tax = taxCalculator.calculate(order);

        return subtotal.subtract(discount).add(tax);
    }
}

// Payment processing only
public class PaymentService {
    private final PaymentGateway gateway;
    private final OrderRepository orders;
    private final EventPublisher events;

    public PaymentResult processPayment(OrderId orderId, PaymentMethod method) {
        Order order = orders.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));

        PaymentResult result = gateway.charge(method, order.getTotal());

        if (result.isSuccessful()) {
            order.markAsPaid(result.getTransactionId());
            orders.save(order);
            events.publish(new PaymentCompletedEvent(order, result));
        }

        return result;
    }
}

// Inventory management only
public class InventoryService {
    private final InventoryRepository inventory;
    private final EventPublisher events;

    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        reserveInventory(event.getOrder().getItems());
    }

    public void reserveInventory(List<OrderItem> items) {
        for (OrderItem item : items) {
            inventory.reserve(item.getProductId(), item.getQuantity());
        }
    }
}

// Notification handling only
public class NotificationService {
    private final EmailClient emailClient;
    private final TemplateEngine templates;

    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        sendConfirmationEmail(event.getOrder());
    }

    @EventListener
    public void onOrderShipped(OrderShippedEvent event) {
        sendShippingNotification(event.getOrder());
    }
}
```

## Refactoring Strategies

### 1. Extract by Responsibility
Group related methods into focused classes.

```java
// Extract all pricing methods
OrderManager.calculateTotal()    → PricingService.calculateTotal()
OrderManager.calculateTax()      → TaxCalculator.calculate()
OrderManager.applyDiscounts()    → DiscountEngine.apply()
```

### 2. Extract by Entity
Create services around domain entities.

```java
// Methods for each entity
OrderManager.createOrder()       → OrderService.create()
OrderManager.reserveInventory()  → InventoryService.reserve()
OrderManager.processPayment()    → PaymentService.process()
```

### 3. Use Domain Events
Decouple with events instead of direct calls.

```java
// Before: Direct coupling
orderManager.createOrder(request);
orderManager.reserveInventory(order);
orderManager.sendConfirmation(order);

// After: Event-driven
orderService.createOrder(command);  // Publishes OrderCreatedEvent
// Listeners handle inventory, notifications, etc.
```

## Detection Checklist

When reviewing code, flag God Objects if:

- [ ] **[BLOCKER]** Class has >20 public methods
- [ ] **[BLOCKER]** Class has >15 dependencies (fields/constructor params)
- [ ] **[BLOCKER]** Class file is >500 lines
- [ ] **[MAJOR]** Class name ends in "Manager", "Handler", "Processor", "Helper"
- [ ] **[MAJOR]** Class touches >3 different bounded contexts
- [ ] **[MAJOR]** >50% of PRs modify this file
- [ ] **[MINOR]** Test file for this class is >1000 lines

## Prevention

1. **Start with clear boundaries**: Define responsibilities before coding
2. **Apply Single Responsibility**: Each class does one thing
3. **Use composition**: Delegate to focused collaborators
4. **Review class growth**: Flag when classes grow too large
5. **Refactor early**: Don't wait until it's unmanageable

## Related Anti-Patterns

| Anti-Pattern | Relationship |
|--------------|-------------|
| **Blob** | Same as God Object |
| **Spaghetti Code** | Often found inside God Objects |
| **Feature Envy** | God Object has features that belong elsewhere |
| **Inappropriate Intimacy** | God Object knows too much about others |

## References

- Robert Martin, "Clean Code" - Single Responsibility Principle
- Martin Fowler, "Refactoring" - Extract Class
- Michael Feathers, "Working Effectively with Legacy Code"
