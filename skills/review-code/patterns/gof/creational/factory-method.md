# Factory Method Pattern

> Define an interface for creating an object, but let subclasses decide which class to instantiate. Factory Method lets a class defer instantiation to subclasses.

## Intent

Provide an interface for creating objects in a superclass, while allowing subclasses to alter the type of objects created.

## Confusion Alert: Factory Method vs. Abstract Factory vs. Simple Factory

| Pattern | What It Does | Structure |
|---------|-------------|-----------|
| **Factory Method** | Subclass decides what to create | Single method, inheritance-based |
| **Abstract Factory** | Create families of related objects | Multiple methods, composition-based |
| **Simple Factory** | Centralize object creation (not GoF) | Static method, no inheritance |

Most "factory" code in the wild is **Simple Factory**, not Factory Method.

## When to Use

- Class can't anticipate what objects it needs to create
- Class wants subclasses to specify created objects
- You want to localize knowledge of which class gets created
- You're building a framework where users extend creation logic

## When NOT to Use

- You know the concrete type at compile time
- Simple `new` with constructor works
- Only one type will ever be created
- **CRITICAL**: Don't add factory "for testability" - use dependency injection instead

## Structure

```
┌─────────────────────┐
│      Creator        │ (abstract)
├─────────────────────┤
│ + factoryMethod()   │──────▶ Product (interface)
│ + someOperation()   │              △
└─────────────────────┘              │
         △                           │
         │                    ┌──────┴──────┐
┌────────┴────────┐           │             │
│ ConcreteCreator │───────▶ ConcreteProduct
└─────────────────┘
```

**Key insight**: Creator has OTHER methods that USE the factory method. If it's just a static creation method, that's Simple Factory.

## Language Examples

### Java (True Factory Method)

```java
// Product interface
public interface Document {
    void open();
    void save();
}

// Concrete products
public class PdfDocument implements Document {
    @Override public void open() { /* PDF logic */ }
    @Override public void save() { /* PDF logic */ }
}

public class WordDocument implements Document {
    @Override public void open() { /* Word logic */ }
    @Override public void save() { /* Word logic */ }
}

// Creator - has methods that USE the factory method
public abstract class Application {
    // Factory method - subclasses decide what to create
    protected abstract Document createDocument();

    // Operations that USE the factory method
    public void newDocument() {
        Document doc = createDocument();  // Uses factory method
        documents.add(doc);
        doc.open();
    }

    public void saveAll() {
        for (Document doc : documents) {
            doc.save();
        }
    }

    private final List<Document> documents = new ArrayList<>();
}

// Concrete creators
public class PdfApplication extends Application {
    @Override
    protected Document createDocument() {
        return new PdfDocument();
    }
}

public class WordApplication extends Application {
    @Override
    protected Document createDocument() {
        return new WordDocument();
    }
}

// Usage
Application app = new PdfApplication();
app.newDocument();  // Creates PdfDocument internally
app.saveAll();
```

### Simple Factory (Common but NOT Factory Method Pattern)

```java
// This is NOT the Factory Method pattern!
// It's a "Simple Factory" - useful but different

public class DocumentFactory {
    public static Document create(String type) {
        return switch (type) {
            case "pdf" -> new PdfDocument();
            case "word" -> new WordDocument();
            default -> throw new IllegalArgumentException("Unknown: " + type);
        };
    }
}

// Usage
Document doc = DocumentFactory.create("pdf");
```

### Go (Interface + Constructor Functions)

Go doesn't have inheritance, so Factory Method is less common. Use constructor functions and interfaces:

```go
// Product interface
type Logger interface {
    Log(message string)
}

// Concrete products
type FileLogger struct {
    path string
}

func (l *FileLogger) Log(message string) {
    // Write to file
}

type ConsoleLogger struct{}

func (l *ConsoleLogger) Log(message string) {
    fmt.Println(message)
}

// "Factory" as constructor function (Go idiom)
type LoggerFactory func() Logger

func NewFileLogger(path string) LoggerFactory {
    return func() Logger {
        return &FileLogger{path: path}
    }
}

func NewConsoleLogger() LoggerFactory {
    return func() Logger {
        return &ConsoleLogger{}
    }
}

// Service that uses factory
type Service struct {
    createLogger LoggerFactory
}

func NewService(factory LoggerFactory) *Service {
    return &Service{createLogger: factory}
}

func (s *Service) DoWork() {
    logger := s.createLogger()
    logger.Log("Starting work")
    // ...
}

// Usage
service := NewService(NewFileLogger("/var/log/app.log"))
service.DoWork()
```

