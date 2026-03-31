# Premature Abstraction Anti-Pattern

> Creating abstractions before understanding the problem domain. Building for hypothetical future needs instead of current requirements.

**Also known as**: Speculative Generality, YAGNI violation, Over-engineering

## The Problem

Premature abstraction:
- Adds complexity before it's needed
- Creates wrong abstractions (based on guesses, not experience)
- Makes code harder to understand and change
- Slows down initial development
- Often gets thrown away when real needs emerge

## The Rule of Three

**Don't abstract until you have 3 concrete examples.**

```
1st time: Just write the code
2nd time: Notice similarity, but wait
3rd time: NOW extract the abstraction

Why? You need 3 examples to see the TRUE pattern,
not the imagined one.
```

## Warning Signs

| Sign | Example |
|------|---------|
| **"In case we need..."** | Interface with one implementation |
| **"For flexibility..."** | Factory that creates one type |
| **"Might change later..."** | Strategy with one strategy |
| **"Future-proof..."** | 5 layers of indirection |
| **Frameworks for simple things** | DI framework for 3 classes |
| **Generic where specific works** | `List<Object>` everywhere |

## Examples: Premature Abstraction

### 1. Interface With One Implementation

```java
// PREMATURE: Interface when there's only one implementation
public interface UserRepository {
    User findById(Long id);
    void save(User user);
}

public class UserRepositoryImpl implements UserRepository {
    // Only implementation that will ever exist
}

// JUST DO THIS:
public class UserRepository {
    public User findById(Long id) { ... }
    public void save(User user) { ... }
}

// Extract interface WHEN you need a second implementation
```

### 2. Factory For One Type

```java
// PREMATURE: Factory that creates one thing
public interface NotificationFactory {
    Notification createNotification(NotificationRequest request);
}

public class NotificationFactoryImpl implements NotificationFactory {
    @Override
    public Notification createNotification(NotificationRequest request) {
        return new EmailNotification(request);  // Always this one
    }
}

// JUST DO THIS:
public class NotificationService {
    public void send(NotificationRequest request) {
        EmailNotification notification = new EmailNotification(request);
        notification.send();
    }
}

// Add factory WHEN you have multiple notification types
```

### 3. Strategy With One Strategy

```java
// PREMATURE: Over-engineered for one algorithm
public interface PricingStrategy {
    Money calculatePrice(Order order);
}

public class StandardPricingStrategy implements PricingStrategy {
    // Only pricing strategy in the entire system
}

public class PricingContext {
    private final PricingStrategy strategy;

    public Money calculate(Order order) {
        return strategy.calculatePrice(order);
    }
}

// JUST DO THIS:
public class PricingService {
    public Money calculatePrice(Order order) {
        // Just the calculation
        return order.getItems().stream()
            .map(this::calculateItemPrice)
            .reduce(Money.ZERO, Money::add);
    }
}

// Add Strategy pattern WHEN you have multiple pricing algorithms
```

### 4. Generic Base Classes

```java
// PREMATURE: Abstract base class for hypothetical reuse
public abstract class BaseEntity<ID> {
    protected ID id;
    protected Instant createdAt;
    protected Instant updatedAt;
    protected Long version;

    public abstract void validate();
    protected abstract void preSave();
    protected abstract void postSave();
    // ... 20 more abstract methods
}

public class User extends BaseEntity<Long> {
    // Now forced to implement methods that don't make sense
    @Override
    protected void preSave() { /* nothing */ }
    @Override
    protected void postSave() { /* nothing */ }
}

// JUST DO THIS:
public class User {
    private Long id;
    private String name;
    private String email;
    // What User actually needs
}

// Extract shared behavior WHEN you see actual duplication
```

### 5. Unnecessary Indirection Layers

```java
// PREMATURE: Too many layers
Controller → Facade → Service → Manager → Repository → DAO → Database

// User clicks "Save"
userController.save(dto);
    userFacade.save(dto);  // Just calls service
        userService.save(dto);  // Just calls manager
            userManager.save(entity);  // Just calls repository
                userRepository.save(entity);  // Just calls DAO
                    userDao.save(entity);  // Finally does something

// JUST DO THIS (initially):
Controller → Service → Repository → Database

// Add layers WHEN you have specific needs for each
```

