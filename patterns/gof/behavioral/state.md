# State Pattern

> Allow an object to alter its behavior when its internal state changes. The object will appear to change its class.

## Intent

Encapsulate state-specific behavior in separate state objects. Let an object delegate behavior to its current state object, making state transitions explicit.

## When to Use

- Object behavior depends on its state and must change at runtime
- Operations have large conditional statements based on state
- State transitions need to be explicit and manageable
- States have distinct, well-defined behaviors

## When NOT to Use

- Only 2-3 states with simple transitions
- State logic is straightforward (if/else is clearer)
- States don't have significantly different behaviors

## Structure

```
┌─────────────┐       ┌─────────────┐
│   Context   │──────▶│    State    │ (interface)
├─────────────┤       ├─────────────┤
│ - state     │       │ + handle()  │
│ + request() │       └──────┬──────┘
└─────────────┘              │
                    ┌────────┼────────┐
                    │        │        │
             ┌──────┴──┐ ┌───┴───┐ ┌──┴──────┐
             │ StateA  │ │StateB │ │ StateC  │
             └─────────┘ └───────┘ └─────────┘
```

## Language Examples

### Java

```java
// State interface
public interface OrderState {
    void next(Order order);
    void previous(Order order);
    void printStatus();
    boolean canCancel();
}

// Concrete states
public class OrderedState implements OrderState {
    @Override
    public void next(Order order) {
        order.setState(new PaidState());
    }

    @Override
    public void previous(Order order) {
        System.out.println("Already at initial state");
    }

    @Override
    public void printStatus() {
        System.out.println("Order placed, awaiting payment");
    }

    @Override
    public boolean canCancel() {
        return true;
    }
}

public class PaidState implements OrderState {
    @Override
    public void next(Order order) {
        order.setState(new ShippedState());
    }

    @Override
    public void previous(Order order) {
        order.setState(new OrderedState());
    }

    @Override
    public void printStatus() {
        System.out.println("Payment received, preparing for shipment");
    }

    @Override
    public boolean canCancel() {
        return true;  // Can still cancel before shipping
    }
}

public class ShippedState implements OrderState {
    @Override
    public void next(Order order) {
        order.setState(new DeliveredState());
    }

    @Override
    public void previous(Order order) {
        System.out.println("Cannot unship order");
    }

    @Override
    public void printStatus() {
        System.out.println("Order shipped, in transit");
    }

    @Override
    public boolean canCancel() {
        return false;  // Too late to cancel
    }
}

public class DeliveredState implements OrderState {
    @Override
    public void next(Order order) {
        System.out.println("Order already delivered");
    }

    @Override
    public void previous(Order order) {
        System.out.println("Cannot undeliver");
    }

    @Override
    public void printStatus() {
        System.out.println("Order delivered");
    }

    @Override
    public boolean canCancel() {
        return false;
    }
}

// Context
public class Order {
    private OrderState state;
    private final String orderId;

    public Order(String orderId) {
        this.orderId = orderId;
        this.state = new OrderedState();
    }

    void setState(OrderState state) {
        this.state = state;
    }

    public void nextState() {
        state.next(this);
    }

    public void previousState() {
        state.previous(this);
    }

    public void printStatus() {
        state.printStatus();
    }

    public boolean cancel() {
        if (state.canCancel()) {
            System.out.println("Order cancelled");
            return true;
        }
        System.out.println("Cannot cancel order in current state");
        return false;
    }
}

// Usage
Order order = new Order("ORD-123");
order.printStatus();     // Order placed, awaiting payment
order.nextState();
order.printStatus();     // Payment received, preparing for shipment
order.cancel();          // Order cancelled (still allowed)

order.nextState();       // Shipped
order.cancel();          // Cannot cancel order in current state
```

### Go

