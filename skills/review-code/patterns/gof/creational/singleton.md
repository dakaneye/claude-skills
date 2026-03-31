# Singleton Pattern

> Ensure a class has only one instance and provide a global point of access to it.

## Intent

Control object creation, limiting the number of instances to exactly one. Provide a global access point to that instance.

## When to Use

- Exactly one instance is needed (logging, configuration, connection pools)
- The single instance should be accessible throughout the application
- You need lazy initialization of a resource-heavy object

## When NOT to Use

- Testing is important (singletons are hard to mock)
- Dependency injection is available (prefer it)
- Multiple instances might be needed later
- **CRITICAL**: In modern applications, prefer DI over Singleton 99% of the time

## The Problem with Singleton

Singleton is often considered an **anti-pattern** in modern development because:
1. **Hidden dependencies** - Code depends on global state
2. **Testing difficulty** - Can't substitute mock implementations
3. **Tight coupling** - Hard to change later
4. **Concurrency issues** - Thread safety is tricky

**Modern alternative**: Dependency Injection with scoped lifetimes.

## Structure

```
┌──────────────────────────┐
│        Singleton         │
├──────────────────────────┤
│ - instance: Singleton    │
├──────────────────────────┤
│ - Singleton()            │ (private constructor)
│ + getInstance(): Singleton│
│ + businessMethod()       │
└──────────────────────────┘
```

## Language Examples

### Java (Thread-Safe with Holder Pattern)

```java
// RECOMMENDED: Initialization-on-demand holder idiom
public class Configuration {
    // Private constructor prevents external instantiation
    private Configuration() {
        // Load configuration
    }

    // Holder class is not loaded until getInstance() is called
    private static class Holder {
        private static final Configuration INSTANCE = new Configuration();
    }

    public static Configuration getInstance() {
        return Holder.INSTANCE;
    }

    public String getProperty(String key) {
        // ...
    }
}

// Usage
String value = Configuration.getInstance().getProperty("db.url");
```

```java
// ALTERNATIVE: Enum singleton (Effective Java recommended)
public enum DatabaseConnection {
    INSTANCE;

    private final Connection connection;

    DatabaseConnection() {
        this.connection = createConnection();
    }

    public Connection getConnection() {
        return connection;
    }

    private Connection createConnection() {
        // Create connection
    }
}

// Usage
Connection conn = DatabaseConnection.INSTANCE.getConnection();
```

```java
// BETTER: Dependency Injection (preferred over Singleton)
@Singleton  // Container manages single instance
public class Configuration {
    @Inject
    public Configuration(ConfigSource source) {
        // ...
    }
}

// Usage - injected, not fetched
public class UserService {
    private final Configuration config;

    @Inject
    public UserService(Configuration config) {
        this.config = config;  // Injected by container
    }
}
```

### Go (sync.Once - Idiomatic)

```go
package config

import (
    "sync"
)

type Config struct {
    DatabaseURL string
    APIKey      string
}

var (
    instance *Config
    once     sync.Once
)

// GetConfig returns the singleton config instance
func GetConfig() *Config {
    once.Do(func() {
        instance = &Config{
            DatabaseURL: os.Getenv("DATABASE_URL"),
            APIKey:      os.Getenv("API_KEY"),
        }
    })
    return instance
}

// BETTER: Dependency injection
// Instead of singleton, create config once in main() and pass it
func main() {
    config := &Config{
        DatabaseURL: os.Getenv("DATABASE_URL"),
    }

    server := NewServer(config)  // Pass as dependency
    server.Run()
}
```

### Python

```python
# Method 1: Module-level (Python idiom)
# config.py
_config = None

def get_config():
    global _config
    if _config is None:
        _config = _load_config()
    return _config

def _load_config():
    # Load from file/env
    pass


# Method 2: Class with __new__
class Singleton:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        # Initialize once
        self._initialized = True


# Method 3: Metaclass (most Pythonic for classes)
class SingletonMeta(type):
    _instances = {}

    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super().__call__(*args, **kwargs)
        return cls._instances[cls]

class Database(metaclass=SingletonMeta):
    def __init__(self):
        self.connection = create_connection()


# BETTER: Just use dependency injection
# Create once in main, pass to constructors
def main():
    config = load_config()
    db = Database(config)
    app = Application(db)  # Pass dependencies
```

## Review Checklist

### Is Singleton Necessary?
- [ ] **[BLOCKER]** Can this be replaced with dependency injection? (Usually yes)
- [ ] **[BLOCKER]** Is there truly only one valid instance? (Not "convenient", but necessary)
- [ ] **[MAJOR]** Is global access actually required?

