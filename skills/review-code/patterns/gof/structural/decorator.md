# Decorator Pattern

> Attach additional responsibilities to an object dynamically. Decorators provide a flexible alternative to subclassing for extending functionality.

## Intent

Add behavior to individual objects without affecting other objects of the same class. Compose behaviors by wrapping objects with decorator objects.

## When to Use

- Add responsibilities to objects dynamically and transparently
- Responsibilities can be withdrawn
- Extension by subclassing is impractical (explosion of subclasses)
- Behaviors can be combined in various ways

## When NOT to Use

- Behavior is fixed at compile time (just use inheritance)
- Only one combination of behaviors needed
- Deep decorator chains become hard to debug
- Order of decoration matters and is error-prone

## Structure

```
┌─────────────┐       ┌─────────────────┐
│   Client    │──────▶│    Component    │ (interface)
└─────────────┘       └────────┬────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────┴───────┐ ┌──────┴──────┐  ┌──────┴──────┐
     │ConcreteComponent│ │  Decorator  │──┤  Component  │
     └────────────────┘ └──────┬──────┘  └─────────────┘
                               │ (wraps)
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────┴───────┐ ┌──────┴───────┐ ┌──────┴──────┐
     │DecoratorA      │ │DecoratorB    │ │DecoratorC   │
     └────────────────┘ └──────────────┘ └─────────────┘
```

## Language Examples

### Java

```java
// Component interface
public interface DataSource {
    void writeData(String data);
    String readData();
}

// Concrete component
public class FileDataSource implements DataSource {
    private final String filename;

    public FileDataSource(String filename) {
        this.filename = filename;
    }

    @Override
    public void writeData(String data) {
        // Write to file
    }

    @Override
    public String readData() {
        // Read from file
        return "";
    }
}

// Base decorator
public abstract class DataSourceDecorator implements DataSource {
    protected final DataSource wrappee;

    public DataSourceDecorator(DataSource source) {
        this.wrappee = source;
    }

    @Override
    public void writeData(String data) {
        wrappee.writeData(data);
    }

    @Override
    public String readData() {
        return wrappee.readData();
    }
}

// Concrete decorators
public class EncryptionDecorator extends DataSourceDecorator {
    public EncryptionDecorator(DataSource source) {
        super(source);
    }

    @Override
    public void writeData(String data) {
        String encrypted = encrypt(data);
        super.writeData(encrypted);
    }

    @Override
    public String readData() {
        String data = super.readData();
        return decrypt(data);
    }

    private String encrypt(String data) { /* ... */ }
    private String decrypt(String data) { /* ... */ }
}

public class CompressionDecorator extends DataSourceDecorator {
    public CompressionDecorator(DataSource source) {
        super(source);
    }

    @Override
    public void writeData(String data) {
        String compressed = compress(data);
        super.writeData(compressed);
    }

    @Override
    public String readData() {
        String data = super.readData();
        return decompress(data);
    }

    private String compress(String data) { /* ... */ }
    private String decompress(String data) { /* ... */ }
}

// Usage - compose behaviors
DataSource source = new FileDataSource("data.txt");

// Add encryption
source = new EncryptionDecorator(source);

// Add compression (compresses encrypted data)
source = new CompressionDecorator(source);

source.writeData("sensitive data");
// Flow: data -> compress -> encrypt -> file
```

### Java (Real-World: I/O Streams)

```java
// Java I/O is the classic Decorator example
InputStream input = new FileInputStream("file.txt");

// Add buffering
input = new BufferedInputStream(input);

// Add decompression
input = new GZIPInputStream(input);

// Or fluently
InputStream decorated = new GZIPInputStream(
    new BufferedInputStream(
        new FileInputStream("file.txt.gz")
    )
);
```

### Go