```go
// State interface
type State interface {
    InsertMoney(m *VendingMachine, amount int)
    SelectProduct(m *VendingMachine, product string)
    Dispense(m *VendingMachine)
}

// Context
type VendingMachine struct {
    state   State
    balance int
    product string
}

func NewVendingMachine() *VendingMachine {
    return &VendingMachine{
        state: &IdleState{},
    }
}

func (m *VendingMachine) SetState(state State) {
    m.state = state
}

func (m *VendingMachine) InsertMoney(amount int) {
    m.state.InsertMoney(m, amount)
}

func (m *VendingMachine) SelectProduct(product string) {
    m.state.SelectProduct(m, product)
}

func (m *VendingMachine) Dispense() {
    m.state.Dispense(m)
}

// Concrete states
type IdleState struct{}

func (s *IdleState) InsertMoney(m *VendingMachine, amount int) {
    m.balance = amount
    fmt.Printf("Received $%d\n", amount)
    m.SetState(&HasMoneyState{})
}

func (s *IdleState) SelectProduct(m *VendingMachine, product string) {
    fmt.Println("Please insert money first")
}

func (s *IdleState) Dispense(m *VendingMachine) {
    fmt.Println("Please insert money and select product")
}

type HasMoneyState struct{}

func (s *HasMoneyState) InsertMoney(m *VendingMachine, amount int) {
    m.balance += amount
    fmt.Printf("Balance: $%d\n", m.balance)
}

func (s *HasMoneyState) SelectProduct(m *VendingMachine, product string) {
    m.product = product
    fmt.Printf("Selected: %s\n", product)
    m.SetState(&DispensingState{})
}

func (s *HasMoneyState) Dispense(m *VendingMachine) {
    fmt.Println("Please select a product")
}

type DispensingState struct{}

func (s *DispensingState) InsertMoney(m *VendingMachine, amount int) {
    fmt.Println("Please wait, dispensing in progress")
}

func (s *DispensingState) SelectProduct(m *VendingMachine, product string) {
    fmt.Println("Please wait, dispensing in progress")
}

func (s *DispensingState) Dispense(m *VendingMachine) {
    fmt.Printf("Dispensing %s\n", m.product)
    m.balance = 0
    m.product = ""
    m.SetState(&IdleState{})
}

// Usage
vm := NewVendingMachine()
vm.SelectProduct("Soda")     // Please insert money first
vm.InsertMoney(2)            // Received $2
vm.SelectProduct("Soda")     // Selected: Soda
vm.Dispense()                // Dispensing Soda
```

### Python

```python
from abc import ABC, abstractmethod

# State interface
class DocumentState(ABC):
    @abstractmethod
    def edit(self, doc: "Document") -> None:
        pass

    @abstractmethod
    def review(self, doc: "Document") -> None:
        pass

    @abstractmethod
    def publish(self, doc: "Document") -> None:
        pass

    @abstractmethod
    def reject(self, doc: "Document") -> None:
        pass

# Concrete states
class DraftState(DocumentState):
    def edit(self, doc: "Document") -> None:
        print("Editing draft...")

    def review(self, doc: "Document") -> None:
        print("Submitting for review")
        doc.set_state(ModerationState())

    def publish(self, doc: "Document") -> None:
        print("Cannot publish draft directly")

    def reject(self, doc: "Document") -> None:
        print("Draft cannot be rejected")

class ModerationState(DocumentState):
    def edit(self, doc: "Document") -> None:
        print("Cannot edit during review. Returning to draft.")
        doc.set_state(DraftState())

    def review(self, doc: "Document") -> None:
        print("Already under review")

    def publish(self, doc: "Document") -> None:
        print("Approved! Publishing...")
        doc.set_state(PublishedState())

    def reject(self, doc: "Document") -> None:
        print("Rejected. Returning to draft.")
        doc.set_state(DraftState())

class PublishedState(DocumentState):
    def edit(self, doc: "Document") -> None:
        print("Creating new draft from published version")
        doc.set_state(DraftState())

    def review(self, doc: "Document") -> None:
        print("Already published")

    def publish(self, doc: "Document") -> None:
        print("Already published")

    def reject(self, doc: "Document") -> None:
        print("Unpublishing...")
        doc.set_state(DraftState())

# Context
class Document:
    def __init__(self, title: str):
        self.title = title
        self._state = DraftState()

    def set_state(self, state: DocumentState) -> None:
        self._state = state

    def edit(self) -> None:
        self._state.edit(self)

    def review(self) -> None:
        self._state.review(self)

    def publish(self) -> None:
        self._state.publish(self)

    def reject(self) -> None:
        self._state.reject(self)

# Usage
doc = Document("My Article")
doc.edit()      # Editing draft...
doc.publish()   # Cannot publish draft directly
doc.review()    # Submitting for review
doc.publish()   # Approved! Publishing...
doc.edit()      # Creating new draft from published version
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Multiple distinct states with different behaviors
- [ ] **[MAJOR]** State transitions are complex or numerous
- [ ] **[MINOR]** Behavior changes significantly based on state

### Correct Implementation
- [ ] **[BLOCKER]** All states implement complete interface
- [ ] **[MAJOR]** State transitions are explicit and documented
- [ ] **[MAJOR]** Context delegates to state (doesn't check state itself)
- [ ] **[MINOR]** States are stateless if possible (can be singletons)

### Anti-Patterns to Flag
- [ ] **[MAJOR]** Context still has state conditionals
- [ ] **[MAJOR]** States with circular dependencies on context internals
- [ ] **[MINOR]** Using State for 2-3 simple states (if/else is clearer)

## Common Mistakes

### 1. Context Still Has Conditionals
```java
// BAD: Context checks state
class Order {
    private State state;

