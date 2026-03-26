# Strategy Pattern

> Define a family of algorithms, encapsulate each one, and make them interchangeable. Strategy lets the algorithm vary independently from clients that use it.

## Intent

Enable selecting an algorithm at runtime. Instead of implementing a single algorithm directly, code receives runtime instructions about which algorithm to use.

## When to Use

- Multiple algorithms exist for the same task
- Algorithms can be selected at runtime
- You want to eliminate conditional statements for algorithm selection
- Different variants of an algorithm are needed
- Algorithm uses data clients shouldn't know about

## When NOT to Use

- Only one algorithm exists (premature abstraction)
- Algorithm selection is compile-time only
- Simple conditional (2-3 cases) is clearer
- **CRITICAL**: You're adding Strategy "for future extensibility" with no current need

## Structure

```
┌─────────────┐        ┌─────────────┐
│   Context   │───────▶│  Strategy   │ (interface)
└─────────────┘        └─────────────┘
                             △
                             │
               ┌─────────────┼─────────────┐
               │             │             │
        ┌──────┴──────┐ ┌────┴────┐ ┌──────┴──────┐
        │ConcreteStratA│ │Strategy B│ │ConcreteStratC│
        └─────────────┘ └─────────┘ └─────────────┘
```

## Language Examples

### Java

```java
// Strategy interface
@FunctionalInterface
public interface CompressionStrategy {
    byte[] compress(byte[] data);
}

// Concrete strategies
public class GzipCompression implements CompressionStrategy {
    @Override
    public byte[] compress(byte[] data) {
        // gzip implementation
    }
}

public class ZstdCompression implements CompressionStrategy {
    private final int level;

    public ZstdCompression(int level) {
        this.level = level;
    }

    @Override
    public byte[] compress(byte[] data) {
        // zstd implementation with level
    }
}

// Context
public class FileArchiver {
    private final CompressionStrategy compression;

    public FileArchiver(CompressionStrategy compression) {
        this.compression = compression;
    }

    public void archive(Path source, Path dest) {
        byte[] data = Files.readAllBytes(source);
        byte[] compressed = compression.compress(data);
        Files.write(dest, compressed);
    }
}

// Usage - strategy selected at runtime
CompressionStrategy strategy = switch (config.getCompression()) {
    case "gzip" -> new GzipCompression();
    case "zstd" -> new ZstdCompression(config.getLevel());
    default -> throw new IllegalArgumentException("Unknown compression");
};

FileArchiver archiver = new FileArchiver(strategy);
archiver.archive(source, dest);

// Or with lambdas for simple strategies
FileArchiver noCompression = new FileArchiver(data -> data);  // Identity
```

### Go

```go
// Strategy as interface
type Hasher interface {
    Hash(data []byte) ([]byte, error)
}

// Concrete strategies
type SHA256Hasher struct{}

func (h SHA256Hasher) Hash(data []byte) ([]byte, error) {
    sum := sha256.Sum256(data)
    return sum[:], nil
}

type SHA512Hasher struct{}

func (h SHA512Hasher) Hash(data []byte) ([]byte, error) {
    sum := sha512.Sum512(data)
    return sum[:], nil
}

// Context
type FileVerifier struct {
    hasher Hasher
}

func NewFileVerifier(hasher Hasher) *FileVerifier {
    return &FileVerifier{hasher: hasher}
}

func (v *FileVerifier) Verify(path string, expected []byte) (bool, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return false, fmt.Errorf("read file: %w", err)
    }

    actual, err := v.hasher.Hash(data)
    if err != nil {
        return false, fmt.Errorf("hash: %w", err)
    }

    return bytes.Equal(actual, expected), nil
}

// Usage
var hasher Hasher
switch algo {
case "sha256":
    hasher = SHA256Hasher{}
case "sha512":
    hasher = SHA512Hasher{}
}

verifier := NewFileVerifier(hasher)
ok, err := verifier.Verify("file.txt", expectedHash)
```

### Python

