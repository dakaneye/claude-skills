# Hexagonal Architecture (Ports and Adapters)

> Allow an application to equally be driven by users, programs, automated test, or batch scripts, and to be developed and tested in isolation from its eventual run-time devices and databases.

**Source**: Alistair Cockburn (2005)

## Intent

Isolate the application core from external concerns by defining explicit ports (interfaces) through which the outside world interacts with the application, and adapters that convert between external protocols and the port's format.

## Key Concepts

- **Hexagon**: The application core containing business logic
- **Ports**: Interfaces defined by the application (not by external systems)
- **Driving Ports**: How the outside drives the application (API, UI, CLI)
- **Driven Ports**: How the application drives the outside (database, external services)
- **Adapters**: Implementations that connect ports to external systems

## Structure

```
                   ┌─────────────────────────────────────┐
                   │         Driving Adapters            │
                   │   (REST, GraphQL, CLI, Tests)       │
                   └──────────────┬──────────────────────┘
                                  │
                   ┌──────────────▼──────────────────────┐
                   │         Driving Ports               │
                   │   (Use Case Interfaces)             │
                   └──────────────┬──────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
        │    ┌────────────────────▼────────────────────┐   │
        │    │                                         │   │
        │    │           APPLICATION CORE              │   │
        │    │                                         │   │
        │    │    ┌─────────────────────────────┐     │   │
        │    │    │      Domain Model           │     │   │
        │    │    │   (Entities, Value Objects) │     │   │
        │    │    └─────────────────────────────┘     │   │
        │    │                                         │   │
        │    │    ┌─────────────────────────────┐     │   │
        │    │    │      Application Services   │     │   │
        │    │    │      (Use Cases)            │     │   │
        │    │    └─────────────────────────────┘     │   │
        │    │                                         │   │
        │    └────────────────────┬────────────────────┘   │
        │                         │                         │
        └─────────────────────────┼─────────────────────────┘
                                  │
                   ┌──────────────▼──────────────────────┐
                   │         Driven Ports                │
                   │   (Repository, Gateway interfaces)  │
                   └──────────────┬──────────────────────┘
                                  │
                   ┌──────────────▼──────────────────────┐
                   │         Driven Adapters             │
                   │   (PostgreSQL, S3, Stripe, Email)   │
                   └─────────────────────────────────────┘
```

## When to Use

- Need to swap infrastructure without changing business logic
- Multiple entry points (API, CLI, event consumers)
- Test business logic in isolation
- Long-lived application with evolving requirements
- Microservices with clear boundaries

## When NOT to Use

- Simple CRUD applications
- Prototypes or MVPs
- When team lacks experience with the pattern
- Time-constrained projects where simplicity matters more

## Language Examples

### Java

