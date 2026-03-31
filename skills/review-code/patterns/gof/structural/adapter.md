# Adapter Pattern

> Convert the interface of a class into another interface clients expect. Adapter lets classes work together that couldn't otherwise because of incompatible interfaces.

## Intent

Allow incompatible interfaces to work together by wrapping one interface with another that clients expect.

## When to Use

- Integrating legacy code with new systems
- Using third-party libraries with different interfaces
- Creating reusable classes that cooperate with unrelated classes
- Adapting an existing class to a new interface without modifying it

## When NOT to Use

- You control both interfaces (just make them compatible)
- The interfaces are already similar (might be overengineering)
- Performance is critical (adds a layer of indirection)

## Structure

### Object Adapter (Composition - Preferred)
```
┌─────────────┐       ┌─────────────┐
│   Client    │──────▶│   Target    │ (interface)
└─────────────┘       └──────┬──────┘
                             │
                      ┌──────┴──────┐
                      │   Adapter   │
                      └──────┬──────┘
                             │ has-a
                      ┌──────┴──────┐
                      │   Adaptee   │ (legacy/3rd party)
                      └─────────────┘
```

### Class Adapter (Inheritance - Less Flexible)
```
┌─────────────┐       ┌─────────────┐
│   Client    │──────▶│   Target    │ (interface)
└─────────────┘       └──────┬──────┘
                             │
                      ┌──────┴──────┐
                      │   Adapter   │
                      └──────┬──────┘
                             │ extends
                      ┌──────┴──────┐
                      │   Adaptee   │
                      └─────────────┘
```

## Language Examples

### Java

```java
// Target interface - what the client expects
public interface MediaPlayer {
    void play(String filename);
}

// Adaptee - legacy/third-party with incompatible interface
public class VlcPlayer {
    public void playVlc(String filename) {
        System.out.println("Playing vlc: " + filename);
    }
}

public class Mp4Player {
    public void playMp4(String filename) {
        System.out.println("Playing mp4: " + filename);
    }
}

// Adapter - converts adaptee interface to target interface
public class MediaAdapter implements MediaPlayer {
    private final VlcPlayer vlcPlayer;
    private final Mp4Player mp4Player;

    public MediaAdapter() {
        this.vlcPlayer = new VlcPlayer();
        this.mp4Player = new Mp4Player();
    }

    @Override
    public void play(String filename) {
        if (filename.endsWith(".vlc")) {
            vlcPlayer.playVlc(filename);
        } else if (filename.endsWith(".mp4")) {
            mp4Player.playMp4(filename);
        } else {
            throw new UnsupportedOperationException("Format not supported: " + filename);
        }
    }
}

// Usage
MediaPlayer player = new MediaAdapter();
player.play("movie.mp4");  // Works with new interface
```

```java
// Real-world example: Adapting legacy payment gateway
// Target interface (your system)
public interface PaymentProcessor {
    PaymentResult process(PaymentRequest request);
}

// Adaptee (legacy third-party SDK)
public class LegacyPaymentGateway {
    public int makePayment(String cardNumber, String expiry, int amountCents) {
        // Returns: 0=success, 1=declined, 2=error
        return 0;
    }
}

// Adapter
public class LegacyPaymentAdapter implements PaymentProcessor {
    private final LegacyPaymentGateway gateway;

    public LegacyPaymentAdapter(LegacyPaymentGateway gateway) {
        this.gateway = gateway;
    }

    @Override
    public PaymentResult process(PaymentRequest request) {
        // Translate request format
        int amountCents = request.getAmount().multiply(BigDecimal.valueOf(100)).intValue();

        // Call legacy system
        int result = gateway.makePayment(
            request.getCardNumber(),
            request.getExpiry(),
            amountCents
        );

        // Translate response
        return switch (result) {
            case 0 -> PaymentResult.success();
            case 1 -> PaymentResult.declined("Card declined");
            default -> PaymentResult.error("Payment processing error");
        };
    }
}
```

### Go

```go
// Target interface
type Notifier interface {
    Send(userID string, message string) error
}

// Adaptee - third-party Slack SDK with different interface
type SlackClient struct {
    webhookURL string
}

func (s *SlackClient) PostMessage(channel, text string, opts ...Option) error {
    // Slack-specific implementation
    return nil
}

// Adapter
type SlackAdapter struct {
    client      *SlackClient
    userToChannel map[string]string  // Map user IDs to Slack channels
}

func NewSlackAdapter(webhookURL string, userMappings map[string]string) *SlackAdapter {
    return &SlackAdapter{
        client:        &SlackClient{webhookURL: webhookURL},
        userToChannel: userMappings,
    }
}

func (a *SlackAdapter) Send(userID string, message string) error {
    channel, ok := a.userToChannel[userID]
    if !ok {
        return fmt.Errorf("no Slack channel for user: %s", userID)
    }
    return a.client.PostMessage(channel, message)
}

// Usage - client uses Notifier interface
func NotifyUser(notifier Notifier, userID, message string) error {
    return notifier.Send(userID, message)
}

// Can use Slack, Email, SMS - all implement Notifier
slack := NewSlackAdapter(webhookURL, mappings)
NotifyUser(slack, "user123", "Hello!")
```

### Python