```go
// Component interface
type Handler interface {
    Handle(request *Request) (*Response, error)
}

// Concrete component
type APIHandler struct{}

func (h *APIHandler) Handle(request *Request) (*Response, error) {
    // Process API request
    return &Response{Status: 200}, nil
}

// Decorator: Logging
type LoggingHandler struct {
    wrapped Handler
    logger  *slog.Logger
}

func WithLogging(h Handler, logger *slog.Logger) Handler {
    return &LoggingHandler{wrapped: h, logger: logger}
}

func (h *LoggingHandler) Handle(request *Request) (*Response, error) {
    h.logger.Info("request started", "path", request.Path)
    start := time.Now()

    response, err := h.wrapped.Handle(request)

    h.logger.Info("request completed",
        "path", request.Path,
        "duration", time.Since(start),
        "status", response.Status,
    )
    return response, err
}

// Decorator: Authentication
type AuthHandler struct {
    wrapped Handler
    auth    AuthService
}

func WithAuth(h Handler, auth AuthService) Handler {
    return &AuthHandler{wrapped: h, auth: auth}
}

func (h *AuthHandler) Handle(request *Request) (*Response, error) {
    if !h.auth.Validate(request.Token) {
        return &Response{Status: 401}, nil
    }
    return h.wrapped.Handle(request)
}

// Decorator: Rate Limiting
type RateLimitHandler struct {
    wrapped Handler
    limiter *rate.Limiter
}

func WithRateLimit(h Handler, rps int) Handler {
    return &RateLimitHandler{
        wrapped: h,
        limiter: rate.NewLimiter(rate.Limit(rps), rps),
    }
}

func (h *RateLimitHandler) Handle(request *Request) (*Response, error) {
    if !h.limiter.Allow() {
        return &Response{Status: 429}, nil
    }
    return h.wrapped.Handle(request)
}

// Usage - compose decorators
handler := &APIHandler{}
handler = WithLogging(handler, logger)
handler = WithAuth(handler, authService)
handler = WithRateLimit(handler, 100)

// Request flow: RateLimit -> Auth -> Logging -> API
```

### Python

```python
from abc import ABC, abstractmethod
from functools import wraps
from typing import Callable

# Component interface
class Notifier(ABC):
    @abstractmethod
    def send(self, message: str) -> None:
        pass

# Concrete component
class EmailNotifier(Notifier):
    def __init__(self, email: str):
        self._email = email

    def send(self, message: str) -> None:
        print(f"Sending email to {self._email}: {message}")

# Base decorator
class NotifierDecorator(Notifier):
    def __init__(self, wrapped: Notifier):
        self._wrapped = wrapped

    def send(self, message: str) -> None:
        self._wrapped.send(message)

# Concrete decorators
class SMSDecorator(NotifierDecorator):
    def __init__(self, wrapped: Notifier, phone: str):
        super().__init__(wrapped)
        self._phone = phone

    def send(self, message: str) -> None:
        super().send(message)
        print(f"Sending SMS to {self._phone}: {message}")

class SlackDecorator(NotifierDecorator):
    def __init__(self, wrapped: Notifier, channel: str):
        super().__init__(wrapped)
        self._channel = channel

    def send(self, message: str) -> None:
        super().send(message)
        print(f"Posting to Slack #{self._channel}: {message}")

# Usage
notifier = EmailNotifier("user@example.com")
notifier = SMSDecorator(notifier, "+1234567890")
notifier = SlackDecorator(notifier, "alerts")

notifier.send("Server is down!")
# Sends: Email + SMS + Slack


# Python idiom: Function decorators
def log_calls(func: Callable) -> Callable:
    @wraps(func)
    def wrapper(*args, **kwargs):
        print(f"Calling {func.__name__}")
        result = func(*args, **kwargs)
        print(f"Finished {func.__name__}")
        return result
    return wrapper

def retry(times: int = 3):
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(times):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == times - 1:
                        raise
            return None
        return wrapper
    return decorator

@log_calls
@retry(times=3)
def fetch_data(url: str) -> dict:
    # Fetch data from URL
    pass
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Behaviors need to be added/removed dynamically
- [ ] **[MAJOR]** Multiple behavior combinations are needed
- [ ] **[MINOR]** Subclassing would lead to class explosion

### Correct Implementation
- [ ] **[BLOCKER]** Decorator implements same interface as component
- [ ] **[BLOCKER]** Decorator delegates to wrapped object
- [ ] **[MAJOR]** Decorators are independent (can be combined freely)
- [ ] **[MINOR]** Base decorator class reduces duplication

### Anti-Patterns to Flag
- [ ] **[MAJOR]** Decorator changes interface (that's Adapter)
- [ ] **[MAJOR]** Deep decorator chains (>3-4 levels)
- [ ] **[MAJOR]** Order-dependent decorators without documentation
- [ ] **[MINOR]** Using decorator for single fixed combination

## Common Mistakes

### 1. Breaking the Interface Contract
```java
// BAD: Decorator adds methods not in interface
public class ExtendedDecorator extends DataSourceDecorator {
    public void newMethod() {  // Not in DataSource interface!
        // This breaks polymorphism
    }
}

