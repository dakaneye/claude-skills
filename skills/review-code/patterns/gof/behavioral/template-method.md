# Template Method Pattern

> Define the skeleton of an algorithm in an operation, deferring some steps to subclasses. Template Method lets subclasses redefine certain steps of an algorithm without changing the algorithm's structure.

## Intent

Define the overall structure of an algorithm in a base class, but let subclasses override specific steps without changing the algorithm's structure.

## When to Use

- Multiple classes have similar algorithms with some differences
- Want to control extension points in a framework
- Common behavior should be localized in a single class
- Algorithm has invariant parts and variant parts

## When NOT to Use

- Algorithms are completely different (not variants)
- Composition would work better (Strategy pattern)
- Too many abstract methods required (interface might be better)
- **Modern preference**: Composition over inheritance - consider Strategy first

## Structure

```
┌─────────────────────────┐
│    AbstractClass        │
├─────────────────────────┤
│ + templateMethod()      │  ← final (skeleton)
│ # step1()               │  ← may have default
│ # step2()               │  ← abstract (required)
│ # step3()               │  ← hook (optional)
└───────────┬─────────────┘
            │
   ┌────────┴────────┐
   │                 │
┌──┴───────┐  ┌──────┴────┐
│ConcreteA │  │ConcreteB  │
├──────────┤  ├───────────┤
│ # step1()│  │ # step1() │
│ # step2()│  │ # step2() │
└──────────┘  └───────────┘
```

## Language Examples

### Java

```java
// Abstract class with template method
public abstract class DataMiner {

    // Template method - defines algorithm skeleton (final prevents override)
    public final void mine(String path) {
        openFile(path);
        extractData();
        parseData();
        analyzeData();
        sendReport();
        closeFile();
    }

    // Abstract methods - subclasses MUST implement
    protected abstract void openFile(String path);
    protected abstract void extractData();
    protected abstract void closeFile();

    // Hook methods - subclasses CAN override (have default behavior)
    protected void parseData() {
        // Default parsing
        System.out.println("Default parsing...");
    }

    protected void analyzeData() {
        // Default analysis
        System.out.println("Default analysis...");
    }

    // Hook with empty default - extension point
    protected void sendReport() {
        // Default: no report
    }
}

// Concrete implementation for PDF
public class PdfMiner extends DataMiner {
    private PdfDocument document;

    @Override
    protected void openFile(String path) {
        this.document = PdfReader.open(path);
    }

    @Override
    protected void extractData() {
        // PDF-specific extraction
        for (PdfPage page : document.getPages()) {
            // Extract text from PDF
        }
    }

    @Override
    protected void closeFile() {
        document.close();
    }

    @Override
    protected void sendReport() {
        // PDF miner sends email reports
        EmailService.send(getReport());
    }
}

// Concrete implementation for CSV
public class CsvMiner extends DataMiner {
    private BufferedReader reader;
    private List<String[]> rows;

    @Override
    protected void openFile(String path) {
        this.reader = new BufferedReader(new FileReader(path));
    }

    @Override
    protected void extractData() {
        this.rows = reader.lines()
            .map(line -> line.split(","))
            .collect(Collectors.toList());
    }

    @Override
    protected void closeFile() {
        reader.close();
    }

    // Uses default parseData(), analyzeData(), sendReport()
}

// Usage
DataMiner pdfMiner = new PdfMiner();
pdfMiner.mine("report.pdf");  // Uses PDF-specific steps

DataMiner csvMiner = new CsvMiner();
csvMiner.mine("data.csv");    // Uses CSV-specific steps
```

### Java (Framework Example - JUnit Style)

```java
// Test framework template
public abstract class TestCase {

    // Template method
    public final void runTest() {
        setUp();
        try {
            runTestMethod();
            System.out.println("Test passed");
        } catch (AssertionError e) {
            System.out.println("Test failed: " + e.getMessage());
        } finally {
            tearDown();
        }
    }

    // Hooks with default behavior
    protected void setUp() {
        // Default: nothing
    }

    protected void tearDown() {
        // Default: nothing
    }

    // Abstract - subclass must implement
    protected abstract void runTestMethod();
}

// User's test
public class UserServiceTest extends TestCase {
    private UserService service;
    private Database db;

    @Override
    protected void setUp() {
        db = new TestDatabase();
        service = new UserService(db);
    }

    @Override
    protected void runTestMethod() {
        User user = service.findById(1);
        assert user != null : "User should exist";
    }

    @Override
    protected void tearDown() {
        db.close();
    }
}
```

### Go (Using Composition - Idiomatic)

Go doesn't have inheritance, so use composition with interfaces:

```go
// Define steps as interface
type DataProcessor interface {
    Open(path string) error
    Extract() ([]byte, error)
    Close() error
}

// "Template" as function that uses interface
func ProcessData(processor DataProcessor, path string) error {
    if err := processor.Open(path); err != nil {
        return fmt.Errorf("open: %w", err)
    }
    defer processor.Close()

    data, err := processor.Extract()
    if err != nil {
        return fmt.Errorf("extract: %w", err)
    }

    // Common processing steps
    parsed := parse(data)
    analyzed := analyze(parsed)
    report(analyzed)

    return nil
}

// Concrete implementation
type PDFProcessor struct {
    doc *pdf.Document
}

func (p *PDFProcessor) Open(path string) error {
    doc, err := pdf.Open(path)
    if err != nil {
        return err
    }
    p.doc = doc
    return nil
}

func (p *PDFProcessor) Extract() ([]byte, error) {
    var text []byte
    for _, page := range p.doc.Pages {
        text = append(text, page.Text()...)
    }
    return text, nil
}

func (p *PDFProcessor) Close() error {
    return p.doc.Close()
}

// Usage
ProcessData(&PDFProcessor{}, "report.pdf")
ProcessData(&CSVProcessor{}, "data.csv")
```

### Python

```python
from abc import ABC, abstractmethod

class GameAI(ABC):
    """Template for game AI behavior."""

    # Template method
    def turn(self) -> None:
        self.collect_resources()
        self.build_structures()
        self.build_units()
        self.attack()

    # Abstract methods - must implement
    @abstractmethod
    def build_structures(self) -> None:
        pass

    @abstractmethod
    def build_units(self) -> None:
        pass

    # Hooks with default behavior
    def collect_resources(self) -> None:
        for building in self.buildings:
            building.collect()

    def attack(self) -> None:
        # Default: attack closest enemy
        enemy = self.find_closest_enemy()
        if enemy:
            self.send_warriors(enemy)

class OrcsAI(GameAI):
    def build_structures(self) -> None:
        # Build barracks and farms
        if self.resources > 100:
            self.build("barracks")

    def build_units(self) -> None:
        # Orcs build warriors
        self.build("warrior")
        self.build("warrior")

class MonstersAI(GameAI):
    def build_structures(self) -> None:
        # Monsters don't build
        pass

    def build_units(self) -> None:
        # Monsters spawn from lairs
        pass

    def collect_resources(self) -> None:
        # Override: Monsters don't collect
        pass

# Usage
orc_ai = OrcsAI()
orc_ai.turn()  # Uses orc-specific building/units

monster_ai = MonstersAI()
monster_ai.turn()  # Uses monster-specific behavior
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Algorithm has fixed structure with variable steps
- [ ] **[MAJOR]** Multiple classes share similar algorithms
- [ ] **[MINOR]** Want to prevent algorithm structure changes

### Correct Implementation
- [ ] **[BLOCKER]** Template method is final (Java) or equivalent
- [ ] **[MAJOR]** Hooks have sensible defaults (not empty abstract)
- [ ] **[MAJOR]** Abstract methods are truly variable across subclasses
- [ ] **[MINOR]** Named clearly: abstract methods required, hooks optional

### Anti-Patterns to Flag
- [ ] **[MAJOR]** Too many abstract methods (consider Strategy)
- [ ] **[MAJOR]** Template method not final (can be overridden)
- [ ] **[MINOR]** Using inheritance when composition works

## Hollywood Principle

Template Method exemplifies the "Hollywood Principle": **Don't call us, we'll call you.**

The base class calls subclass methods, not the other way around:

```java
// Base class controls flow
public final void templateMethod() {
    step1();      // Calls subclass
    step2();      // Calls subclass
    step3();      // Calls subclass
}
```

## Template Method vs. Strategy

| Template Method | Strategy |
|-----------------|----------|
| Inheritance-based | Composition-based |
| Algorithm structure fixed | Entire algorithm varies |
| Compile-time | Runtime flexibility |
| Subclass defines steps | Injected object defines algorithm |

**Modern preference**: Strategy (composition) is often preferred over Template Method (inheritance).

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Strategy** | Alternative using composition |
| **Factory Method** | Often used in template methods |
| **Hook** | Template method defines hooks |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Framework](https://spring.io/) | `JdbcTemplate`, `RestTemplate`, `TransactionTemplate` |
| **Java** | [JUnit](https://junit.org/) | Test lifecycle (`@BeforeEach`, `@AfterEach`) follows template |
| **Java** | Standard Library | `AbstractList`, `AbstractSet` use template method |
| **Go** | Standard Library | `sort.Interface` - provide `Len`, `Less`, `Swap` |
| **Go** | [testify](https://github.com/stretchr/testify) | Test suite with `SetupTest`, `TearDownTest` hooks |
| **Python** | Standard Library | `unittest.TestCase` with `setUp`, `tearDown` |
| **Python** | [pytest](https://pytest.org/) | Fixtures follow template pattern conceptually |
| **JavaScript** | [Mocha](https://mochajs.org/) | `beforeEach`, `afterEach` hooks |
| **JavaScript** | [Jest](https://jestjs.io/) | Test lifecycle hooks |

**Note**: Template Method is baked into many frameworks. You typically don't need a library - you extend framework base classes or implement framework interfaces.

## References

- GoF p.325
- Refactoring Guru: https://refactoring.guru/design-patterns/template-method
