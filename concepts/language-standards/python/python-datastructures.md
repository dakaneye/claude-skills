# Python Data Structures

> dataclass, TypedDict, Pydantic, and choosing the right structure.

## Choosing the Right Structure

| Use Case | Choice | Reason |
|----------|--------|--------|
| Simple data container | `dataclass` | Automatic `__init__`, `__repr__`, `__eq__` |
| Immutable data | `@dataclass(frozen=True)` or `NamedTuple` | Hashable, thread-safe |
| JSON-like dicts with types | `TypedDict` | Type checking for dict keys |
| Validation + serialization | `Pydantic BaseModel` | Runtime validation, JSON schema |
| Config from env/files | `Pydantic Settings` | Auto-load from environment |
| Database models | `SQLAlchemy models` | ORM mapping |

## dataclass Patterns

```python
# WRONG: Manual __init__ for simple data
class User:
    def __init__(self, name: str, email: str, active: bool = True):
        self.name = name
        self.email = email
        self.active = active

    def __repr__(self):
        return f"User(name={self.name!r}, email={self.email!r})"

    def __eq__(self, other):
        if not isinstance(other, User):
            return NotImplemented
        return (self.name, self.email, self.active) == (other.name, other.email, other.active)

# RIGHT: dataclass
from dataclasses import dataclass

@dataclass
class User:
    name: str
    email: str
    active: bool = True

# WRONG: Mutable default in dataclass
@dataclass
class Config:
    items: list[str] = []  # All instances share this list!

# RIGHT: Use field with default_factory
from dataclasses import dataclass, field

@dataclass
class Config:
    items: list[str] = field(default_factory=list)

# Frozen dataclass for immutability
@dataclass(frozen=True)
class Point:
    x: float
    y: float

    def distance_from_origin(self) -> float:
        return (self.x ** 2 + self.y ** 2) ** 0.5

# Python 3.10+: slots for memory efficiency
@dataclass(slots=True)
class Event:
    timestamp: float
    message: str
    # Uses __slots__, reduces memory ~40%, prevents dynamic attributes
```

## TypedDict vs dataclass

```python
# TypedDict: For dict-like data (JSON, external APIs)
from typing import TypedDict, NotRequired

class UserDict(TypedDict):
    id: int
    name: str
    email: str
    metadata: NotRequired[dict[str, str]]  # Optional key

def process_api_response(data: UserDict) -> None:
    # data["id"] is typed as int
    # data["unknown"] would be a type error
    pass

# dataclass: For internal domain objects
@dataclass
class User:
    id: int
    name: str
    email: str
    metadata: dict[str, str] = field(default_factory=dict)

# When to use which:
# - TypedDict: Interfacing with JSON, dicts from external sources
# - dataclass: Internal domain models, need methods, need immutability
```

## Pydantic for Validation

```python
# WRONG: Manual validation everywhere
@dataclass
class CreateUserRequest:
    email: str
    age: int

    def __post_init__(self):
        if "@" not in self.email:
            raise ValueError("Invalid email")
        if self.age < 0 or self.age > 150:
            raise ValueError("Invalid age")

# RIGHT: Pydantic with declarative validation
from pydantic import BaseModel, EmailStr, Field

class CreateUserRequest(BaseModel):
    email: EmailStr
    age: int = Field(ge=0, le=150)

    model_config = {"strict": True}

# Automatic validation on instantiation
try:
    request = CreateUserRequest(email="invalid", age=-5)
except ValidationError as e:
    print(e.errors())  # Structured error info
```

---

## Quick Reference

| Need | Use | Why |
|------|-----|-----|
| Simple data holder | `@dataclass` | Auto-generated methods |
| Mutable default | `field(default_factory=list)` | Avoid shared mutable |
| Immutable | `@dataclass(frozen=True)` | Hashable, safe |
| Memory efficiency | `@dataclass(slots=True)` | ~40% less memory (3.10+) |
| Dict from JSON | `TypedDict` | Type checking on keys |
| Validation needed | `Pydantic BaseModel` | Runtime validation |
| Environment config | `Pydantic Settings` | Auto-load from env |