```python
from abc import ABC, abstractmethod

# Target interface
class DataSource(ABC):
    @abstractmethod
    def read_data(self) -> list[dict]:
        pass

# Adaptee - legacy XML parser with different interface
class LegacyXMLParser:
    def __init__(self, file_path: str):
        self.file_path = file_path

    def parse_xml(self) -> "XMLDocument":
        # Returns proprietary XML document structure
        pass

    def get_elements(self, doc: "XMLDocument", tag: str) -> list:
        # Returns XML elements
        pass

# Adapter
class XMLDataSourceAdapter(DataSource):
    def __init__(self, xml_parser: LegacyXMLParser, tag: str):
        self._parser = xml_parser
        self._tag = tag

    def read_data(self) -> list[dict]:
        doc = self._parser.parse_xml()
        elements = self._parser.get_elements(doc, self._tag)

        # Convert XML elements to dictionaries
        return [self._element_to_dict(elem) for elem in elements]

    def _element_to_dict(self, element) -> dict:
        # Convert proprietary XML element to dict
        pass

# Usage
def process_data(source: DataSource):
    for record in source.read_data():
        # Process uniform dict format
        pass

# Can use JSON, CSV, XML - all implement DataSource
xml_source = XMLDataSourceAdapter(LegacyXMLParser("data.xml"), "record")
process_data(xml_source)
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Adapting code you don't control (third-party, legacy)
- [ ] **[MAJOR]** Interface incompatibility is the problem (not missing functionality)
- [ ] **[MINOR]** Preserving existing client code while integrating new systems

### Correct Implementation
- [ ] **[BLOCKER]** Adapter implements target interface completely
- [ ] **[MAJOR]** Uses composition (object adapter) over inheritance
- [ ] **[MAJOR]** Translation logic is complete and correct
- [ ] **[MINOR]** Adapter is stateless if possible

### Anti-Patterns to Flag
- [ ] **[MAJOR]** Adapting interfaces you control (just change them)
- [ ] **[MAJOR]** Adding functionality beyond translation (that's Decorator)
- [ ] **[MINOR]** Class adapter when object adapter would work

## Common Mistakes

### 1. Adapter with Business Logic
```java
// BAD: Adapter does more than translation
public class PaymentAdapter implements PaymentProcessor {
    @Override
    public PaymentResult process(PaymentRequest request) {
        // Validation should NOT be here
        if (request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Invalid amount");
        }

        // Discount logic should NOT be here
        BigDecimal finalAmount = applyDiscounts(request);

        return gateway.charge(finalAmount);
    }
}

// GOOD: Adapter only translates
public class PaymentAdapter implements PaymentProcessor {
    @Override
    public PaymentResult process(PaymentRequest request) {
        // Only translate between interfaces
        LegacyRequest legacyRequest = toLegacyFormat(request);
        LegacyResponse response = gateway.charge(legacyRequest);
        return toPaymentResult(response);
    }
}
```

### 2. Incomplete Adaptation
```java
// BAD: Not all target methods implemented properly
public class IncompleteAdapter implements FullInterface {
    @Override
    public void methodA() { adaptee.doA(); }  // OK

    @Override
    public void methodB() {
        throw new UnsupportedOperationException();  // Violates contract!
    }
}

// GOOD: Full implementation or don't implement interface
// If can't implement fully, use a different pattern or interface
```

### 3. Adapting When Not Needed
```java
// BAD: Creating adapter for interface you control
// MyService and MyClient are both in your codebase
class MyServiceAdapter implements MyClientInterface {
    // Just change MyService to implement MyClientInterface directly!
}

// GOOD: Only adapt external/legacy code you can't modify
class ThirdPartyAdapter implements MyClientInterface {
    private final ThirdPartyLibrary lib;  // Can't modify this
    // Adaptation is justified
}
```

## Two-Way Adapter

Sometimes you need to adapt in both directions:

```java
// Two-way adapter for bidirectional integration
public class TwoWayAdapter implements NewInterface, LegacyInterface {
    private NewSystem newSystem;
    private LegacySystem legacySystem;

    // Adapt new to legacy
    @Override
    public void legacyMethod(LegacyData data) {
        NewData converted = convertToNew(data);
        newSystem.newMethod(converted);
    }

    // Adapt legacy to new
    @Override
    public void newMethod(NewData data) {
        LegacyData converted = convertToLegacy(data);
        legacySystem.legacyMethod(converted);
    }
}
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Bridge** | Separates abstraction from implementation; Adapter makes things work together |
| **Decorator** | Adds behavior; Adapter changes interface |
| **Facade** | Simplifies interface; Adapter converts interface |
| **Proxy** | Same interface; Adapter changes interface |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [MapStruct](https://mapstruct.org/) | Compile-time object mapping/adaptation |
| **Java** | [ModelMapper](http://modelmapper.org/) | Runtime object mapping between types |
| **Java** | Standard Library | `Arrays.asList()`, `InputStreamReader` are adapters |
| **Go** | Standard Library | Interfaces are implicit - adapters are just implementations |
| **Go** | [gRPC](https://grpc.io/) | Generated code adapts protobuf to Go types |
| **Python** | Standard Library | `io.TextIOWrapper` adapts binary streams to text |
| **Python** | [marshmallow](https://marshmallow.readthedocs.io/) | Schema-based serialization/adaptation |
| **JavaScript** | [class-transformer](https://github.com/typestack/class-transformer) | Transform plain objects to class instances |
| **.NET** | [AutoMapper](https://automapper.org/) | Convention-based object mapping |

**Note**: Adapter is a structural pattern you implement per integration. Mapping libraries help with data transformation aspects but don't replace hand-written adapters for behavior.

## References

- GoF p.139
- Refactoring Guru: https://refactoring.guru/design-patterns/adapter
