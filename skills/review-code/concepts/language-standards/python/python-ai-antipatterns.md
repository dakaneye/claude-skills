# Python AI Anti-Patterns

> Over-engineering, verbose comments, cargo-culted patterns, security, and performance.

## Over-Engineering

```python
# AI SMELL: AbstractFactoryStrategyBuilderPattern for simple task
class UserValidationStrategyFactory:
    def create_strategy(self, user_type: str) -> UserValidationStrategy:
        if user_type == "admin":
            return AdminUserValidationStrategy()
        return DefaultUserValidationStrategy()

class UserValidationStrategy(ABC):
    @abstractmethod
    def validate(self, user: User) -> bool: ...

class AdminUserValidationStrategy(UserValidationStrategy):
    def validate(self, user: User) -> bool:
        return user.email.endswith("@company.com")

# RIGHT: Simple function
def is_valid_admin(user: User) -> bool:
    return user.email.endswith("@company.com")
```

## Verbose Comments on Obvious Code

```python
# AI SMELL: Comments restating the code
def add(a: int, b: int) -> int:
    # Add a and b together
    result = a + b  # Store the sum in result
    # Return the result
    return result

# RIGHT: No comments needed for obvious code
def add(a: int, b: int) -> int:
    return a + b
```

## Cargo-Culted Patterns

```python
# AI SMELL: Singleton for no reason
class ConfigurationManager:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

# RIGHT: Just use a module-level instance or dependency injection
# config.py
_config: Config | None = None

def get_config() -> Config:
    global _config
    if _config is None:
        _config = load_config()
    return _config

# Or better: dependency injection
class App:
    def __init__(self, config: Config):
        self.config = config
```

## Reinventing the Standard Library

```python
# AI SMELL: Custom implementation of stdlib
def flatten(nested_list):
    """Flatten a nested list."""
    result = []
    for item in nested_list:
        if isinstance(item, list):
            result.extend(flatten(item))
        else:
            result.append(item)
    return result

# RIGHT: Use itertools
from itertools import chain

def flatten(nested_list: list[list[T]]) -> list[T]:
    return list(chain.from_iterable(nested_list))

# Or for deeply nested, use more_itertools
from more_itertools import collapse
list(collapse(deeply_nested))
```

## Unnecessary Abstraction

```python
# AI SMELL: Interface with one implementation
class IUserRepository(ABC):
    @abstractmethod
    def find_by_id(self, user_id: int) -> User | None: ...

class UserRepository(IUserRepository):
    def find_by_id(self, user_id: int) -> User | None:
        return db.query(User).get(user_id)

# RIGHT: Just use the class directly; add interface when needed
class UserRepository:
    def find_by_id(self, user_id: int) -> User | None:
        return db.query(User).get(user_id)

# Add Protocol for testing if needed:
class UserRepo(Protocol):
    def find_by_id(self, user_id: int) -> User | None: ...
```

## Silent Failures

```python
# AI SMELL: Swallowing exceptions
def safe_parse_json(data: str) -> dict:
    try:
        return json.loads(data)
    except json.JSONDecodeError:
        return {}  # Silent failure, caller has no idea it failed

# RIGHT: Let it fail or return explicit failure
def parse_json(data: str) -> dict:
    return json.loads(data)  # Let caller handle

# Or with explicit optional
def try_parse_json(data: str) -> dict | None:
    try:
        return json.loads(data)
    except json.JSONDecodeError:
        return None  # Explicit "parsing failed"
```

---

## Security Patterns

### Input Validation with Pydantic

```python
# WRONG: Manual validation scattered throughout
def create_user(data: dict) -> User:
    if not data.get("email"):
        raise ValueError("Email required")
    if "@" not in data["email"]:
        raise ValueError("Invalid email")
    # More scattered validation...

# RIGHT: Centralized validation with Pydantic
from pydantic import BaseModel, EmailStr, Field

class CreateUserRequest(BaseModel):
    email: EmailStr
    name: str = Field(min_length=2, max_length=100)
    age: int = Field(ge=0, le=150)

def create_user(request: CreateUserRequest) -> User:
    # Request is already validated
    return User(email=request.email, name=request.name)
```

### SQL Injection Prevention

```python
# WRONG: String interpolation in queries
def get_user(user_id: str) -> User | None:
    result = db.execute(f"SELECT * FROM users WHERE id = '{user_id}'")
    return result.fetchone()

# RIGHT: Parameterized queries
from sqlalchemy import text

def get_user(user_id: str) -> User | None:
    result = db.execute(
        text("SELECT * FROM users WHERE id = :id"),
        {"id": user_id}
    )
    return result.fetchone()

# BETTER: Use ORM
def get_user(session: Session, user_id: str) -> User | None:
    return session.get(User, user_id)
```

### Path Traversal Prevention

See `python-paths.md` for the full pattern using `is_relative_to()` to prevent directory escape attacks.

---

## Performance Patterns

### O(n²) Loop Anti-Patterns

```python
# WRONG: List search inside loop = O(n²)
for order in orders:
    customer = next((c for c in customers if c.id == order.customer_id), None)
    process_order(order, customer)

# RIGHT: Build dict first = O(n)
customer_map = {c.id: c for c in customers}
for order in orders:
    customer = customer_map.get(order.customer_id)
    process_order(order, customer)
```

### String Building in Loops

```python
# WRONG: String concatenation in loop
result = ""
for item in items:
    result += f"- {item.name}\n"  # Creates new string each time

# RIGHT: Use join
result = "\n".join(f"- {item.name}" for item in items)
```

### Repeated Regex Compilation

```python
# WRONG: Compiling regex on every call
def is_valid(text: str) -> bool:
    return re.match(r'^[a-z0-9]+$', text) is not None  # Compiled each time

# RIGHT: Compile once at module level
VALID_PATTERN = re.compile(r'^[a-z0-9]+$')

def is_valid(text: str) -> bool:
    return VALID_PATTERN.match(text) is not None
```

### Sequential I/O When Parallel Works

```python
# WRONG: Sequential async calls
async def fetch_all(ids: list[str]) -> list[Data]:
    results = []
    for id in ids:
        result = await fetch_data(id)  # Waits for each one
        results.append(result)
    return results

# RIGHT: Parallel with gather
async def fetch_all(ids: list[str]) -> list[Data]:
    return await asyncio.gather(*[fetch_data(id) for id in ids])
```

---

## AI Detection Signals

| Signal | Description |
|--------|-------------|
| `Factory`, `Strategy`, `Builder` | Over-engineering |
| Comments restating code | AI verbosity |
| Singleton pattern | Cargo cult |
| Custom stdlib reimplementation | Not checking stdlib |
| `IFoo` with one implementation | Premature abstraction |
| Silent `except: return {}` | Hiding failures |
| `for x: await y` in loop | Sequential when parallel |
| Regex in function body | Repeated compilation |