## Correct Approach: YAGNI (You Aren't Gonna Need It)

```java
// ✅ Start simple
public class OrderService {
    public void processOrder(Order order) {
        // Direct implementation
        validateOrder(order);
        calculateTotal(order);
        saveOrder(order);
        sendConfirmation(order);
    }
}

// ✅ Extract WHEN needed (third occurrence)
// After seeing pattern in OrderService, InvoiceService, RefundService:
public interface DocumentProcessor {
    void validate(Document doc);
    Money calculate(Document doc);
    void save(Document doc);
    void notify(Document doc);
}
```

## When TO Create Abstractions

| Scenario | Reasoning |
|----------|-----------|
| **Rule of Three** | Seen pattern 3+ times |
| **Testing requirement** | Need to mock external dependency |
| **Contractual interface** | Public API stability |
| **Known variation** | Actually have 2+ implementations NOW |
| **Domain concept** | Abstraction exists in domain language |

## When NOT TO Create Abstractions

| Scenario | Better Approach |
|----------|-----------------|
| **"Might need later"** | Wait until you do |
| **"For flexibility"** | Flexibility you don't need is cost |
| **"Best practice"** | Context matters more than rules |
| **"Clean architecture"** | Simple is cleaner than complex |
| **"Enterprise pattern"** | Not every app is enterprise scale |

## Detection Checklist

When reviewing code, flag Premature Abstraction if:

- [ ] **[MAJOR]** Interface with exactly one implementation (not for testing)
- [ ] **[MAJOR]** Factory that creates only one type
- [ ] **[MAJOR]** Strategy/Template with only one concrete strategy
- [ ] **[MAJOR]** Abstract base class with empty/trivial method implementations
- [ ] **[MINOR]** Generic types where specific types would work
- [ ] **[MINOR]** Design pattern applied without the problem it solves

## The Cost of Wrong Abstractions

> "Duplication is far cheaper than the wrong abstraction."
> — Sandi Metz

```
Wrong abstraction:
┌─────────────────────────────────────────┐
│       AbstractPaymentProcessor          │
├─────────────────────────────────────────┤
│ Was designed for Visa, MasterCard       │
│                                         │
│ Now need to add:                        │
│ - Cryptocurrency (no currency code)     │
│ - Subscription (recurring)              │
│ - Marketplace (split payment)           │
│                                         │
│ Abstraction doesn't fit! But everything │
│ depends on it. Massive refactoring      │
│ required.                               │
└─────────────────────────────────────────┘

No abstraction (just code):
// Easier to see patterns emerge
// Easier to create RIGHT abstraction later
// Less code to change if needs shift
```

## Refactoring Away From Premature Abstraction

### 1. Inline the Abstraction
```java
// Before
interface UserFinder { User find(Long id); }
class UserFinderImpl implements UserFinder { ... }

// After
class UserRepository {
    User findById(Long id) { ... }
}
```

### 2. Remove Empty Layers
```java
// Before
controller.save(user);      // calls facade
facade.save(user);          // calls service
service.save(user);         // calls repository
repository.save(user);      // actual work

// After
controller.save(user);      // calls service
service.save(user);         // calls repository
repository.save(user);      // actual work
```

### 3. Specialize Generics
```java
// Before
class Repository<T, ID> { ... }
class UserRepository extends Repository<User, Long> { /* empty */ }

// After
class UserRepository {
    User findById(Long id) { ... }
    void save(User user) { ... }
    // User-specific queries
    List<User> findByEmail(String email) { ... }
}
```

## Related Concepts

| Concept | Description |
|---------|-------------|
| **YAGNI** | You Aren't Gonna Need It |
| **KISS** | Keep It Simple, Stupid |
| **Rule of Three** | Abstract after 3 occurrences |
| **AHA Programming** | Avoid Hasty Abstractions |

## References

- Sandi Metz, "The Wrong Abstraction"
- Martin Fowler, "YAGNI"
- Kent Beck, "Extreme Programming Explained" - Simple Design
- Dan Abramov, "Goodbye, Clean Code"
