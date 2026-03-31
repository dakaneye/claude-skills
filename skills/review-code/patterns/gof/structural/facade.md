# Facade Pattern

> Provide a unified interface to a set of interfaces in a subsystem. Facade defines a higher-level interface that makes the subsystem easier to use.

## Intent

Simplify a complex subsystem by providing a single entry point. Hide the complexity of interacting with multiple components behind a simple interface.

## When to Use

- Provide a simple interface to a complex subsystem
- Decouple clients from subsystem components
- Layer your subsystems (facade at each level)
- Wrap a poorly designed API with a better one

## When NOT to Use

- Subsystem is already simple
- Clients need fine-grained control over subsystem
- You're just wrapping a single class (that's not a facade)

## Structure

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ uses
       ▼
┌─────────────┐
│   Facade    │
└──────┬──────┘
       │ coordinates
       ▼
┌─────────────────────────────────┐
│          Subsystem              │
│  ┌─────┐  ┌─────┐  ┌─────┐     │
│  │ A   │  │ B   │  │ C   │     │
│  └─────┘  └─────┘  └─────┘     │
└─────────────────────────────────┘
```

## Language Examples

### Java

```java
// Complex subsystem classes
class VideoFile {
    private String filename;
    public VideoFile(String filename) { this.filename = filename; }
    public String getCodec() { return "mp4"; }
}

class CodecFactory {
    public Codec extract(VideoFile file) {
        return new Codec(file.getCodec());
    }
}

class Codec {
    private String type;
    public Codec(String type) { this.type = type; }
}

class BitrateReader {
    public byte[] read(VideoFile file, Codec codec) {
        return new byte[0];
    }
}

class AudioMixer {
    public byte[] fix(byte[] data) {
        return data;
    }
}

// Facade - simple interface to complex subsystem
public class VideoConverter {
    public byte[] convert(String filename, String format) {
        VideoFile file = new VideoFile(filename);
        CodecFactory factory = new CodecFactory();
        Codec sourceCodec = factory.extract(file);

        Codec destinationCodec;
        if (format.equals("mp4")) {
            destinationCodec = new Codec("mp4");
        } else {
            destinationCodec = new Codec("ogg");
        }

        BitrateReader reader = new BitrateReader();
        byte[] buffer = reader.read(file, sourceCodec);

        AudioMixer mixer = new AudioMixer();
        byte[] result = mixer.fix(buffer);

        return result;
    }
}

// Usage - client doesn't know about subsystem
VideoConverter converter = new VideoConverter();
byte[] mp4 = converter.convert("birthday.ogg", "mp4");
```

```java
// Real-world example: Payment Processing Facade
public class PaymentFacade {
    private final InventoryService inventory;
    private final PaymentGateway gateway;
    private final ShippingService shipping;
    private final NotificationService notifications;
    private final OrderRepository orders;

    public PaymentFacade(
        InventoryService inventory,
        PaymentGateway gateway,
        ShippingService shipping,
        NotificationService notifications,
        OrderRepository orders
    ) {
        this.inventory = inventory;
        this.gateway = gateway;
        this.shipping = shipping;
        this.notifications = notifications;
        this.orders = orders;
    }

    /**
     * Process complete order - facade hides coordination complexity
     */
    public OrderResult processOrder(Order order) {
        // 1. Check inventory
        if (!inventory.checkAvailability(order.getItems())) {
            return OrderResult.outOfStock();
        }

        // 2. Reserve items
        String reservationId = inventory.reserve(order.getItems());

        try {
            // 3. Process payment
            PaymentResult payment = gateway.charge(
                order.getPaymentMethod(),
                order.getTotal()
            );

            if (!payment.isSuccessful()) {
                inventory.release(reservationId);
                return OrderResult.paymentFailed(payment.getError());
            }

            // 4. Create shipping label
            String trackingNumber = shipping.createLabel(order.getAddress());

            // 5. Save order
            Order savedOrder = orders.save(order
                .withPaymentId(payment.getTransactionId())
                .withTrackingNumber(trackingNumber)
            );

            // 6. Send confirmation
            notifications.sendOrderConfirmation(savedOrder);

            return OrderResult.success(savedOrder);

        } catch (Exception e) {
            inventory.release(reservationId);
            throw e;
        }
    }
}