### Python

```python
from abc import ABC, abstractmethod

# Product
class Transport(ABC):
    @abstractmethod
    def deliver(self, cargo: str) -> None:
        pass

class Truck(Transport):
    def deliver(self, cargo: str) -> None:
        print(f"Delivering {cargo} by road")

class Ship(Transport):
    def deliver(self, cargo: str) -> None:
        print(f"Delivering {cargo} by sea")

# Creator with factory method
class Logistics(ABC):
    @abstractmethod
    def create_transport(self) -> Transport:
        """Factory method - subclasses decide what to create"""
        pass

    def plan_delivery(self, cargo: str) -> None:
        """Uses the factory method"""
        transport = self.create_transport()
        transport.deliver(cargo)

class RoadLogistics(Logistics):
    def create_transport(self) -> Transport:
        return Truck()

class SeaLogistics(Logistics):
    def create_transport(self) -> Transport:
        return Ship()

# Usage
logistics = RoadLogistics()
logistics.plan_delivery("electronics")  # Uses Truck internally
```

## Review Checklist

### Is This Really Factory Method?
- [ ] **[BLOCKER]** Creator has OTHER methods that call the factory method
- [ ] **[BLOCKER]** Subclasses override the factory method
- [ ] **[MAJOR]** There are multiple concrete creators

If none of these: it's probably Simple Factory, not Factory Method.

### Appropriate Use
- [ ] **[BLOCKER]** Multiple product types exist (not single implementation)
- [ ] **[MAJOR]** Framework/library code where users extend behavior
- [ ] **[MAJOR]** Creator needs to do work with the created object

