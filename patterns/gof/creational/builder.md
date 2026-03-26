# Builder Pattern

> Separate construction of a complex object from its representation, allowing the same construction process to create different representations.

## Intent

Construct complex objects step-by-step. The pattern allows producing different types and representations of an object using the same construction code.

## When to Use

- Object has many constructor parameters (>4-5)
- You need immutable objects with many fields
- You want a fluent API for construction
- Construction involves multiple steps that can vary
- You need to build different representations of the same type

## When NOT to Use

- Object has few fields (2-3) - use constructor
- Object is mutable - just use setters
- Single representation - don't need the abstraction
- **CRITICAL**: Single implementation with no variation - this is cargo cult

## Structure

```
┌─────────────┐         ┌─────────────┐
│  Director   │────────▶│  Builder    │ (interface)
└─────────────┘         └─────────────┘
                              △
                              │
                    ┌─────────┴─────────┐
                    │                   │
             ┌──────┴──────┐    ┌───────┴─────┐
             │ConcreteBuilderA│    │ConcreteBuilderB│
             └─────────────┘    └─────────────┘
```

**Note**: In modern usage, often simplified to just Builder + Product (no Director).

## Language Examples

### Java (Canonical - Effective Java Style)

```java
// Product - immutable
public final class HttpRequest {
    private final String url;
    private final String method;
    private final Map<String, String> headers;
    private final byte[] body;
    private final Duration timeout;

    private HttpRequest(Builder builder) {
        this.url = Objects.requireNonNull(builder.url);
        this.method = builder.method;
        this.headers = Map.copyOf(builder.headers);
        this.body = builder.body != null ? builder.body.clone() : null;
        this.timeout = builder.timeout;
    }

    // Getters only, no setters
    public String url() { return url; }
    public String method() { return method; }
    // ...

    public static Builder builder(String url) {
        return new Builder(url);
    }

    public static final class Builder {
        // Required
        private final String url;

        // Optional with defaults
        private String method = "GET";
        private final Map<String, String> headers = new HashMap<>();
        private byte[] body;
        private Duration timeout = Duration.ofSeconds(30);

        private Builder(String url) {
            this.url = url;
        }

        public Builder method(String method) {
            this.method = Objects.requireNonNull(method);
            return this;
        }

        public Builder header(String name, String value) {
            this.headers.put(name, value);
            return this;
        }

        public Builder body(byte[] body) {
            this.body = body;
            return this;
        }

        public Builder timeout(Duration timeout) {
            this.timeout = Objects.requireNonNull(timeout);
            return this;
        }

        public HttpRequest build() {
            // Validation
            if (body != null && "GET".equals(method)) {
                throw new IllegalStateException("GET requests cannot have body");
            }
            return new HttpRequest(this);
        }
    }
}

// Usage
HttpRequest request = HttpRequest.builder("https://api.example.com")
    .method("POST")
    .header("Content-Type", "application/json")
    .body(jsonBytes)
    .timeout(Duration.ofSeconds(10))
    .build();
```

### Go (Functional Options - Idiomatic Alternative)

Go doesn't use the traditional Builder pattern. Use **Functional Options** instead:

```go
// Product
type Server struct {
    addr         string
    port         int
    timeout      time.Duration
    maxConns     int
    tlsConfig    *tls.Config
}

// Option type
type Option func(*Server)

// Option functions
func WithPort(port int) Option {
    return func(s *Server) {
        s.port = port
    }
}

func WithTimeout(d time.Duration) Option {
    return func(s *Server) {
        s.timeout = d
    }
}

func WithTLS(config *tls.Config) Option {
    return func(s *Server) {
        s.tlsConfig = config
    }
}

// Constructor with options
func NewServer(addr string, opts ...Option) *Server {
    // Defaults
    s := &Server{
        addr:    addr,
        port:    8080,
        timeout: 30 * time.Second,
        maxConns: 100,
    }

    // Apply options
    for _, opt := range opts {
        opt(s)
    }

    return s
}

// Usage
server := NewServer("localhost",
    WithPort(9000),
    WithTimeout(time.Minute),
    WithTLS(tlsConfig),
)
```

