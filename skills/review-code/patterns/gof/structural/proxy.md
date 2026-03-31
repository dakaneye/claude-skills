# Proxy Pattern

> Provide a surrogate or placeholder for another object to control access to it.

## Intent

Control access to an object by providing a substitute that has the same interface. The proxy can add functionality like lazy initialization, access control, logging, or caching.

## Types of Proxy

| Type | Purpose | Example |
|------|---------|---------|
| **Virtual Proxy** | Lazy initialization | Load image on first access |
| **Protection Proxy** | Access control | Check permissions |
| **Remote Proxy** | Network access | RPC/RMI stubs |
| **Logging Proxy** | Logging/metrics | Request logging |
| **Caching Proxy** | Cache results | Memoization |
| **Smart Reference** | Reference counting | Cleanup when no refs |

## When to Use

- Lazy initialization of expensive objects
- Access control (permissions, authentication)
- Local interface to remote service
- Logging, caching, or metrics without changing real object
- Reference counting for cleanup

## When NOT to Use

- No additional functionality needed (just use the real object)
- Adding behavior that changes semantics (use Decorator)
- Converting interfaces (use Adapter)

## Structure

```
┌─────────────┐       ┌─────────────┐
│   Client    │──────▶│  Subject    │ (interface)
└─────────────┘       └──────┬──────┘
                             │
                    ┌────────┴────────┐
                    │                 │
             ┌──────┴──────┐   ┌──────┴──────┐
             │    Proxy    │──▶│ RealSubject │
             └─────────────┘   └─────────────┘
```

## Language Examples

### Java (Virtual Proxy - Lazy Loading)

```java
// Subject interface
public interface Image {
    void display();
    int getWidth();
    int getHeight();
}

// Real subject - expensive to create
public class HighResolutionImage implements Image {
    private final String filename;
    private byte[] imageData;

    public HighResolutionImage(String filename) {
        this.filename = filename;
        loadFromDisk();  // Expensive operation
    }

    private void loadFromDisk() {
        System.out.println("Loading image from disk: " + filename);
        // Simulate expensive loading
        this.imageData = new byte[10_000_000];
    }

    @Override
    public void display() {
        System.out.println("Displaying: " + filename);
    }

    @Override
    public int getWidth() { return 1920; }

    @Override
    public int getHeight() { return 1080; }
}

// Virtual proxy - delays loading until needed
public class ImageProxy implements Image {
    private final String filename;
    private HighResolutionImage realImage;

    public ImageProxy(String filename) {
        this.filename = filename;
        // Does NOT load image yet
    }

    private HighResolutionImage getRealImage() {
        if (realImage == null) {
            realImage = new HighResolutionImage(filename);
        }
        return realImage;
    }

    @Override
    public void display() {
        getRealImage().display();  // Loads on first display
    }

    @Override
    public int getWidth() {
        // Could return cached metadata without loading full image
        return getRealImage().getWidth();
    }

    @Override
    public int getHeight() {
        return getRealImage().getHeight();
    }
}

// Usage
List<Image> gallery = List.of(
    new ImageProxy("photo1.jpg"),
    new ImageProxy("photo2.jpg"),
    new ImageProxy("photo3.jpg")
);
// No images loaded yet!

gallery.get(0).display();  // Loads photo1.jpg on demand
```

### Java (Protection Proxy - Access Control)

```java
public interface Document {
    String read();
    void write(String content);
    void delete();
}

public class SecureDocumentProxy implements Document {
    private final Document document;
    private final User currentUser;
    private final AccessControl accessControl;

    public SecureDocumentProxy(Document document, User user, AccessControl ac) {
        this.document = document;
        this.currentUser = user;
        this.accessControl = ac;
    }

    @Override
    public String read() {
        if (!accessControl.canRead(currentUser, document)) {
            throw new AccessDeniedException("Read access denied");
        }
        return document.read();
    }

    @Override
    public void write(String content) {
        if (!accessControl.canWrite(currentUser, document)) {
            throw new AccessDeniedException("Write access denied");
        }
        document.write(content);
    }

    @Override
    public void delete() {
        if (!accessControl.canDelete(currentUser, document)) {
            throw new AccessDeniedException("Delete access denied");
        }
        document.delete();
    }
}
```

### Go (Caching Proxy)

```go
// Subject interface
type DataFetcher interface {
    Fetch(key string) ([]byte, error)
}

// Real subject - slow database call
type DatabaseFetcher struct {
    db *sql.DB
}

func (f *DatabaseFetcher) Fetch(key string) ([]byte, error) {
    // Slow database query
    row := f.db.QueryRow("SELECT data FROM items WHERE key = ?", key)
    var data []byte
    err := row.Scan(&data)
    return data, err
}

// Caching proxy
type CachingProxy struct {
    fetcher DataFetcher
    cache   map[string]cacheEntry
    mu      sync.RWMutex
    ttl     time.Duration
}

type cacheEntry struct {
    data      []byte
    expiresAt time.Time
}

func NewCachingProxy(fetcher DataFetcher, ttl time.Duration) *CachingProxy {
    return &CachingProxy{
        fetcher: fetcher,
        cache:   make(map[string]cacheEntry),
        ttl:     ttl,
    }
}

func (p *CachingProxy) Fetch(key string) ([]byte, error) {
    // Check cache first
    p.mu.RLock()
    if entry, ok := p.cache[key]; ok && time.Now().Before(entry.expiresAt) {
        p.mu.RUnlock()
        return entry.data, nil
    }
    p.mu.RUnlock()

    // Cache miss - fetch from real source
    data, err := p.fetcher.Fetch(key)
    if err != nil {
        return nil, err
    }

    // Update cache
    p.mu.Lock()
    p.cache[key] = cacheEntry{
        data:      data,
        expiresAt: time.Now().Add(p.ttl),
    }
    p.mu.Unlock()

    return data, nil
}

// Usage
dbFetcher := &DatabaseFetcher{db: db}
cachedFetcher := NewCachingProxy(dbFetcher, 5*time.Minute)

data, _ := cachedFetcher.Fetch("user:123")  // DB call
data, _ = cachedFetcher.Fetch("user:123")   // Cache hit
```

