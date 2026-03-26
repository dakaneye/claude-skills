# Repository Pattern

> Mediates between the domain and data mapping layers using a collection-like interface for accessing domain objects.

**Source**: Martin Fowler, "Patterns of Enterprise Application Architecture" (2002)

## Intent

Encapsulate the logic required to access data sources. Centralize common data access functionality, providing better maintainability and decoupling the infrastructure from the domain layer.

## When to Use

- Need to separate domain logic from data access
- Want to unit test domain logic without database
- Multiple data sources or complex queries
- Domain model is the focus (not CRUD operations)

## When NOT to Use

- Simple CRUD applications (Active Record may suffice)
- Single data source with straightforward queries
- Prototyping or throwaway code
- ORM already provides sufficient abstraction

## Structure

```
┌─────────────────┐     ┌─────────────────┐
│   Domain Layer  │────▶│   Repository    │ (interface)
│                 │     │   Interface     │
└─────────────────┘     └────────┬────────┘
                                 │
                        ┌────────┴────────┐
                        │                 │
                 ┌──────┴──────┐  ┌───────┴─────┐
                 │  PostgresRepo│  │ InMemoryRepo│
                 └─────────────┘  └─────────────┘
                        │
                        ▼
               ┌─────────────────┐
               │    Database     │
               └─────────────────┘
```

## Language Examples

### Java

```java
// Domain entity
public class User {
    private UserId id;
    private Email email;
    private String name;
    private Instant createdAt;

    // Domain behavior
    public void changeName(String newName) {
        if (newName == null || newName.isBlank()) {
            throw new IllegalArgumentException("Name cannot be blank");
        }
        this.name = newName;
    }
}

// Repository interface (domain layer)
public interface UserRepository {
    Optional<User> findById(UserId id);
    Optional<User> findByEmail(Email email);
    List<User> findAll();
    List<User> findByNameContaining(String namePart);

    void save(User user);
    void delete(UserId id);

    boolean existsByEmail(Email email);
}

// Implementation (infrastructure layer)
public class JpaUserRepository implements UserRepository {
    private final EntityManager em;

    public JpaUserRepository(EntityManager em) {
        this.em = em;
    }

    @Override
    public Optional<User> findById(UserId id) {
        return Optional.ofNullable(
            em.find(User.class, id.getValue())
        );
    }

    @Override
    public Optional<User> findByEmail(Email email) {
        return em.createQuery(
                "SELECT u FROM User u WHERE u.email = :email", User.class)
            .setParameter("email", email)
            .getResultStream()
            .findFirst();
    }

    @Override
    public void save(User user) {
        if (user.getId() == null) {
            em.persist(user);
        } else {
            em.merge(user);
        }
    }

    @Override
    public void delete(UserId id) {
        findById(id).ifPresent(em::remove);
    }
}

// In-memory implementation for testing
public class InMemoryUserRepository implements UserRepository {
    private final Map<UserId, User> store = new ConcurrentHashMap<>();

    @Override
    public Optional<User> findById(UserId id) {
        return Optional.ofNullable(store.get(id));
    }

    @Override
    public void save(User user) {
        store.put(user.getId(), user);
    }

    // ... other methods
}

// Usage in domain service
public class UserService {
    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public void changeUserName(UserId userId, String newName) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new UserNotFoundException(userId));

        user.changeName(newName);

        userRepository.save(user);
    }
}
```

### Go