### Correct Implementation
- [ ] **[BLOCKER]** Factory method is protected/package-private (not public)
- [ ] **[MAJOR]** Creator doesn't know concrete product types
- [ ] **[MINOR]** Factory method has sensible default in base class (optional)

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Factory for single implementation (use DI instead)
- [ ] **[BLOCKER]** Public factory method on concrete class (just a static method)
- [ ] **[MAJOR]** Factory method is the ONLY method (that's Simple Factory)

## Common Mistakes

### 1. Confusing with Simple Factory
```java
// This is NOT Factory Method - it's Simple Factory
class ShapeFactory {
    public static Shape create(String type) { ... }
}

// Factory Method requires:
// 1. Abstract creator with other methods
// 2. Subclasses that override factory method
```

### 2. Factory for Single Type
```java
// BAD: Only one product type
interface UserRepository { ... }
class PostgresUserRepository implements UserRepository { ... }

class UserRepositoryFactory {
    UserRepository create() {
        return new PostgresUserRepository();  // Always same type!
    }
}

// GOOD: Just inject the concrete type
class UserService {
    UserService(UserRepository repo) { ... }
}
```

### 3. Public Factory Method
```java
// BAD: Factory method is public API
public abstract class Creator {
    public abstract Product createProduct();  // Wrong!
}

// GOOD: Factory method is implementation detail
public abstract class Creator {
    protected abstract Product createProduct();  // Internal use

    public void doSomething() {
        Product p = createProduct();  // Used here
        // ...
    }
}
```

## Testing Strategy

### What to Test
1. **Correct product creation**: Each creator creates expected product type
2. **Creator operations**: Methods that use factory method work correctly
3. **Product polymorphism**: All products fulfill the interface contract

### How to Test

```java
// Test each concrete creator
class PdfApplicationTest {
    @Test
    void shouldCreatePdfDocuments() {
        Application app = new PdfApplication();

        app.newDocument();

        // Verify via behavior, not instanceof
        Document doc = app.getDocuments().get(0);
        assertThat(doc.getFileExtension()).isEqualTo(".pdf");
    }
}

// Test creator operations work with any product
class ApplicationTest {
    @Test
    void shouldSaveAllDocuments() {
        // Use a test double creator
        Application app = new TestApplication();
        app.newDocument();
        app.newDocument();

        app.saveAll();

        // Verify all documents were saved
        assertThat(app.getDocuments())
            .allMatch(Document::isSaved);
    }

    // Test creator for controlled testing
    static class TestApplication extends Application {
        @Override
        protected Document createDocument() {
            return new TestDocument();  // Fast, in-memory document
        }
    }
}

// Test product interface contract
class DocumentContractTest {
    @ParameterizedTest
    @MethodSource("allDocumentTypes")
    void shouldImplementOpenAndSave(Document doc) {
        doc.open();
        doc.save();
        // No exceptions = contract fulfilled
    }

    static Stream<Document> allDocumentTypes() {
        return Stream.of(
            new PdfDocument(),
            new WordDocument()
        );
    }
}
```

```go
// Go - Test factory functions
func TestLoggerFactory(t *testing.T) {
    tests := []struct {
        name    string
        factory LoggerFactory
        wantLog string
    }{
        {"file logger", NewFileLogger("/tmp/test.log"), "file"},
        {"console logger", NewConsoleLogger(), "console"},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            logger := tt.factory()
            // Test via behavior
            logger.Log("test message")
        })
    }
}
```

### What to Mock
- **In creator tests**: Nothing - use concrete creators
- **In integration tests**: May use test creators with test products
- **For isolation**: Create test-specific subclass of creator

### Testing Anti-Patterns
- ❌ Testing with `instanceof` checks (test behavior, not type)
- ❌ Mocking the factory method itself (defeats purpose)
- ❌ Not testing all creator variants

## Often Composed With

| Pattern | Composition | Example |
|---------|-------------|---------|
| **Template Method** | Factory method as step in template | `template.process()` calls `createHandler()` |
| **Abstract Factory** | Abstract factory uses factory methods | Factory methods create each product type |
| **Dependency Injection** | Factory method configured via DI | `@Inject LoggerFactory loggerFactory` |
| **Registry** | Lookup creators by key | `CreatorRegistry.get("pdf").createDocument()` |
| **Singleton** | Creators often singletons | Each creator type exists once |

### Factory Method in Frameworks
```java
// Spring - BeanFactory uses factory methods
@Configuration
public class AppConfig {
    @Bean  // Factory method!
    public DataSource dataSource() {
        return new HikariDataSource(config);
    }
}

// Test configuration overrides factory methods
@TestConfiguration
public class TestConfig {
    @Bean
    public DataSource dataSource() {
        return new EmbeddedDatabaseBuilder().build();  // Test product
    }
}
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Abstract Factory** | Often implemented with Factory Methods; creates families vs. single products |
| **Template Method** | Factory Method is a specialization (creation step in template) |
| **Prototype** | Alternative that doesn't require subclassing |

## When to Refactor Away

Consider removing Factory Method when:
- Only one concrete creator exists
- Subclassing is unwieldy (use composition + Simple Factory)
- Dependency injection handles the variation

## Prefer Dependency Injection

Most uses of "factory" are better served by DI:

```java
// Instead of factory
class Service {
    private final RepositoryFactory factory;
    void doWork() {
        Repository repo = factory.create();  // Why create each time?
    }
}

// Use DI
class Service {
    private final Repository repo;
    Service(Repository repo) { this.repo = repo; }  // Injected once
    void doWork() { repo.save(...); }
}
```

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Framework](https://spring.io/) | `@Bean` factory methods, `FactoryBean` interface |
| **Java** | [Guice](https://github.com/google/guice) | `@Provides` methods, `Provider<T>` |
| **Java** | Standard Library | `List.of()`, `Optional.of()`, `Files.newInputStream()` |
| **Go** | Standard Library | Constructor functions `NewXxx()` are idiomatic |
| **Go** | [wire](https://github.com/google/wire) | Compile-time DI with provider functions |
| **Python** | Standard Library | `@classmethod` factories, `__new__` |
| **Python** | [Factory Boy](https://factoryboy.readthedocs.io/) | Test fixture factories |
| **JavaScript** | Standard Library | Factory functions are idiomatic |
| **JavaScript** | [InversifyJS](https://inversify.io/) | IoC container with factory bindings |

**Note**: Factory Method is a structural pattern built into most languages. DI containers assist with factory-like creation but are distinct from the GoF pattern.

## References

- GoF p.107
- Refactoring Guru: https://refactoring.guru/design-patterns/factory-method
- "Replace Constructor with Factory Method" - Fowler's Refactoring