    public void ship() {
        if (state instanceof PaidState) {  // Wrong!
            // State pattern avoids this
        }
    }
}

// GOOD: Delegate to state
class Order {
    private State state;

    public void ship() {
        state.ship(this);  // State decides what to do
    }
}
```

### 2. Missing State Transitions
```java
// BAD: Not all transitions handled
class DraftState implements DocumentState {
    public void publish(Document doc) {
        doc.setState(new PublishedState());  // Skips review!
    }
}

// GOOD: Enforce proper transitions
class DraftState implements DocumentState {
    public void publish(Document doc) {
        throw new IllegalStateException("Must be reviewed before publishing");
    }

    public void review(Document doc) {
        doc.setState(new ReviewState());
    }
}
```

## State vs. Strategy

| State | Strategy |
|-------|----------|
| Transitions between states | Selected at creation/injection |
| States know about each other | Strategies are independent |
| Object appears to change class | Algorithm varies |
| Context has implicit state machine | Context is stateless |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Strategy** | Similar structure, different intent |
| **Flyweight** | States can be shared as flyweights |
| **Singleton** | Stateless states can be singletons |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Statemachine](https://spring.io/projects/spring-statemachine) | Full state machine framework with persistence |
| **Java** | [Stateless4j](https://github.com/stateless4j/stateless4j) | Lightweight fluent state machine |
| **Java** | [EasyFlow](https://github.com/Beh01der/EasyFlow) | Simple state machine with async support |
| **Go** | [looplab/fsm](https://github.com/looplab/fsm) | Finite state machine with callbacks |
| **Go** | [qmuntal/stateless](https://github.com/qmuntal/stateless) | Port of Stateless4j for Go |
| **Python** | [transitions](https://github.com/pytransitions/transitions) | Lightweight state machine with callbacks |
| **Python** | [python-statemachine](https://github.com/fgmacedo/python-statemachine) | Declarative state machines |
| **JavaScript** | [XState](https://xstate.js.org/) | Full statecharts implementation, popular for UI |
| **JavaScript** | [robot3](https://thisrobot.life/) | Lightweight functional state machines |
| **.NET** | [Stateless](https://github.com/dotnet-state-machine/stateless) | Fluent state machine library |

**Note**: For simple state (3-4 states), hand-rolled State pattern is fine. For complex state machines with guards, history, and hierarchical states, use a library.

## References

- GoF p.305
- Refactoring Guru: https://refactoring.guru/design-patterns/state
- "Replace Type Code with State/Strategy" - Fowler's Refactoring