```go
// Domain entity
type User struct {
    ID        UserID
    Email     string
    Name      string
    CreatedAt time.Time
}

// Repository interface (domain layer)
type UserRepository interface {
    FindByID(ctx context.Context, id UserID) (*User, error)
    FindByEmail(ctx context.Context, email string) (*User, error)
    FindAll(ctx context.Context) ([]*User, error)
    Save(ctx context.Context, user *User) error
    Delete(ctx context.Context, id UserID) error
}

// PostgreSQL implementation
type PostgresUserRepository struct {
    db *sql.DB
}

func NewPostgresUserRepository(db *sql.DB) *PostgresUserRepository {
    return &PostgresUserRepository{db: db}
}

func (r *PostgresUserRepository) FindByID(ctx context.Context, id UserID) (*User, error) {
    row := r.db.QueryRowContext(ctx,
        "SELECT id, email, name, created_at FROM users WHERE id = $1",
        id,
    )

    user := &User{}
    err := row.Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
    if err == sql.ErrNoRows {
        return nil, ErrUserNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("scan user: %w", err)
    }

    return user, nil
}

func (r *PostgresUserRepository) Save(ctx context.Context, user *User) error {
    _, err := r.db.ExecContext(ctx, `
        INSERT INTO users (id, email, name, created_at)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (id) DO UPDATE
        SET email = $2, name = $3
    `, user.ID, user.Email, user.Name, user.CreatedAt)

    if err != nil {
        return fmt.Errorf("save user: %w", err)
    }
    return nil
}

// In-memory implementation for testing
type InMemoryUserRepository struct {
    mu    sync.RWMutex
    users map[UserID]*User
}

func NewInMemoryUserRepository() *InMemoryUserRepository {
    return &InMemoryUserRepository{
        users: make(map[UserID]*User),
    }
}

func (r *InMemoryUserRepository) FindByID(ctx context.Context, id UserID) (*User, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()

    user, ok := r.users[id]
    if !ok {
        return nil, ErrUserNotFound
    }
    return user, nil
}

func (r *InMemoryUserRepository) Save(ctx context.Context, user *User) error {
    r.mu.Lock()
    defer r.mu.Unlock()

    r.users[user.ID] = user
    return nil
}

// Usage
func (s *UserService) ChangeUserName(ctx context.Context, userID UserID, newName string) error {
    user, err := s.repo.FindByID(ctx, userID)
    if err != nil {
        return fmt.Errorf("find user: %w", err)
    }

    user.Name = newName

    if err := s.repo.Save(ctx, user); err != nil {
        return fmt.Errorf("save user: %w", err)
    }

    return nil
}
```

### Python

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional, List
from datetime import datetime

# Domain entity
@dataclass
class User:
    id: str
    email: str
    name: str
    created_at: datetime

    def change_name(self, new_name: str) -> None:
        if not new_name or not new_name.strip():
            raise ValueError("Name cannot be blank")
        self.name = new_name

# Repository interface
class UserRepository(ABC):
    @abstractmethod
    def find_by_id(self, user_id: str) -> Optional[User]:
        pass

    @abstractmethod
    def find_by_email(self, email: str) -> Optional[User]:
        pass

    @abstractmethod
    def find_all(self) -> List[User]:
        pass

    @abstractmethod
    def save(self, user: User) -> None:
        pass

    @abstractmethod
    def delete(self, user_id: str) -> None:
        pass

# SQLAlchemy implementation
class SQLAlchemyUserRepository(UserRepository):
    def __init__(self, session: Session):
        self._session = session

    def find_by_id(self, user_id: str) -> Optional[User]:
        return self._session.query(User).filter_by(id=user_id).first()

    def save(self, user: User) -> None:
        self._session.merge(user)
        self._session.commit()

# In-memory implementation for testing
class InMemoryUserRepository(UserRepository):
    def __init__(self):
        self._users: dict[str, User] = {}

    def find_by_id(self, user_id: str) -> Optional[User]:
        return self._users.get(user_id)

    def save(self, user: User) -> None:
        self._users[user.id] = user

# Usage in tests
def test_change_user_name():
    repo = InMemoryUserRepository()
    user = User(id="1", email="test@example.com", name="Old", created_at=datetime.now())
    repo.save(user)

    service = UserService(repo)
    service.change_user_name("1", "New Name")

    updated = repo.find_by_id("1")
    assert updated.name == "New Name"
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Domain model exists (not just DTOs)
- [ ] **[MAJOR]** Need to test domain logic independently
- [ ] **[MINOR]** Multiple implementations needed (test, production)

