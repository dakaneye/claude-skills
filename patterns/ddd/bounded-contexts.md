# Bounded Context Pattern

> A description of a boundary (typically a subsystem or a team's work) within which a particular model is defined and applicable.

**Source**: Eric Evans, "Domain-Driven Design" (2003)

## Intent

Define explicit boundaries around different domain models. The same concept (e.g., "Customer") may have different meanings and attributes in different contexts.

## Key Concepts

- **Bounded Context**: A boundary where a domain model applies
- **Ubiquitous Language**: Shared vocabulary within a context
- **Context Map**: Shows relationships between bounded contexts
- **Context Boundaries**: Typically align with team boundaries

## The Problem It Solves

```
Without Bounded Contexts:
┌─────────────────────────────────────────────────────┐
│                 Single "Customer" Model             │
│  - id                                               │
│  - name                                             │
│  - email                                            │
│  - shippingAddress      (Sales needs this)          │
│  - creditLimit          (Accounting needs this)     │
│  - supportTickets[]     (Support needs this)        │
│  - purchaseHistory[]    (Marketing needs this)      │
│  - employeeDiscount     (HR needs this)             │
│  ... becomes a MONSTER with 100+ fields            │
└─────────────────────────────────────────────────────┘

With Bounded Contexts:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│    Sales     │  │  Accounting  │  │   Support    │
│   Context    │  │   Context    │  │   Context    │
├──────────────┤  ├──────────────┤  ├──────────────┤
│   Customer   │  │   Customer   │  │   Customer   │
│ - id         │  │ - id         │  │ - id         │
│ - name       │  │ - accountNum │  │ - name       │
│ - shipAddr   │  │ - creditLimit│  │ - email      │
│ - orders[]   │  │ - balance    │  │ - tickets[]  │
└──────────────┘  └──────────────┘  └──────────────┘
Same concept, different models, clear boundaries
```

## When to Use

- Large domain with multiple subdomains
- Different teams working on same system
- Same terminology means different things
- Model is becoming a "God object"

## When NOT to Use

- Small domain with single team
- Clear, consistent terminology throughout
- Premature - start with one model, split when needed

## Context Relationships

### Shared Kernel
Two contexts share a subset of the model:
```
┌──────────────┐
│   Context A  │──┐
└──────────────┘  │  ┌────────────┐
                  ├─▶│Shared Model│
┌──────────────┐  │  └────────────┘
│   Context B  │──┘
└──────────────┘
```

### Customer-Supplier
Upstream context provides what downstream needs:
```
┌──────────────┐        ┌──────────────┐
│   Upstream   │───────▶│  Downstream  │
│  (Supplier)  │        │  (Customer)  │
└──────────────┘        └──────────────┘
```

### Conformist
Downstream conforms to upstream model:
```
┌──────────────┐        ┌──────────────┐
│   Upstream   │───────▶│  Downstream  │
│              │        │ (Conformist) │
└──────────────┘        └──────────────┘
```

### Anti-Corruption Layer (ACL)
Translation layer protects context from external model:
```
┌──────────────┐   ┌─────┐   ┌──────────────┐
│   External   │──▶│ ACL │──▶│  Our Context │
│   Context    │   └─────┘   │  (Protected) │
└──────────────┘             └──────────────┘
```

### Published Language
Contexts communicate via shared interchange format:
```
┌──────────────┐        ┌──────────────┐
│   Context A  │◀──────▶│   Context B  │
└──────────────┘        └──────────────┘
        │                      │
        └────────┬─────────────┘
                 │
        ┌────────┴────────┐
        │ Published Lang  │
        │ (JSON/Proto/XML)│
        └─────────────────┘
```

## Language Examples

### Java (Multiple Contexts in Monolith)

```java
// ===== SALES CONTEXT =====
package com.company.sales.domain;

// Customer in Sales context
public class Customer {
    private CustomerId id;
    private String name;
    private ShippingAddress shippingAddress;
    private List<Order> orders;

    public void placeOrder(Order order) {
        // Sales-specific behavior
        orders.add(order);
    }
}

// ===== ACCOUNTING CONTEXT =====
package com.company.accounting.domain;

// Same concept, different model
public class Customer {
    private CustomerId id;
    private String accountNumber;
    private Money creditLimit;
    private Money balance;

    public boolean canMakePurchase(Money amount) {
        return balance.add(amount).lessThan(creditLimit);
    }
}

// ===== ANTI-CORRUPTION LAYER =====
package com.company.sales.infrastructure.acl;

// Translates between Sales context and external CRM
public class CrmCustomerAdapter {
    private final CrmClient crmClient;

    public com.company.sales.domain.Customer fetchCustomer(CustomerId id) {
        // Fetch from external CRM
        CrmCustomerDto crmCustomer = crmClient.getCustomer(id.toString());

        // Translate to our domain model
        return new com.company.sales.domain.Customer(
            id,
            crmCustomer.getFullName(),  // CRM calls it "fullName", we call it "name"
            translateAddress(crmCustomer.getDeliveryAddress())
        );
    }

    private ShippingAddress translateAddress(CrmAddressDto crmAddress) {
        return new ShippingAddress(
            crmAddress.getLine1(),
            crmAddress.getLine2(),
            crmAddress.getCity(),
            crmAddress.getStateCode(),  // CRM uses "stateCode", we use "state"
            crmAddress.getZipCode()
        );
    }
}

// ===== CONTEXT MAP (Documentation) =====
/**
 * Context Map:
 *
 * [Sales Context] <---> [Accounting Context]
 *     Customer Events (Published Language)
 *
 * [Sales Context] <--- ACL --- [External CRM]
 *
 * [Sales Context] --> [Shipping Context]
 *     (Customer-Supplier: Sales provides OrderShipped events)
 */
```

### Microservices Implementation

```java
// ===== SALES SERVICE =====
// sales-service/src/main/java/...

@Entity
public class Customer {
    @Id private UUID id;
    private String name;
    @Embedded private ShippingAddress shippingAddress;

    // Sales-specific model
}

@RestController
public class SalesOrderController {
    @PostMapping("/orders")
    public OrderResponse placeOrder(@RequestBody PlaceOrderRequest request) {
        // Handle order
    }
}

// Published events (for other contexts)
public record OrderPlacedEvent(
    UUID orderId,
    UUID customerId,
    BigDecimal total,
    Instant timestamp
) {}

// ===== ACCOUNTING SERVICE =====
// accounting-service/src/main/java/...

@Entity
public class Customer {
    @Id private UUID id;
    private String accountNumber;
    private BigDecimal creditLimit;
    private BigDecimal balance;

    // Accounting-specific model
}

// Consumes events from Sales context
@KafkaListener(topics = "sales.orders")
public void onOrderPlaced(OrderPlacedEvent event) {
    Customer customer = customerRepository.findById(event.customerId())
        .orElseThrow();

    customer.recordPurchase(event.total());
    customerRepository.save(customer);
}
```

### Go (Anti-Corruption Layer)

```go
// Our domain model
package shipping

type Shipment struct {
    ID          ShipmentID
    OrderID     OrderID
    Destination Address
    Carrier     Carrier
    Status      ShipmentStatus
}

type Address struct {
    Street     string
    City       string
    State      string
    PostalCode string
    Country    string
}

// Anti-Corruption Layer for external carrier API
package shipping

type CarrierACL struct {
    fedexClient *fedex.Client
    upsClient   *ups.Client
}

// Translate from external carrier model to our domain
func (acl *CarrierACL) GetShipmentStatus(shipmentID ShipmentID, carrier Carrier) (ShipmentStatus, error) {
    switch carrier {
    case CarrierFedEx:
        return acl.translateFedExStatus(shipmentID)
    case CarrierUPS:
        return acl.translateUPSStatus(shipmentID)
    default:
        return ShipmentStatus{}, errors.New("unknown carrier")
    }
}

func (acl *CarrierACL) translateFedExStatus(id ShipmentID) (ShipmentStatus, error) {
    // FedEx uses different status codes
    fedexStatus, err := acl.fedexClient.TrackPackage(string(id))
    if err != nil {
        return ShipmentStatus{}, err
    }

    // Translate FedEx-specific statuses to our domain
    switch fedexStatus.StatusCode {
    case "PU": // FedEx: Picked Up
        return ShipmentStatusInTransit, nil
    case "IT": // FedEx: In Transit
        return ShipmentStatusInTransit, nil
    case "DL": // FedEx: Delivered
        return ShipmentStatusDelivered, nil
    case "DE": // FedEx: Delivery Exception
        return ShipmentStatusException, nil
    default:
        return ShipmentStatusUnknown, nil
    }
}
```

## Review Checklist

### Context Design
- [ ] **[BLOCKER]** Each context has clear boundaries
- [ ] **[BLOCKER]** Ubiquitous language defined per context
- [ ] **[MAJOR]** Context map documents relationships
- [ ] **[MAJOR]** ACL used for external/legacy systems

### Implementation
- [ ] **[BLOCKER]** No shared database tables across contexts
- [ ] **[BLOCKER]** Contexts communicate via events or APIs
- [ ] **[MAJOR]** Each context owns its data
- [ ] **[MINOR]** Published language documented

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Single "God model" used everywhere
- [ ] **[BLOCKER]** Direct database access across contexts
- [ ] **[MAJOR]** Same class used in multiple contexts
- [ ] **[MAJOR]** Missing ACL for external systems

## Common Mistakes

### 1. Shared Database
```
// BAD: Contexts share tables
┌──────────────┐     ┌──────────┐     ┌──────────────┐
│    Sales     │────▶│ customers│◀────│  Accounting  │
│   Context    │     │  (table) │     │   Context    │
└──────────────┘     └──────────┘     └──────────────┘

// GOOD: Each context owns its data
┌──────────────┐     ┌──────────────┐
│    Sales     │     │  Accounting  │
│ customers    │     │  customers   │
│  (table)     │     │   (table)    │
└──────────────┘     └──────────────┘
        │                   │
        └─────────┬─────────┘
             Events/API
```

### 2. No Anti-Corruption Layer
```java
// BAD: External model leaks into domain
public class OrderService {
    public void processOrder(ExternalCrmOrder crmOrder) {  // External type!
        // Domain is now coupled to CRM model
    }
}

// GOOD: ACL translates at boundary
public class OrderService {
    public void processOrder(Order order) {  // Our domain type
        // Domain is protected
    }
}

public class CrmOrderAdapter {  // ACL
    public Order translate(ExternalCrmOrder crmOrder) {
        return new Order(
            crmOrder.getOrderNumber(),
            translateCustomer(crmOrder.getClient()),  // Different names
            translateItems(crmOrder.getLineItems())
        );
    }
}
```

## Context Mapping Strategies

| Relationship | When to Use | Complexity |
|--------------|-------------|------------|
| **Shared Kernel** | Close collaboration, shared ownership | Low |
| **Customer-Supplier** | Upstream serves downstream needs | Medium |
| **Conformist** | Downstream accepts upstream model | Low |
| **ACL** | Protect from legacy/external systems | High |
| **Published Language** | Multiple consumers, API/events | Medium |
| **Separate Ways** | No integration needed | None |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Anti-Corruption Layer** | Protects context boundaries |
| **Aggregate** | Consistency boundary within context |
| **Domain Events** | Communication between contexts |
| **Microservices** | Often align with bounded contexts |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Modulith](https://spring.io/projects/spring-modulith) | Module boundaries with verification, event-based communication |
| **Java** | [jMolecules](https://github.com/xmolecules/jmolecules) | `@BoundedContext`, `@Module` annotations for documentation |
| **Java** | [ArchUnit](https://www.archunit.org/) | Enforce context boundaries via architecture tests |
| **Go** | Standard Library | Package structure naturally enforces boundaries |
| **Go** | [go-kit](https://gokit.io/) | Microservices toolkit supporting context separation |
| **Python** | [punq](https://github.com/bobthemighty/punq) | Lightweight DI for enforcing module boundaries |
| **.NET** | [MediatR](https://github.com/jbogard/MediatR) | Decoupled communication between bounded contexts |
| **.NET** | [NServiceBus](https://particular.net/nservicebus) | Service bus for context integration |
| **TypeScript** | [NestJS](https://docs.nestjs.com/modules) | Module system with encapsulation and DI |

**Note**: Bounded Contexts are primarily an architectural pattern. Libraries help enforce boundaries (ArchUnit, Spring Modulith) or facilitate communication (events, message buses), but the context design is hand-crafted.

## References

- Eric Evans, "Domain-Driven Design" Chapter 14
- Vaughn Vernon, "Implementing Domain-Driven Design" Chapter 3
- https://martinfowler.com/bliki/BoundedContext.html