### Python (dataclass with factory)

```python
from dataclasses import dataclass, field
from typing import Optional
from datetime import timedelta

@dataclass(frozen=True)  # Immutable
class HttpRequest:
    url: str
    method: str = "GET"
    headers: dict[str, str] = field(default_factory=dict)
    body: Optional[bytes] = None
    timeout: timedelta = timedelta(seconds=30)

    def __post_init__(self):
        if self.body and self.method == "GET":
            raise ValueError("GET requests cannot have body")

# For complex construction, use a builder class
class HttpRequestBuilder:
    def __init__(self, url: str):
        self._url = url
        self._method = "GET"
        self._headers: dict[str, str] = {}
        self._body: Optional[bytes] = None
        self._timeout = timedelta(seconds=30)

    def method(self, method: str) -> "HttpRequestBuilder":
        self._method = method
        return self

    def header(self, name: str, value: str) -> "HttpRequestBuilder":
        self._headers[name] = value
        return self

    def body(self, body: bytes) -> "HttpRequestBuilder":
        self._body = body
        return self

    def build(self) -> HttpRequest:
        return HttpRequest(
            url=self._url,
            method=self._method,
            headers=self._headers,
            body=self._body,
            timeout=self._timeout,
        )

# Usage
request = (HttpRequestBuilder("https://api.example.com")
    .method("POST")
    .header("Content-Type", "application/json")
    .body(json_bytes)
    .build())
```

## Review Checklist

### Appropriate Use
- [ ] **[BLOCKER]** More than 4-5 constructor parameters exist
- [ ] **[BLOCKER]** Object needs to be immutable after construction
- [ ] **[MAJOR]** Construction involves validation across multiple fields
- [ ] **[MAJOR]** Multiple representations actually exist (or are planned)

### Correct Implementation
- [ ] **[BLOCKER]** `build()` validates invariants before creating object
- [ ] **[BLOCKER]** Product is immutable (no setters after construction)
- [ ] **[MAJOR]** Required fields enforced (constructor param or build-time check)
- [ ] **[MAJOR]** Builder is reusable or clearly documented as single-use
- [ ] **[MINOR]** Fluent API returns `this` for chaining

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Builder for class with 2-3 fields (just use constructor)
- [ ] **[MAJOR]** Builder that doesn't validate anything
- [ ] **[MAJOR]** Product with setters (defeats immutability purpose)
- [ ] **[MINOR]** `build()` can be called multiple times creating different objects

## Common Mistakes

### 1. Builder for Simple Objects
```java
// BAD: Overkill for simple object
Point.builder().x(1).y(2).build();

// GOOD: Just use constructor
new Point(1, 2);
```

### 2. Mutable Product
```java
// BAD: Builder creates mutable object
class User {
    private String name;
    public void setName(String name) { this.name = name; }  // Defeats purpose
}

// GOOD: Immutable product
class User {
    private final String name;
    private User(Builder b) { this.name = b.name; }
    public String name() { return name; }
}
```

### 3. No Validation
```java
// BAD: Build doesn't validate
public User build() {
    return new User(this);  // Invalid state possible
}

// GOOD: Validate invariants
public User build() {
    if (email == null || !email.contains("@")) {
        throw new IllegalStateException("Valid email required");
    }
    return new User(this);
}
```

## Testing Strategy

### What to Test
1. **Required fields**: Build fails without them
2. **Default values**: Unset optional fields have correct defaults
3. **Validation**: Invalid combinations rejected at build time
4. **Immutability**: Built object cannot be modified

### How to Test

```java
class HttpRequestBuilderTest {

    @Test
    void shouldRequireUrl() {
        // Required field enforced via constructor
        assertThrows(NullPointerException.class, () ->
            HttpRequest.builder(null).build()
        );
    }

    @Test
    void shouldUseDefaultMethod() {
        HttpRequest request = HttpRequest.builder("https://example.com").build();

        assertThat(request.method()).isEqualTo("GET");
    }

    @Test
    void shouldRejectBodyOnGetRequest() {
        var builder = HttpRequest.builder("https://example.com")
            .method("GET")
            .body(new byte[]{1, 2, 3});

        assertThrows(IllegalStateException.class, builder::build);
    }

    @Test
    void shouldCreateImmutableHeaders() {
        HttpRequest request = HttpRequest.builder("https://example.com")
            .header("Content-Type", "application/json")
            .build();

        // Headers should be immutable
        assertThrows(UnsupportedOperationException.class, () ->
            request.headers().put("X-New", "value")
        );
    }
}
```