### Correct Implementation
- [ ] **[BLOCKER]** Repository interface is in domain layer
- [ ] **[BLOCKER]** Implementation is in infrastructure layer
- [ ] **[MAJOR]** Returns domain objects, not DTOs or database entities
- [ ] **[MAJOR]** Methods are collection-like (find, save, delete)
- [ ] **[MINOR]** Specification pattern for complex queries

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Repository leaks database concepts (SQL, ORM entities)
- [ ] **[MAJOR]** Generic repository for all entities (loses domain value)
- [ ] **[MAJOR]** Business logic in repository implementation
- [ ] **[MINOR]** Too many query methods (consider Specification)

## Common Mistakes

### 1. Leaking Database Concepts
```java
// BAD: Repository returns JPA entities
public interface UserRepository {
    UserEntity findById(Long id);  // JPA entity, not domain
}

// GOOD: Repository returns domain objects
public interface UserRepository {
    Optional<User> findById(UserId id);  // Domain object
}
```

### 2. Generic Repository Anti-Pattern
```java
// BAD: Loses domain meaning
public interface GenericRepository<T, ID> {
    Optional<T> findById(ID id);
    void save(T entity);
}

// GOOD: Domain-specific repositories
public interface OrderRepository {
    Optional<Order> findById(OrderId id);
    List<Order> findPendingOrders();  // Domain-specific query
    List<Order> findByCustomer(CustomerId id);
}
```

### 3. Business Logic in Repository
```java
// BAD: Validation in repository
public class UserRepositoryImpl implements UserRepository {
    @Override
    public void save(User user) {
        // Business logic doesn't belong here!
        if (existsByEmail(user.getEmail())) {
            throw new DuplicateEmailException();
        }
        em.persist(user);
    }
}

// GOOD: Keep repository focused on persistence
public class UserRepositoryImpl implements UserRepository {
    @Override
    public void save(User user) {
        em.persist(user);  // Just persist
    }

    @Override
    public boolean existsByEmail(Email email) {
        // Query only
    }
}

// Validation in domain service
public class UserService {
    public void registerUser(User user) {
        if (userRepository.existsByEmail(user.getEmail())) {
            throw new DuplicateEmailException();
        }
        userRepository.save(user);
    }
}
```

## Repository vs. DAO

| Repository | DAO |
|------------|-----|
| Domain-centric | Database-centric |
| Returns domain objects | May return database entities |
| Collection-like interface | CRUD operations |
| Part of domain layer (interface) | Data access layer |
| Focus on aggregate roots | Any table/entity |

## Testing Strategy

### What to Test
1. **Domain service logic**: Use in-memory repository implementation
2. **Repository implementation**: Integration test against real database
3. **Query correctness**: Verify filters, pagination, sorting work
4. **Transactional behavior**: Test rollback scenarios

### How to Test

```java
// Unit test domain service with in-memory repo
class UserServiceTest {
    private InMemoryUserRepository repo;
    private UserService service;

    @BeforeEach
    void setup() {
        repo = new InMemoryUserRepository();
        service = new UserService(repo);
    }

    @Test
    void shouldChangeUserName() {
        // Given
        User user = new User(UserId.generate(), "old@example.com", "Old Name");
        repo.save(user);

        // When
        service.changeUserName(user.getId(), "New Name");

        // Then
        User updated = repo.findById(user.getId()).orElseThrow();
        assertThat(updated.getName()).isEqualTo("New Name");
    }

    @Test
    void shouldThrowWhenUserNotFound() {
        assertThrows(UserNotFoundException.class,
            () -> service.changeUserName(UserId.generate(), "Name"));
    }
}

// Integration test repository implementation
@DataJpaTest
class JpaUserRepositoryIntegrationTest {
    @Autowired
    private TestEntityManager entityManager;

    private JpaUserRepository repo;

    @Test
    void shouldFindByEmail() {
        // Given - use real database
        User user = new User(...);
        entityManager.persist(user);
        entityManager.flush();

        // When
        Optional<User> found = repo.findByEmail(user.getEmail());

        // Then
        assertThat(found).isPresent();
        assertThat(found.get().getId()).isEqualTo(user.getId());
    }
}
```