```python
from abc import ABC, abstractmethod
from typing import Callable

# Strategy as protocol/ABC
class SortStrategy(ABC):
    @abstractmethod
    def sort(self, data: list) -> list:
        pass

# Concrete strategies
class QuickSort(SortStrategy):
    def sort(self, data: list) -> list:
        if len(data) <= 1:
            return data
        pivot = data[len(data) // 2]
        left = [x for x in data if x < pivot]
        middle = [x for x in data if x == pivot]
        right = [x for x in data if x > pivot]
        return self.sort(left) + middle + self.sort(right)

class MergeSort(SortStrategy):
    def sort(self, data: list) -> list:
        # merge sort implementation
        pass

# Context
class DataProcessor:
    def __init__(self, sort_strategy: SortStrategy):
        self._sort_strategy = sort_strategy

    def process(self, data: list) -> list:
        return self._sort_strategy.sort(data)

# Usage
processor = DataProcessor(QuickSort())
result = processor.process([3, 1, 4, 1, 5])

# Python idiom: functions as strategies
def bubble_sort(data: list) -> list:
    # implementation
    pass

class FunctionalProcessor:
    def __init__(self, sort_fn: Callable[[list], list]):
        self._sort = sort_fn

    def process(self, data: list) -> list:
        return self._sort(data)

# Even simpler with just functions
processor = FunctionalProcessor(sorted)  # Use built-in
```

## Review Checklist

### Appropriate Use
- [ ] **[BLOCKER]** Multiple algorithms actually exist today (not "might need")
- [ ] **[BLOCKER]** Algorithm selected at runtime (not compile-time constant)
- [ ] **[MAJOR]** Algorithms are interchangeable (same interface makes sense)
- [ ] **[MINOR]** Eliminates complex conditional logic

### Correct Implementation
- [ ] **[BLOCKER]** Strategy injected via constructor (not created internally)
- [ ] **[MAJOR]** Strategy interface is minimal (single method preferred)
- [ ] **[MAJOR]** Context doesn't know about concrete strategies
- [ ] **[MINOR]** Strategies are stateless or clearly document state

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Single concrete strategy (premature abstraction)
- [ ] **[BLOCKER]** Strategy created inside context (defeats purpose)
- [ ] **[MAJOR]** Interface with many methods (should be smaller)
- [ ] **[MAJOR]** Conditional inside strategy selection that could be the strategy

## Common Mistakes

### 1. Premature Strategy
```java
// BAD: Only one implementation exists
interface PaymentProcessor { void process(Payment p); }
class StripeProcessor implements PaymentProcessor { ... }
// No other processors exist or are planned!

// GOOD: Just use the concrete class directly
class StripeProcessor {
    void process(Payment p) { ... }
}
// Extract interface when second implementation appears
```

### 2. Strategy Created Inside Context
```java
// BAD: Context creates strategy (defeats DI)
class Archiver {
    void archive(String type, byte[] data) {
        Compressor c = switch (type) {
            case "gzip" -> new GzipCompressor();  // Tight coupling!
            default -> new NoopCompressor();
        };
        c.compress(data);
    }
}

// GOOD: Strategy injected
class Archiver {
    private final Compressor compressor;

    Archiver(Compressor compressor) {
        this.compressor = compressor;
    }

    void archive(byte[] data) {
        compressor.compress(data);
    }
}
```

### 3. Fat Strategy Interface
```java
// BAD: Too many methods
interface DataStrategy {
    void load();
    void transform();
    void validate();
    void save();
    void cleanup();
}

// GOOD: Single responsibility
interface Transformer {
    Data transform(Data input);
}
```

## Language-Specific Notes

### Java
- Use `@FunctionalInterface` for single-method strategies (enables lambdas)
- Consider method references: `new Processor(String::toLowerCase)`
- Enum can implement strategy: `enum Compression implements Compressor`

### Go
- Functions are first-class; often no interface needed
- `type StrategyFunc func([]byte) []byte` is valid
- Keep interfaces small (Go proverb: "The bigger the interface, the weaker the abstraction")

### Python
- Functions as strategies are idiomatic (no class needed)
- Use `Callable[[Input], Output]` type hint
- `Protocol` from typing for structural typing

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **State** | Similar structure; State changes behavior via state object, Strategy is chosen by client |
| **Template Method** | Algorithm skeleton with overridable steps (inheritance) vs. entire algorithm delegation (composition) |
| **Command** | Command encapsulates request; Strategy encapsulates algorithm |
| **Decorator** | Decorator adds behavior; Strategy replaces behavior |

## Testing Strategy

### What to Test
1. **Each concrete strategy**: Unit test each algorithm independently
2. **Context behavior**: Test context uses strategy correctly
3. **Strategy selection**: Test factory/selector logic
4. **Edge cases**: Test with null/empty inputs

### How to Test

