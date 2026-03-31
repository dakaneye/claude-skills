# Observer Pattern

> Define a one-to-many dependency between objects so that when one object changes state, all its dependents are notified and updated automatically.

## Intent

Establish a subscription mechanism to notify multiple objects about events that happen to the object they're observing.

## When to Use

- Changes to one object require changing others, and you don't know how many
- An object should notify other objects without making assumptions about them
- Event-driven or reactive programming models
- Loose coupling between event source and handlers

## When NOT to Use

- Simple direct method calls work
- Notification order matters (Observer doesn't guarantee order)
- Synchronous, immediate response required with guaranteed completion
- **CRITICAL**: Memory leak risk in languages without weak references (most of them)

## Memory Leak Warning

**This is the most common bug with Observer pattern.** Observers hold references to subjects (or vice versa), preventing garbage collection.

```java
// DANGER: Memory leak
button.addActionListener(event -> { ... });
// If button outlives the containing object, leak!

// SOLUTION: Remove observers explicitly
void dispose() {
    button.removeActionListener(this.listener);
}
```

## Structure

```
┌─────────────────┐        ┌─────────────────┐
│    Subject      │        │    Observer     │ (interface)
├─────────────────┤        ├─────────────────┤
│ + attach(o)     │◀──────▶│ + update()      │
│ + detach(o)     │        └─────────────────┘
│ + notify()      │               △
└─────────────────┘               │
                           ┌──────┴───────┐
                           │              │
                    ConcreteObserverA  ConcreteObserverB
```

## Language Examples

### Java (Push Model - Data in Notification)

```java
// Observer interface
@FunctionalInterface
public interface PriceObserver {
    void onPriceChange(String symbol, BigDecimal oldPrice, BigDecimal newPrice);
}

// Subject
public class StockTicker {
    private final Map<String, BigDecimal> prices = new ConcurrentHashMap<>();
    private final List<PriceObserver> observers = new CopyOnWriteArrayList<>();

    public void addObserver(PriceObserver observer) {
        observers.add(Objects.requireNonNull(observer));
    }

    public void removeObserver(PriceObserver observer) {
        observers.remove(observer);
    }

    public void updatePrice(String symbol, BigDecimal newPrice) {
        BigDecimal oldPrice = prices.put(symbol, newPrice);
        if (oldPrice == null || !oldPrice.equals(newPrice)) {
            notifyObservers(symbol, oldPrice, newPrice);
        }
    }

    private void notifyObservers(String symbol, BigDecimal oldPrice, BigDecimal newPrice) {
        for (PriceObserver observer : observers) {
            try {
                observer.onPriceChange(symbol, oldPrice, newPrice);
            } catch (Exception e) {
                // Log but don't let one observer break others
                log.error("Observer failed: {}", observer, e);
            }
        }
    }
}

// Usage with explicit cleanup
public class TradingDashboard implements PriceObserver, AutoCloseable {
    private final StockTicker ticker;

    public TradingDashboard(StockTicker ticker) {
        this.ticker = ticker;
        ticker.addObserver(this);  // Register
    }

    @Override
    public void onPriceChange(String symbol, BigDecimal oldPrice, BigDecimal newPrice) {
        updateDisplay(symbol, newPrice);
    }

    @Override
    public void close() {
        ticker.removeObserver(this);  // CRITICAL: Unregister to prevent leak
    }
}

// Usage
try (TradingDashboard dashboard = new TradingDashboard(ticker)) {
    // Dashboard receives updates
}  // Automatically unregisters on close
```

### Java (Modern - Event Bus / Weak References)

```java
// Using weak references to prevent leaks
public class WeakObserverList<T> {
    private final List<WeakReference<T>> observers = new ArrayList<>();

    public void add(T observer) {
        observers.add(new WeakReference<>(observer));
    }

    public void forEach(Consumer<T> action) {
        observers.removeIf(ref -> ref.get() == null);  // Clean up dead refs
        for (WeakReference<T> ref : observers) {
            T observer = ref.get();
            if (observer != null) {
                action.accept(observer);
            }
        }
    }
}

// Or use an event bus library (Guava EventBus, etc.)
```

### Go (Channel-Based - Idiomatic)

```go
// Event type
type PriceUpdate struct {
    Symbol   string
    OldPrice float64
    NewPrice float64
}

// Subject using channels
type StockTicker struct {
    mu        sync.RWMutex
    prices    map[string]float64
    observers []chan<- PriceUpdate
}

func NewStockTicker() *StockTicker {
    return &StockTicker{
        prices:    make(map[string]float64),
        observers: make([]chan<- PriceUpdate, 0),
    }
}

func (t *StockTicker) Subscribe() <-chan PriceUpdate {
    ch := make(chan PriceUpdate, 10)  // Buffered to prevent blocking
    t.mu.Lock()
    t.observers = append(t.observers, ch)
    t.mu.Unlock()
    return ch
}

func (t *StockTicker) Unsubscribe(ch <-chan PriceUpdate) {
    t.mu.Lock()
    defer t.mu.Unlock()
    for i, obs := range t.observers {
        // Can't directly compare, need to track differently in real code
        // This is simplified
        _ = i
        _ = obs
    }
}

func (t *StockTicker) UpdatePrice(symbol string, newPrice float64) {
    t.mu.Lock()
    oldPrice := t.prices[symbol]
    t.prices[symbol] = newPrice
    observers := t.observers  // Copy slice under lock
    t.mu.Unlock()

    if oldPrice != newPrice {
        update := PriceUpdate{symbol, oldPrice, newPrice}
        for _, ch := range observers {
            select {
            case ch <- update:
            default:
                // Observer channel full, skip (or log)
            }
        }
    }
}

// Usage
func main() {
    ticker := NewStockTicker()

    // Observer as goroutine
    updates := ticker.Subscribe()
    go func() {
        for update := range updates {
            fmt.Printf("%s: %.2f -> %.2f\n",
                update.Symbol, update.OldPrice, update.NewPrice)
        }
    }()

    ticker.UpdatePrice("GOOG", 2800.00)
}
```

### Python

```python
from abc import ABC, abstractmethod
from typing import List, Any
from weakref import WeakSet
import contextlib

# Observer interface
class Observer(ABC):
    @abstractmethod
    def update(self, subject: "Subject", *args, **kwargs) -> None:
        pass

# Subject with weak references (prevents memory leaks)
class Subject:
    def __init__(self):
        self._observers: WeakSet[Observer] = WeakSet()

    def attach(self, observer: Observer) -> None:
        self._observers.add(observer)

    def detach(self, observer: Observer) -> None:
        self._observers.discard(observer)

    def notify(self, *args, **kwargs) -> None:
        for observer in self._observers:
            with contextlib.suppress(Exception):
                observer.update(self, *args, **kwargs)

# Concrete subject
class StockTicker(Subject):
    def __init__(self):
        super().__init__()
        self._prices: dict[str, float] = {}

    def update_price(self, symbol: str, price: float) -> None:
        old_price = self._prices.get(symbol)
        self._prices[symbol] = price
        if old_price != price:
            self.notify(symbol=symbol, old_price=old_price, new_price=price)

# Concrete observer
class Dashboard(Observer):
    def update(self, subject: Subject, **kwargs) -> None:
        print(f"Price update: {kwargs['symbol']} = {kwargs['new_price']}")

# Usage
ticker = StockTicker()
dashboard = Dashboard()
ticker.attach(dashboard)

ticker.update_price("AAPL", 150.00)  # Dashboard notified
# No explicit detach needed due to WeakSet
```

## Review Checklist

### Memory Safety (CRITICAL)
- [ ] **[BLOCKER]** Observers are unregistered when no longer needed
- [ ] **[BLOCKER]** Use weak references OR explicit lifecycle management
- [ ] **[MAJOR]** Subject doesn't hold strong reference to short-lived observers
- [ ] **[MAJOR]** In UI: observers removed when component destroyed

### Correct Implementation
- [ ] **[BLOCKER]** Notification doesn't throw if one observer fails
- [ ] **[MAJOR]** Thread-safe if subject modified from multiple threads
- [ ] **[MAJOR]** No infinite loops (observer modifying subject in update)
- [ ] **[MINOR]** Notification order documented if it matters

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Lambda observers without cleanup mechanism
- [ ] **[BLOCKER]** Observer holds strong reference to long-lived subject
- [ ] **[MAJOR]** Synchronous notification blocks on slow observer
- [ ] **[MAJOR]** Observer throws exception (should be caught)

## Common Mistakes

### 1. Memory Leak (Most Common)
```java
// BAD: Anonymous lambda leaks
button.addListener(e -> updateDisplay());  // Can't remove!

// GOOD: Named reference for removal
private final EventListener listener = e -> updateDisplay();

void init() {
    button.addListener(listener);
}

void cleanup() {
    button.removeListener(listener);
}
```

### 2. Exception Breaks Notification Chain
```java
// BAD: One observer exception stops all notifications
void notify() {
    for (Observer o : observers) {
        o.update();  // If this throws, others don't get notified
    }
}

// GOOD: Isolate failures
void notify() {
    for (Observer o : observers) {
        try {
            o.update();
        } catch (Exception e) {
            log.error("Observer failed", e);
        }
    }
}
```

### 3. Blocking Notification
```java
// BAD: Slow observer blocks subject
void update() {
    Thread.sleep(5000);  // Blocks notification to other observers
}

// GOOD: Async processing
void update() {
    executor.submit(() -> slowProcessing());
}
```

### 4. Notification During State Change
```java
// BAD: Notify while still changing state
void setState(State s) {
    this.state = s;
    notify();  // Observers see partial state
    this.timestamp = now();
}

// GOOD: Notify after state is consistent
void setState(State s) {
    this.state = s;
    this.timestamp = now();
    notify();  // State is complete
}
```

## Language-Specific Notes

### Java
- Use `CopyOnWriteArrayList` for thread-safe observer list
- Consider `java.beans.PropertyChangeSupport` for simple cases
- Reactive Streams (`Flow.Publisher/Subscriber`) for complex scenarios

### Go
- Channels are idiomatic alternative to callback-based observers
- `context.Context` for cancellation
- Be careful with goroutine leaks (unsubscribed channels)

### Python
- `WeakSet` prevents memory leaks automatically
- `asyncio` for async notifications
- Consider signals/slots pattern (Qt, blinker library)

### JavaScript/TypeScript
- `EventEmitter` built into Node.js
- Remove listeners in component cleanup (`removeEventListener`)
- Consider RxJS for complex event streams

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Mediator** | Centralizes communication; Observer is direct subject-observer |
| **Publish-Subscribe** | Similar but usually has message broker intermediary |
| **Event Sourcing** | Stores events; Observer distributes them in real-time |

## Modern Alternatives

### Reactive Streams (Java 9+)
```java
// Flow API for backpressure-aware observer
Flow.Publisher<Update> publisher = ...;
publisher.subscribe(new Flow.Subscriber<>() {
    public void onSubscribe(Flow.Subscription s) { s.request(10); }
    public void onNext(Update u) { process(u); }
    public void onError(Throwable t) { log.error(t); }
    public void onComplete() { }
});
```

### Event Bus
```java
// Guava EventBus
EventBus bus = new EventBus();
bus.register(observer);
bus.post(new PriceUpdateEvent(...));
```

## When to Refactor Away

Consider removing Observer when:
- Only one observer exists (just call it directly)
- Notification order must be guaranteed
- Memory leaks are persistent problem
- Reactive streams fit better (backpressure needed)

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [RxJava](https://github.com/ReactiveX/RxJava) | Reactive streams with backpressure |
| **Java** | [Project Reactor](https://projectreactor.io/) | Reactive Streams for Spring ecosystem |
| **Java** | [Guava EventBus](https://github.com/google/guava/wiki/EventBusExplained) | Publish-subscribe event bus |
| **Java** | [java.util.concurrent.Flow](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/concurrent/Flow.html) | Built-in Reactive Streams (Java 9+) |
| **Go** | [Channels](https://go.dev/tour/concurrency/2) | Built-in, idiomatic observer mechanism |
| **Go** | [eapache/channels](https://github.com/eapache/channels) | Extended channel utilities |
| **Python** | [blinker](https://blinker.readthedocs.io/) | Fast signal/slot library |
| **Python** | [PyPubSub](https://pypubsub.readthedocs.io/) | Publish-subscribe messaging |
| **Python** | [RxPY](https://github.com/ReactiveX/RxPY) | Reactive Extensions for Python |
| **JavaScript** | [RxJS](https://rxjs.dev/) | Reactive Extensions for JS |
| **JavaScript** | [EventEmitter](https://nodejs.org/api/events.html) | Built-in Node.js event system |
| **JavaScript** | [mitt](https://github.com/developit/mitt) | Tiny functional event emitter |

## References

- GoF p.293
- Refactoring Guru: https://refactoring.guru/design-patterns/observer
- Java WeakReference: https://docs.oracle.com/javase/8/docs/api/java/lang/ref/WeakReference.html