```java
// ===== DOMAIN (Application Core) =====
package com.company.domain;

// Entity
public class Account {
    private final AccountId id;
    private Money balance;
    private AccountStatus status;

    public void deposit(Money amount) {
        if (status != AccountStatus.ACTIVE) {
            throw new AccountNotActiveException(id);
        }
        this.balance = balance.add(amount);
    }

    public void withdraw(Money amount) {
        if (status != AccountStatus.ACTIVE) {
            throw new AccountNotActiveException(id);
        }
        if (balance.lessThan(amount)) {
            throw new InsufficientFundsException(id, amount, balance);
        }
        this.balance = balance.subtract(amount);
    }
}

// ===== DRIVING PORT (Inbound) =====
package com.company.application.port.in;

// What the application offers to the outside world
public interface TransferMoneyUseCase {
    void transfer(TransferMoneyCommand command);
}

// Command object with validation
public record TransferMoneyCommand(
    AccountId sourceAccountId,
    AccountId targetAccountId,
    Money amount
) {
    public TransferMoneyCommand {
        Objects.requireNonNull(sourceAccountId, "Source account required");
        Objects.requireNonNull(targetAccountId, "Target account required");
        Objects.requireNonNull(amount, "Amount required");
        if (amount.isNegativeOrZero()) {
            throw new IllegalArgumentException("Amount must be positive");
        }
    }
}

// ===== DRIVEN PORT (Outbound) =====
package com.company.application.port.out;

// What the application needs from the outside world
public interface LoadAccountPort {
    Account loadAccount(AccountId accountId);
}

public interface UpdateAccountStatePort {
    void updateAccount(Account account);
}

public interface AccountLockPort {
    void lockAccount(AccountId accountId);
    void releaseAccount(AccountId accountId);
}

// ===== APPLICATION SERVICE (Implements Driving Port) =====
package com.company.application.service;

public class TransferMoneyService implements TransferMoneyUseCase {
    private final LoadAccountPort loadAccountPort;
    private final UpdateAccountStatePort updateAccountStatePort;
    private final AccountLockPort accountLockPort;

    public TransferMoneyService(
            LoadAccountPort loadAccountPort,
            UpdateAccountStatePort updateAccountStatePort,
            AccountLockPort accountLockPort) {
        this.loadAccountPort = loadAccountPort;
        this.updateAccountStatePort = updateAccountStatePort;
        this.accountLockPort = accountLockPort;
    }

    @Override
    public void transfer(TransferMoneyCommand command) {
        // Lock accounts to prevent concurrent modification
        accountLockPort.lockAccount(command.sourceAccountId());
        accountLockPort.lockAccount(command.targetAccountId());

        try {
            Account source = loadAccountPort.loadAccount(command.sourceAccountId());
            Account target = loadAccountPort.loadAccount(command.targetAccountId());

            // Domain logic
            source.withdraw(command.amount());
            target.deposit(command.amount());

            // Persist changes
            updateAccountStatePort.updateAccount(source);
            updateAccountStatePort.updateAccount(target);
        } finally {
            accountLockPort.releaseAccount(command.sourceAccountId());
            accountLockPort.releaseAccount(command.targetAccountId());
        }
    }
}

// ===== DRIVING ADAPTER (REST Controller) =====
package com.company.adapter.in.web;

@RestController
@RequestMapping("/accounts")
public class TransferMoneyController {
    private final TransferMoneyUseCase transferMoneyUseCase;

    public TransferMoneyController(TransferMoneyUseCase transferMoneyUseCase) {
        this.transferMoneyUseCase = transferMoneyUseCase;
    }

    @PostMapping("/transfer")
    public ResponseEntity<Void> transfer(@RequestBody TransferRequest request) {
        // Adapt HTTP request to use case command
        TransferMoneyCommand command = new TransferMoneyCommand(
            new AccountId(request.getSourceAccountId()),
            new AccountId(request.getTargetAccountId()),
            Money.of(request.getAmount(), request.getCurrency())
        );

        transferMoneyUseCase.transfer(command);

        return ResponseEntity.ok().build();
    }
}

// ===== DRIVEN ADAPTER (Database) =====
package com.company.adapter.out.persistence;

@Repository
public class AccountPersistenceAdapter
        implements LoadAccountPort, UpdateAccountStatePort {

    private final AccountJpaRepository repository;
    private final AccountMapper mapper;

    @Override
    public Account loadAccount(AccountId accountId) {
        AccountJpaEntity entity = repository.findById(accountId.getValue())
            .orElseThrow(() -> new AccountNotFoundException(accountId));
        return mapper.toDomain(entity);
    }

    @Override
    public void updateAccount(Account account) {
        AccountJpaEntity entity = mapper.toEntity(account);
        repository.save(entity);
    }
}

// Separate adapter for locking
@Component
public class AccountLockAdapter implements AccountLockPort {
    private final Map<AccountId, ReentrantLock> locks = new ConcurrentHashMap<>();

    @Override
    public void lockAccount(AccountId accountId) {
        locks.computeIfAbsent(accountId, id -> new ReentrantLock()).lock();
    }

    @Override
    public void releaseAccount(AccountId accountId) {
        Lock lock = locks.get(accountId);
        if (lock != null) {
            lock.unlock();
        }
    }
}
```

### Go