```go
// Go - Use interfaces for testability
func TestUserService_ChangeUserName(t *testing.T) {
    repo := NewInMemoryUserRepository()
    service := NewUserService(repo)

    user := &User{ID: "123", Name: "Old"}
    repo.Save(context.Background(), user)

    err := service.ChangeUserName(context.Background(), "123", "New")
    if err != nil {
        t.Fatal(err)
    }

    updated, _ := repo.FindByID(context.Background(), "123")
    if updated.Name != "New" {
        t.Errorf("expected New, got %s", updated.Name)
    }
}
```

### In-Memory Repository Pattern
Always create an in-memory implementation for testing:
- Fast unit tests (no database startup)
- Deterministic behavior
- Easy to inspect state directly

### What to Mock
- **Nothing!** Use in-memory implementation instead of mocks
- Mocking repository methods hides bugs in queries
- In-memory repo tests the contract naturally

### Testing Anti-Patterns
- ❌ Mocking repository methods in domain tests
- ❌ Testing repository implementation logic in unit tests
- ❌ No integration tests for actual database queries

## Often Composed With

| Pattern | Composition | Example |
|---------|-------------|---------|
| **Unit of Work** | Coordinate multi-aggregate transactions | `uow.repositories.users.save(user)` |
| **Specification** | Encapsulate complex queries | `repo.findAll(spec.active().and(spec.inRole("admin")))` |
| **Aggregate** | One repository per aggregate root | `OrderRepository` not `OrderLineRepository` |
| **Domain Events** | Publish events after save | `repo.save(user); events.publish(UserCreated)` |
| **Service Layer** | Services use repositories | `userService.register()` calls `userRepo.save()` |

### Typical Layering
```
┌─────────────────────────────────┐
│       Application Service       │ ← Uses repositories
├─────────────────────────────────┤
│         Domain Service          │ ← Uses repositories
├─────────────────────────────────┤
│      Repository Interface       │ ← Defined in domain layer
├─────────────────────────────────┤
│    Repository Implementation    │ ← In infrastructure layer
└─────────────────────────────────┘
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Unit of Work** | Coordinates multiple repository changes |
| **Specification** | Encapsulates query criteria |
| **Data Mapper** | Maps between domain and database |
| **Aggregate** | Repository per aggregate root |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Data JPA](https://spring.io/projects/spring-data-jpa) | Auto-generates repository implementations |
| **Java** | [Hibernate](https://hibernate.org/) | ORM with repository support |
| **Java** | [jOOQ](https://www.jooq.org/) | Type-safe SQL with repository patterns |
| **Java** | [MyBatis](https://mybatis.org/) | SQL mapper with repository capabilities |
| **Go** | [sqlx](https://github.com/jmoiron/sqlx) | Extensions to database/sql |
| **Go** | [GORM](https://gorm.io/) | ORM with repository pattern support |
| **Go** | [Ent](https://entgo.io/) | Entity framework by Meta |
| **Python** | [SQLAlchemy](https://www.sqlalchemy.org/) | ORM with repository pattern support |
| **Python** | [Django ORM](https://docs.djangoproject.com/en/4.2/topics/db/) | Built-in model repositories |
| **Python** | [Tortoise ORM](https://tortoise.github.io/) | Async ORM for Python |
| **JavaScript** | [TypeORM](https://typeorm.io/) | Repository pattern for TypeScript |
| **JavaScript** | [Prisma](https://www.prisma.io/) | Type-safe database client |
| **JavaScript** | [Sequelize](https://sequelize.org/) | ORM with model repositories |

## References

- Fowler, "Patterns of Enterprise Application Architecture" p.322
- Eric Evans, "Domain-Driven Design"
- https://martinfowler.com/eaaCatalog/repository.html