```java
// Test each strategy independently
class GzipCompressionTest {
    @Test
    void shouldCompressAndDecompress() {
        GzipCompression gzip = new GzipCompression();
        byte[] original = "test data".getBytes();

        byte[] compressed = gzip.compress(original);
        byte[] decompressed = gzip.decompress(compressed);

        assertThat(decompressed).isEqualTo(original);
    }
}

// Test context with mock strategy
class FileArchiverTest {
    @Test
    void shouldUseInjectedStrategy() {
        // Given - spy to verify call
        CompressionStrategy mockStrategy = mock(CompressionStrategy.class);
        when(mockStrategy.compress(any())).thenReturn(new byte[]{1, 2, 3});

        FileArchiver archiver = new FileArchiver(mockStrategy);

        // When
        archiver.archive(testFile, outputFile);

        // Then - strategy was called
        verify(mockStrategy).compress(any());
    }

    @Test
    void shouldWorkWithNoOpStrategy() {
        // Test with identity strategy (no compression)
        FileArchiver archiver = new FileArchiver(data -> data);

        archiver.archive(testFile, outputFile);

        // Output equals input
        assertThat(Files.readAllBytes(outputFile))
            .isEqualTo(Files.readAllBytes(testFile));
    }
}
```

```go
// Go - Table-driven tests for all strategies
func TestHashers(t *testing.T) {
    tests := []struct {
        name     string
        hasher   Hasher
        input    []byte
        wantLen  int
    }{
        {"SHA256", SHA256Hasher{}, []byte("test"), 32},
        {"SHA512", SHA512Hasher{}, []byte("test"), 64},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := tt.hasher.Hash(tt.input)
            if err != nil {
                t.Fatal(err)
            }
            if len(result) != tt.wantLen {
                t.Errorf("got len %d, want %d", len(result), tt.wantLen)
            }
        })
    }
}
```

### What to Mock
- **In strategy tests**: Mock nothing - test the algorithm
- **In context tests**: Mock strategy to verify it's called
- **In integration tests**: Use real strategies

### Testing Anti-Patterns
- ❌ Only testing the context, not individual strategies
- ❌ Testing strategy internals instead of inputs/outputs
- ❌ Complex setup to test simple strategies (KISS)

## Often Composed With

| Pattern | Composition | Example |
|---------|-------------|---------|
| **Factory Method** | Factory creates appropriate strategy | `CompressionFactory.forFormat(format)` |
| **Dependency Injection** | Strategies injected via constructor | `new Archiver(compressionStrategy)` |
| **Template Method** | Template calls strategy at extension point | Algorithm skeleton calls strategy for one step |
| **Decorator** | Decorate strategy with logging/metrics | `new LoggingStrategy(actualStrategy)` |
| **Configuration** | Strategy selected from config | `@Value("${compression.type}")` |

### Strategy Selection Patterns
```java
// Via factory
CompressionStrategy strategy = CompressionFactory.create(config.getType());

// Via Map lookup
Map<String, CompressionStrategy> strategies = Map.of(
    "gzip", new GzipCompression(),
    "zstd", new ZstdCompression()
);
CompressionStrategy strategy = strategies.get(config.getType());

// Via enum
enum Compression implements CompressionStrategy {
    GZIP { public byte[] compress(byte[] data) { ... } },
    ZSTD { public byte[] compress(byte[] data) { ... } }
}
```

## When to Refactor Away

Consider removing Strategy when:
- Down to single implementation
- Selection is always compile-time (just use concrete type)
- Simple conditional is clearer than indirection
- Lambda/function reference makes interface unnecessary

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [java.util.Comparator](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/Comparator.html) | Classic strategy: pluggable sorting |
| **Java** | [java.util.function](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/function/package-summary.html) | Functional interfaces enable lambdas as strategies |
| **Java** | [Spring @Qualifier](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/beans/factory/annotation/Qualifier.html) | Inject different strategy implementations |
| **Go** | [sort.Interface](https://pkg.go.dev/sort#Interface) | Strategy for custom sorting |
| **Go** | [http.Handler](https://pkg.go.dev/net/http#Handler) | Handler strategy for HTTP processing |
| **Python** | [functools.cmp_to_key](https://docs.python.org/3/library/functools.html#functools.cmp_to_key) | Convert comparison functions to keys |
| **Python** | [typing.Protocol](https://docs.python.org/3/library/typing.html#typing.Protocol) | Structural typing for strategy interfaces |
| **JavaScript** | Built-in | First-class functions make external libraries unnecessary |

**Note**: Strategy pattern is so fundamental that most languages have built-in support. External libraries are rarely needed.

## References

- GoF p.315
- Refactoring Guru: https://refactoring.guru/design-patterns/strategy
- "Replace Conditional with Polymorphism" - Fowler's Refactoring