```go
// ===== DOMAIN =====
package domain

type Account struct {
    ID      AccountID
    Balance Money
    Status  AccountStatus
}

func (a *Account) Withdraw(amount Money) error {
    if a.Status != AccountStatusActive {
        return ErrAccountNotActive
    }
    if a.Balance.LessThan(amount) {
        return ErrInsufficientFunds
    }
    a.Balance = a.Balance.Subtract(amount)
    return nil
}

func (a *Account) Deposit(amount Money) error {
    if a.Status != AccountStatusActive {
        return ErrAccountNotActive
    }
    a.Balance = a.Balance.Add(amount)
    return nil
}

// ===== DRIVING PORT =====
package port

type TransferMoneyUseCase interface {
    Transfer(ctx context.Context, cmd TransferMoneyCommand) error
}

type TransferMoneyCommand struct {
    SourceAccountID domain.AccountID
    TargetAccountID domain.AccountID
    Amount          domain.Money
}

// ===== DRIVEN PORTS =====
package port

type LoadAccountPort interface {
    LoadAccount(ctx context.Context, id domain.AccountID) (*domain.Account, error)
}

type UpdateAccountPort interface {
    UpdateAccount(ctx context.Context, account *domain.Account) error
}

type AccountLockPort interface {
    Lock(ctx context.Context, id domain.AccountID) error
    Unlock(ctx context.Context, id domain.AccountID) error
}

// ===== APPLICATION SERVICE =====
package application

type TransferMoneyService struct {
    loadAccount   port.LoadAccountPort
    updateAccount port.UpdateAccountPort
    lockAccount   port.AccountLockPort
}

func NewTransferMoneyService(
    load port.LoadAccountPort,
    update port.UpdateAccountPort,
    lock port.AccountLockPort,
) *TransferMoneyService {
    return &TransferMoneyService{
        loadAccount:   load,
        updateAccount: update,
        lockAccount:   lock,
    }
}

func (s *TransferMoneyService) Transfer(ctx context.Context, cmd port.TransferMoneyCommand) error {
    // Lock accounts
    if err := s.lockAccount.Lock(ctx, cmd.SourceAccountID); err != nil {
        return fmt.Errorf("lock source: %w", err)
    }
    defer s.lockAccount.Unlock(ctx, cmd.SourceAccountID)

    if err := s.lockAccount.Lock(ctx, cmd.TargetAccountID); err != nil {
        return fmt.Errorf("lock target: %w", err)
    }
    defer s.lockAccount.Unlock(ctx, cmd.TargetAccountID)

    // Load accounts
    source, err := s.loadAccount.LoadAccount(ctx, cmd.SourceAccountID)
    if err != nil {
        return fmt.Errorf("load source: %w", err)
    }

    target, err := s.loadAccount.LoadAccount(ctx, cmd.TargetAccountID)
    if err != nil {
        return fmt.Errorf("load target: %w", err)
    }

    // Domain logic
    if err := source.Withdraw(cmd.Amount); err != nil {
        return fmt.Errorf("withdraw: %w", err)
    }

    if err := target.Deposit(cmd.Amount); err != nil {
        return fmt.Errorf("deposit: %w", err)
    }

    // Persist
    if err := s.updateAccount.UpdateAccount(ctx, source); err != nil {
        return fmt.Errorf("update source: %w", err)
    }

    if err := s.updateAccount.UpdateAccount(ctx, target); err != nil {
        return fmt.Errorf("update target: %w", err)
    }

    return nil
}

// ===== DRIVING ADAPTER =====
package web

type TransferHandler struct {
    useCase port.TransferMoneyUseCase
}

func (h *TransferHandler) HandleTransfer(w http.ResponseWriter, r *http.Request) {
    var req TransferRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    cmd := port.TransferMoneyCommand{
        SourceAccountID: domain.AccountID(req.SourceAccountID),
        TargetAccountID: domain.AccountID(req.TargetAccountID),
        Amount:          domain.NewMoney(req.Amount, req.Currency),
    }

    if err := h.useCase.Transfer(r.Context(), cmd); err != nil {
        // Map domain errors to HTTP responses
        http.Error(w, err.Error(), mapErrorToStatus(err))
        return
    }

    w.WriteHeader(http.StatusOK)
}

// ===== DRIVEN ADAPTER =====
package postgres

type AccountRepository struct {
    db *sql.DB
}

func (r *AccountRepository) LoadAccount(ctx context.Context, id domain.AccountID) (*domain.Account, error) {
    row := r.db.QueryRowContext(ctx,
        "SELECT id, balance, status FROM accounts WHERE id = $1",
        id,
    )

    var account domain.Account
    if err := row.Scan(&account.ID, &account.Balance, &account.Status); err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, domain.ErrAccountNotFound
        }
        return nil, fmt.Errorf("scan account: %w", err)
    }

    return &account, nil
}
```

## Package Structure

```
src/
├── domain/                    # Domain model (entities, value objects)
│   ├── account.go
│   └── money.go
│
├── application/
│   ├── port/
│   │   ├── in/               # Driving ports (use case interfaces)
│   │   │   └── transfer_money.go
│   │   └── out/              # Driven ports (repository, gateway interfaces)
│   │       ├── load_account.go
│   │       └── update_account.go
│   └── service/              # Use case implementations
│       └── transfer_money_service.go
│
└── adapter/
    ├── in/                   # Driving adapters
    │   ├── web/             # REST controllers
    │   └── cli/             # CLI commands
    └── out/                  # Driven adapters
        ├── persistence/     # Database implementations
        └── external/        # External service clients
```

## Review Checklist

### Port Design
- [ ] **[BLOCKER]** Ports are interfaces defined by the application, not by adapters
- [ ] **[BLOCKER]** Driving ports represent use cases, not HTTP endpoints
- [ ] **[MAJOR]** Driven ports are fine-grained (not one mega-repository)
- [ ] **[MINOR]** Port names reflect application concepts, not infrastructure

### Adapter Design
- [ ] **[BLOCKER]** Adapters only do translation, no business logic
- [ ] **[MAJOR]** Adapters depend on ports, not the reverse
- [ ] **[MAJOR]** One adapter per external system/protocol
- [ ] **[MINOR]** Adapters are easily replaceable