### If Singleton is Used
- [ ] **[BLOCKER]** Thread-safe initialization
- [ ] **[BLOCKER]** No mutable global state (or properly synchronized)
- [ ] **[MAJOR]** Testable (can reset or substitute for tests)
- [ ] **[MAJOR]** Lazy initialization if resource-heavy

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Singleton used when DI is available
- [ ] **[BLOCKER]** Non-thread-safe double-checked locking
- [ ] **[MAJOR]** Multiple singletons depending on each other
- [ ] **[MAJOR]** Singleton with mutable state

## Common Mistakes

### 1. Broken Double-Checked Locking
```java
// BAD: Race condition in naive double-checked locking
public class BrokenSingleton {
    private static BrokenSingleton instance;

    public static BrokenSingleton getInstance() {
        if (instance == null) {              // Thread A checks
            synchronized (BrokenSingleton.class) {
                if (instance == null) {      // Thread A creates
                    instance = new BrokenSingleton();  // Partially constructed!
                }
            }
        }
        return instance;  // Thread B may see partial object
    }
}

// GOOD: Use volatile or holder pattern
private static volatile Singleton instance;  // volatile required!

// BETTER: Holder pattern (no synchronization needed)
private static class Holder {
    static final Singleton INSTANCE = new Singleton();
}
```

### 2. Hidden Dependencies
```java
// BAD: Hidden dependency on singleton
public class OrderService {
    public void placeOrder(Order order) {
        Database.getInstance().save(order);  // Hidden dependency!
        EmailService.getInstance().send(...);  // Another one!
    }
}

// GOOD: Explicit dependencies
public class OrderService {
    private final Database database;
    private final EmailService emailService;

    public OrderService(Database database, EmailService emailService) {
        this.database = database;
        this.emailService = emailService;
    }

    public void placeOrder(Order order) {
        database.save(order);
        emailService.send(...);
    }
}
```

### 3. Untestable Code
```java
// BAD: Can't test without real database
public void processData() {
    Database db = Database.getInstance();  // Can't mock!
    db.query(...);
}

// GOOD: Dependency injection allows mocking
public void processData(Database db) {
    db.query(...);  // Can pass mock in tests
}
```

## Modern Alternatives

### Dependency Injection Containers

| Framework | Singleton Scope |
|-----------|----------------|
| Spring | `@Scope("singleton")` (default) |
| Guice | `@Singleton` |
| Dagger | `@Singleton` |
| .NET | `services.AddSingleton<T>()` |

```java
// Spring - container manages single instance
@Service  // Singleton by default
public class UserService {
    // ...
}

// Guice
@Singleton
public class Configuration {
    // ...
}
```

### When Singleton IS Appropriate

1. **Logging** - Truly global, stateless
2. **Configuration** - Read-only after init
3. **Hardware access** - Single physical resource
4. **Caches** - Application-wide shared cache

Even in these cases, prefer DI with singleton scope over the Singleton pattern.

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Factory Method** | Often used to create the singleton instance |
| **Abstract Factory** | Can be implemented as singleton |
| **Flyweight** | Manages many instances; Singleton manages one |
| **Monostate** | All instances share state (alternative to Singleton) |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Framework](https://spring.io/) | `@Scope("singleton")` (default) - DI-managed singletons |
| **Java** | [Guice](https://github.com/google/guice) | `@Singleton` annotation |
| **Java** | [Dagger](https://dagger.dev/) | `@Singleton` with compile-time DI |
| **Go** | [sync.Once](https://pkg.go.dev/sync#Once) | Standard library lazy initialization |
| **Go** | [wire](https://github.com/google/wire) | Compile-time DI, can manage single instances |
| **Python** | [dependency-injector](https://python-dependency-injector.ets-labs.org/) | `Singleton` provider for DI containers |
| **Python** | [injector](https://github.com/python-injector/injector) | `@singleton` scope decorator |
| **JavaScript** | [InversifyJS](https://inversify.io/) | `inSingletonScope()` binding |
| **JavaScript** | [tsyringe](https://github.com/microsoft/tsyringe) | `@singleton()` decorator |
| **.NET** | [Microsoft.Extensions.DI](https://docs.microsoft.com/en-us/dotnet/core/extensions/dependency-injection) | `AddSingleton<T>()` registration |

**Note**: Modern applications should use DI containers with singleton scope rather than implementing the Singleton pattern directly. DI-managed singletons are testable and explicit about dependencies.

## References

- GoF p.127
- Effective Java, Item 3: "Enforce the singleton property with a private constructor or an enum type"
- "Singletons are Pathological Liars" - Misko Hevery (Google Testing Blog)