// GOOD: Decorator only implements interface methods
public class GoodDecorator extends DataSourceDecorator {
    @Override
    public void writeData(String data) {
        // Add behavior, but same interface
        super.writeData(preprocess(data));
    }
}
```

### 2. Forgetting to Delegate
```java
// BAD: Decorator doesn't call wrapped object
public class BrokenDecorator extends DataSourceDecorator {
    @Override
    public void writeData(String data) {
        log(data);
        // Forgot to call super.writeData(data)!
    }
}

// GOOD: Always delegate
public class GoodDecorator extends DataSourceDecorator {
    @Override
    public void writeData(String data) {
        log(data);
        super.writeData(data);  // Delegate to wrapped
    }
}
```

### 3. Order-Dependent Without Documentation
```java
// BAD: Order matters but not documented
DataSource source = new CompressionDecorator(
    new EncryptionDecorator(fileSource)
);
// Encrypts then compresses - is this intentional?

// GOOD: Document the expected order
/**
 * Data flow: compress -> encrypt -> write
 * Read flow: read -> decrypt -> decompress
 *
 * Compression before encryption is more efficient.
 */
DataSource source = new EncryptionDecorator(
    new CompressionDecorator(fileSource)
);
```

## Decorator vs. Inheritance

| Decorator | Inheritance |
|-----------|-------------|
| Runtime composition | Compile-time |
| Single object affected | All instances |
| Can be removed | Permanent |
| Flexible combinations | Fixed hierarchy |
| Slight overhead | No overhead |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Adapter** | Changes interface; Decorator keeps same interface |
| **Composite** | Similar structure but different intent |
| **Strategy** | Changes internals; Decorator wraps |
| **Proxy** | Same interface but controls access; Decorator adds behavior |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [java.io](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/io/package-summary.html) | Classic decorator example: `BufferedInputStream`, `GZIPInputStream` |
| **Java** | [Spring Security](https://spring.io/projects/spring-security) | Filter chain uses decorator pattern |
| **Java** | [Lombok @Delegate](https://projectlombok.org/features/Delegate) | Reduces decorator boilerplate |
| **Go** | [io](https://pkg.go.dev/io) | `io.Reader`/`Writer` wrappers are decorators |
| **Go** | [net/http](https://pkg.go.dev/net/http) | Middleware handlers are decorators |
| **Python** | [functools.wraps](https://docs.python.org/3/library/functools.html#functools.wraps) | Built-in decorator support |
| **Python** | [wrapt](https://wrapt.readthedocs.io/) | Advanced decorator utilities |
| **Python** | [decorator](https://pypi.org/project/decorator/) | Simplifies decorator definition |
| **JavaScript** | [lodash.wrap](https://lodash.com/docs/#wrap) | Function wrapper utility |
| **JavaScript** | TC39 Decorators | Language-level decorator syntax (Stage 3) |

## References

- GoF p.175
- Refactoring Guru: https://refactoring.guru/design-patterns/decorator
- Java I/O Streams documentation