// Client code is simple
PaymentFacade facade = new PaymentFacade(...);
OrderResult result = facade.processOrder(order);
```

### Go

```go
// Complex subsystem
type WalletChecker struct{}

func (w *WalletChecker) CheckBalance(accountID string) (float64, error) {
    // Check account balance
    return 1000.00, nil
}

type SecurityCodeVerifier struct{}

func (s *SecurityCodeVerifier) Verify(code string) bool {
    // Verify security code
    return code == "1234"
}

type WalletDebiter struct{}

func (w *WalletDebiter) Debit(accountID string, amount float64) error {
    // Debit from wallet
    return nil
}

type LedgerRecorder struct{}

func (l *LedgerRecorder) Record(accountID string, txType string, amount float64) error {
    // Record in ledger
    return nil
}

type NotificationSender struct{}

func (n *NotificationSender) Send(accountID, message string) error {
    // Send notification
    return nil
}

// Facade
type WalletFacade struct {
    checker  *WalletChecker
    verifier *SecurityCodeVerifier
    debiter  *WalletDebiter
    ledger   *LedgerRecorder
    notifier *NotificationSender
}

func NewWalletFacade() *WalletFacade {
    return &WalletFacade{
        checker:  &WalletChecker{},
        verifier: &SecurityCodeVerifier{},
        debiter:  &WalletDebiter{},
        ledger:   &LedgerRecorder{},
        notifier: &NotificationSender{},
    }
}

func (f *WalletFacade) Pay(accountID string, securityCode string, amount float64) error {
    // Facade coordinates all subsystem interactions
    if !f.verifier.Verify(securityCode) {
        return errors.New("invalid security code")
    }

    balance, err := f.checker.CheckBalance(accountID)
    if err != nil {
        return fmt.Errorf("check balance: %w", err)
    }

    if balance < amount {
        return errors.New("insufficient funds")
    }

    if err := f.debiter.Debit(accountID, amount); err != nil {
        return fmt.Errorf("debit: %w", err)
    }

    if err := f.ledger.Record(accountID, "DEBIT", amount); err != nil {
        // Log but don't fail - ledger is secondary
        log.Printf("ledger record failed: %v", err)
    }

    f.notifier.Send(accountID, fmt.Sprintf("Payment of $%.2f processed", amount))

    return nil
}

// Usage
wallet := NewWalletFacade()
err := wallet.Pay("user123", "1234", 100.00)
```

### Python

```python
# Complex subsystem
class CPU:
    def freeze(self) -> None:
        print("CPU: Freezing processor")

    def jump(self, address: int) -> None:
        print(f"CPU: Jumping to {address}")

    def execute(self) -> None:
        print("CPU: Executing")


class Memory:
    def load(self, address: int, data: bytes) -> None:
        print(f"Memory: Loading {len(data)} bytes at {address}")


class HardDrive:
    def read(self, sector: int, size: int) -> bytes:
        print(f"HardDrive: Reading {size} bytes from sector {sector}")
        return b"boot_data"


# Facade
class ComputerFacade:
    """Simplifies computer boot process."""

    BOOT_ADDRESS = 0x00
    BOOT_SECTOR = 0
    SECTOR_SIZE = 512

    def __init__(self):
        self._cpu = CPU()
        self._memory = Memory()
        self._hard_drive = HardDrive()

    def start(self) -> None:
        """Start the computer - facade hides boot complexity."""
        self._cpu.freeze()
        boot_data = self._hard_drive.read(self.BOOT_SECTOR, self.SECTOR_SIZE)
        self._memory.load(self.BOOT_ADDRESS, boot_data)
        self._cpu.jump(self.BOOT_ADDRESS)
        self._cpu.execute()