### Dependency Direction
- [ ] **[BLOCKER]** Application core has no dependencies on adapters
- [ ] **[BLOCKER]** Domain has no framework imports
- [ ] **[MAJOR]** All external dependencies point inward

## Common Mistakes

### 1. Adapter Leaks into Domain
```java
// BAD: Domain knows about HTTP
public class Account {
    public ResponseEntity<Money> getBalance() { ... }
}

// GOOD: Pure domain
public class Account {
    public Money getBalance() { ... }
}
```

### 2. Single "Kitchen Sink" Port
```java
// BAD: One port does everything
public interface AccountPort {
    Account load(AccountId id);
    void save(Account account);
    void delete(AccountId id);
    List<Account> findByCustomer(CustomerId id);
    void lock(AccountId id);
    void unlock(AccountId id);
    // ... 20 more methods
}

// GOOD: Focused ports
public interface LoadAccountPort {
    Account load(AccountId id);
}

public interface UpdateAccountPort {
    void save(Account account);
}

public interface AccountLockPort {
    void lock(AccountId id);
    void unlock(AccountId id);
}
```

### 3. Business Logic in Adapter
```java
// BAD: Validation in adapter
@PostMapping("/transfer")
public ResponseEntity<?> transfer(@RequestBody TransferRequest request) {
    // Business rule in adapter!
    if (request.getAmount() > 10000) {
        return ResponseEntity.badRequest().body("Amount exceeds limit");
    }
    ...
}

// GOOD: Business logic in domain/application
public void transfer(TransferMoneyCommand command) {
    if (command.amount().exceeds(TRANSFER_LIMIT)) {
        throw new TransferLimitExceededException();
    }
    ...
}
```

## Testing Strategy

```java
// Unit test application service with mock ports
class TransferMoneyServiceTest {

    private LoadAccountPort loadAccountPort = mock(LoadAccountPort.class);
    private UpdateAccountStatePort updateAccountPort = mock(UpdateAccountStatePort.class);
    private AccountLockPort lockPort = mock(AccountLockPort.class);

    private TransferMoneyService service = new TransferMoneyService(
        loadAccountPort, updateAccountPort, lockPort
    );

    @Test
    void shouldTransferMoney() {
        // Given
        Account source = new Account(SOURCE_ID, Money.of(100));
        Account target = new Account(TARGET_ID, Money.of(50));

        when(loadAccountPort.loadAccount(SOURCE_ID)).thenReturn(source);
        when(loadAccountPort.loadAccount(TARGET_ID)).thenReturn(target);

        // When
        service.transfer(new TransferMoneyCommand(SOURCE_ID, TARGET_ID, Money.of(30)));

        // Then
        assertThat(source.getBalance()).isEqualTo(Money.of(70));
        assertThat(target.getBalance()).isEqualTo(Money.of(80));
        verify(updateAccountPort).updateAccount(source);
        verify(updateAccountPort).updateAccount(target);
    }
}
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Clean Architecture** | Same concepts, different terminology |
| **Repository** | Common driven port pattern |
| **Adapter (GoF)** | The adapters implement this pattern |
| **Dependency Injection** | Required for wiring |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [jMolecules](https://github.com/xmolecules/jmolecules) | Annotations for ports (`@PrimaryPort`, `@SecondaryPort`) and adapters |
| **Java** | [ArchUnit](https://www.archunit.org/) | Architecture testing to enforce port/adapter boundaries |
| **Java** | [Spring Modulith](https://spring.io/projects/spring-modulith) | Logical module boundaries with architecture verification |
| **Java** | [Buckpal](https://github.com/thombergs/buckpal) | Reference implementation from "Get Your Hands Dirty on Clean Architecture" |
| **Go** | Standard Library | Interfaces naturally support ports pattern |
| **Go** | [Wire](https://github.com/google/wire) | Compile-time DI for wiring adapters to ports |
| **Python** | [dependency-injector](https://python-dependency-injector.ets-labs.org/) | DI container for adapter injection |
| **Python** | [punq](https://github.com/bobthemighty/punq) | Simple DI container for ports and adapters |
| **JavaScript** | [InversifyJS](https://inversify.io/) | IoC container for TypeScript port/adapter wiring |
| **JavaScript** | [tsyringe](https://github.com/microsoft/tsyringe) | Lightweight DI container from Microsoft |

**Note**: Hexagonal Architecture is primarily a structural pattern enforced through code organization and dependency direction. Libraries help with dependency injection, architecture verification, and documentation but the pattern itself is implemented through interface definitions and package structure.

## References

- Alistair Cockburn, "Hexagonal Architecture" (2005)
- https://alistair.cockburn.us/hexagonal-architecture/
- Tom Hombergs, "Get Your Hands Dirty on Clean Architecture" (2019)