### Python (Logging Proxy)

```python
from abc import ABC, abstractmethod
from functools import wraps
import time
import logging

# Subject interface
class PaymentProcessor(ABC):
    @abstractmethod
    def process(self, amount: float, card: str) -> bool:
        pass

# Real subject
class StripeProcessor(PaymentProcessor):
    def process(self, amount: float, card: str) -> bool:
        # Process payment with Stripe
        return True

# Logging proxy
class LoggingPaymentProxy(PaymentProcessor):
    def __init__(self, processor: PaymentProcessor):
        self._processor = processor
        self._logger = logging.getLogger(__name__)

    def process(self, amount: float, card: str) -> bool:
        masked_card = f"****{card[-4:]}"
        self._logger.info(f"Processing payment: ${amount:.2f} with card {masked_card}")

        start = time.time()
        try:
            result = self._processor.process(amount, card)
            duration = time.time() - start
            self._logger.info(f"Payment {'succeeded' if result else 'failed'} in {duration:.3f}s")
            return result
        except Exception as e:
            self._logger.error(f"Payment error: {e}")
            raise

# Usage
processor = LoggingPaymentProxy(StripeProcessor())
processor.process(99.99, "4111111111111111")
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Need to control access to the real object
- [ ] **[MAJOR]** Same interface as real object (polymorphic)
- [ ] **[MINOR]** Lazy loading, caching, or logging needed

### Correct Implementation
- [ ] **[BLOCKER]** Proxy implements same interface as subject
- [ ] **[MAJOR]** Proxy is transparent to clients
- [ ] **[MAJOR]** Proxy handles errors from real subject appropriately
- [ ] **[MINOR]** Thread safety for caching/lazy proxies

### Anti-Patterns to Flag
- [ ] **[MAJOR]** Proxy changes behavior significantly (use Decorator)
- [ ] **[MAJOR]** Proxy changes interface (use Adapter)
- [ ] **[MINOR]** Proxy with no added functionality

## Common Mistakes

### 1. Leaky Abstraction
```java
// BAD: Proxy exposes implementation details
class ImageProxy implements Image {
    public boolean isLoaded() {  // Not in Image interface!
        return realImage != null;
    }
}

// GOOD: Proxy is transparent
class ImageProxy implements Image {
    // Only implements Image interface
    // Client doesn't know it's a proxy
}
```

### 2. Thread-Unsafe Lazy Loading
```java
// BAD: Race condition
class ImageProxy implements Image {
    private Image realImage;

    public void display() {
        if (realImage == null) {       // Thread A checks
            realImage = loadImage();    // Thread B also loads!
        }
        realImage.display();
    }
}

// GOOD: Thread-safe lazy loading
class ImageProxy implements Image {
    private volatile Image realImage;

    public void display() {
        if (realImage == null) {
            synchronized (this) {
                if (realImage == null) {
                    realImage = loadImage();
                }
            }
        }
        realImage.display();
    }
}
```

## Proxy vs. Decorator vs. Adapter

| Pattern | Interface | Intent |
|---------|-----------|--------|
| **Proxy** | Same | Control access |
| **Decorator** | Same | Add behavior |
| **Adapter** | Different | Convert interface |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Decorator** | Similar structure; Decorator adds behavior, Proxy controls access |
| **Adapter** | Different intent; Adapter converts interface |
| **Facade** | Provides different interface to subsystem |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [java.lang.reflect.Proxy](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/reflect/Proxy.html) | Dynamic proxy for interfaces |
| **Java** | [CGLIB](https://github.com/cglib/cglib) | Bytecode generation for class proxies |
| **Java** | [Spring AOP](https://docs.spring.io/spring-framework/docs/current/reference/html/core.html#aop) | Declarative proxies via `@Transactional`, `@Cacheable` |
| **Java** | [Hibernate](https://hibernate.org/) | Lazy-loading entity proxies |
| **Go** | Standard Library | Interfaces enable manual proxy implementation |
| **Go** | [gRPC](https://grpc.io/docs/languages/go/) | RPC stubs are remote proxies |
| **Python** | [wrapt](https://wrapt.readthedocs.io/) | Transparent object proxies and wrappers |
| **Python** | [lazy-object-proxy](https://pypi.org/project/lazy-object-proxy/) | Virtual proxy for lazy initialization |
| **JavaScript** | [Proxy](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy) | Built-in ES6 Proxy object |
| **.NET** | [Castle.DynamicProxy](http://www.castleproject.org/projects/dynamicproxy/) | Runtime proxy generation |

**Note**: Many ORM and AOP frameworks use proxies internally for lazy loading and cross-cutting concerns.

## References

- GoF p.207
- Refactoring Guru: https://refactoring.guru/design-patterns/proxy