# Usage - client doesn't know about CPU, Memory, HardDrive
computer = ComputerFacade()
computer.start()  # Simple!
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Subsystem has multiple interacting components
- [ ] **[MAJOR]** Clients don't need fine-grained control
- [ ] **[MINOR]** Simplification is the goal (not access control)

### Correct Implementation
- [ ] **[MAJOR]** Facade doesn't add business logic (just coordinates)
- [ ] **[MAJOR]** Subsystem is still accessible if needed
- [ ] **[MINOR]** Facade methods represent meaningful operations

### Anti-Patterns to Flag
- [ ] **[MAJOR]** Facade with too many methods (becoming a God class)
- [ ] **[MAJOR]** Facade adding logic beyond coordination
- [ ] **[MINOR]** Single-class wrapper called "facade"

## Common Mistakes

### 1. Facade Becomes God Class
```java
// BAD: Facade does too much
class EverythingFacade {
    void createUser() { }
    void processPayment() { }
    void generateReport() { }
    void sendEmail() { }
    void updateInventory() { }
    // 50 more methods...
}

// GOOD: Focused facades for each subsystem
class UserFacade { void createUser() { } }
class PaymentFacade { void processPayment() { } }
class ReportFacade { void generateReport() { } }
```

### 2. Facade Hides Necessary Complexity
```java
// BAD: Facade prevents access to needed functionality
class OverlySimpleFacade {
    void process(Data data) {
        // Client can't control any aspect of processing
        // No way to customize, monitor, or debug
    }
}

// GOOD: Facade simplifies common case, allows access to subsystem
class BalancedFacade {
    // Simple method for common case
    void process(Data data) {
        process(data, ProcessOptions.defaults());
    }

    // Overload with options for control
    void process(Data data, ProcessOptions options) { }

    // Expose subsystem if needed
    SubsystemA getSubsystemA() { return subsystemA; }
}
```

### 3. Adding Business Logic
```java
// BAD: Facade contains business rules
class PaymentFacade {
    void processPayment(Payment payment) {
        // Business logic doesn't belong here!
        if (payment.getAmount() > 10000) {
            requireApproval(payment);
        }
        if (customer.isVIP()) {
            applyDiscount(payment);
        }
        // ...
    }
}

// GOOD: Facade only coordinates
class PaymentFacade {
    void processPayment(Payment payment) {
        validator.validate(payment);       // Subsystem handles rules
        processor.process(payment);        // Subsystem handles processing
        notifier.sendConfirmation(payment);// Subsystem handles notification
    }
}
```

## Facade vs. Other Patterns

| Pattern | Intent | Difference |
|---------|--------|------------|
| **Adapter** | Convert interface | Facade simplifies; Adapter converts |
| **Mediator** | Coordinate peers | Mediator for peer communication; Facade for client simplification |
| **Singleton** | Single instance | Often combined (singleton facade) |

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Abstract Factory** | Can create subsystem objects for facade |
| **Mediator** | Similar but mediates between peers |
| **Singleton** | Facade is often a singleton |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [SLF4J](https://www.slf4j.org/) | Facade over various logging frameworks (log4j, logback) |
| **Java** | [Apache Commons](https://commons.apache.org/) | Facades for IO, collections, lang utilities |
| **Java** | [Spring Framework](https://spring.io/) | `JdbcTemplate`, `RestTemplate` are facades over complex APIs |
| **Go** | Standard Library | `database/sql` is a facade over SQL drivers |
| **Go** | [afero](https://github.com/spf13/afero) | Filesystem facade for testing |
| **Python** | [requests](https://requests.readthedocs.io/) | Facade over `urllib` complexity |
| **Python** | [boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) | High-level AWS resource facades |
| **JavaScript** | [axios](https://axios-http.com/) | Facade over `XMLHttpRequest` and `fetch` |
| **JavaScript** | [jQuery](https://jquery.com/) | (Historical) Facade over DOM APIs |

**Note**: Facade is a design approach more than something requiring a library. Many popular libraries ARE facades over lower-level APIs.

## References

- GoF p.185
- Refactoring Guru: https://refactoring.guru/design-patterns/facade