```go
// Go - Test functional options
func TestServerOptions(t *testing.T) {
    t.Run("default values", func(t *testing.T) {
        s := NewServer("localhost")
        if s.port != 8080 {
            t.Errorf("expected default port 8080, got %d", s.port)
        }
    })

    t.Run("with custom port", func(t *testing.T) {
        s := NewServer("localhost", WithPort(9000))
        if s.port != 9000 {
            t.Errorf("expected port 9000, got %d", s.port)
        }
    })

    t.Run("options compose", func(t *testing.T) {
        s := NewServer("localhost",
            WithPort(9000),
            WithTimeout(time.Minute),
        )
        if s.port != 9000 || s.timeout != time.Minute {
            t.Error("options not applied correctly")
        }
    })
}
```

### What to Mock
- **Nothing!** Builders are pure construction logic
- Test the builder in isolation
- Test products separately from builders

### Testing Anti-Patterns
- ❌ Testing private builder state (test via built product)
- ❌ Not testing validation rules
- ❌ Not verifying immutability of built objects

## Often Composed With

| Pattern | Composition | Example |
|---------|-------------|---------|
| **Factory Method** | Factory returns builder | `DocumentFactory.builder("pdf")` |
| **Prototype** | Builder clones prototype | `builder.from(existingRequest).header("X-New", "val")` |
| **Director** | Director orchestrates build steps | `director.constructSportsCarBuilder(builder)` |
| **Fluent Interface** | Builder methods return `this` | `builder.method("POST").header(...).build()` |
| **Immutable Object** | Builder is the only way to create immutable objects | Records/value objects |

### Common Composition: Copy Constructor via Builder
```java
// Create modified copy of immutable object
HttpRequest original = HttpRequest.builder("https://api.example.com")
    .method("GET")
    .build();

// "Copy" with modification
HttpRequest modified = HttpRequest.builder(original)  // Copy constructor
    .header("Authorization", "Bearer token")
    .build();
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Abstract Factory** | Returns complete objects; Builder constructs step-by-step |
| **Prototype** | Alternative when construction is expensive |
| **Fluent Interface** | Builder often implements fluent style |

## When to Refactor Away

Consider removing Builder when:
- Class simplified to fewer fields
- Immutability no longer required
- Only one way to build the object
- Java record or Go struct literal suffices

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Lombok @Builder](https://projectlombok.org/features/Builder) | Generate builder at compile time |
| **Java** | [Immutables](https://immutables.github.io/) | Generate immutable objects with builders |
| **Java** | [AutoValue](https://github.com/google/auto/tree/main/value) | Generate value types with builder support |
| **Java** | [jOOQ Record Builder](https://www.jooq.org/) | DSL builders for SQL records |
| **Go** | Functional Options | Idiomatic pattern, no library needed |
| **Go** | [go-funk](https://github.com/thoas/go-funk) | Functional utilities including builders |
| **Python** | [attrs](https://www.attrs.org/) | Class builder with validation |
| **Python** | [pydantic](https://pydantic-docs.helpmanual.io/) | Data validation and settings with builder-like API |
| **Python** | [dataclasses](https://docs.python.org/3/library/dataclasses.html) | Built-in, with `replace()` for immutable updates |
| **JavaScript** | [zod](https://zod.dev/) | Schema builder with TypeScript inference |
| **JavaScript** | [yup](https://github.com/jquense/yup) | Schema builder for validation |
| **Kotlin** | Built-in | Data classes with `copy()` make builders unnecessary |

## References

- GoF p.97
- Effective Java, Item 2: "Consider a builder when faced with many constructor parameters"
- Go Functional Options: https://dave.cheney.net/2014/10/17/functional-options-for-friendly-apis
