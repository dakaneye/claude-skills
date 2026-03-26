# Python Type Hints

> Type annotations for public APIs, TypeVars, and modern Python generics.

## When Required

Type hints are REQUIRED for:
- All public function signatures
- All class attributes
- All module-level constants
- Return types (including `-> None`)

```python
# WRONG: Missing type hints on public API
def process_items(items, threshold):
    results = []
    for item in items:
        if item.value > threshold:
            results.append(item.name)
    return results

# RIGHT: Complete type annotations
def process_items(items: list[Item], threshold: float) -> list[str]:
    results: list[str] = []
    for item in items:
        if item.value > threshold:
            results.append(item.name)
    return results
```

## Common Type Hint Mistakes

```python
# WRONG: Using List, Dict, Optional from typing (Python 3.9+)
from typing import List, Dict, Optional

def get_users(ids: List[int]) -> Dict[int, Optional[str]]:
    pass

# RIGHT: Use built-in generics (Python 3.9+)
def get_users(ids: list[int]) -> dict[int, str | None]:
    pass

# WRONG: Optional[X] instead of X | None (Python 3.10+)
from typing import Optional
def find_user(user_id: int) -> Optional[User]:
    pass

# RIGHT: Union syntax with |
def find_user(user_id: int) -> User | None:
    pass

# WRONG: Forgetting to annotate return None
def log_event(event: Event):  # Returns None implicitly
    logger.info(event.message)

# RIGHT: Explicit None return
def log_event(event: Event) -> None:
    logger.info(event.message)
```

## TypeVar and Generics

```python
# WRONG: Losing type information
def first(items: list) -> Any:
    return items[0] if items else None

# RIGHT: Preserve type information with TypeVar
from typing import TypeVar

T = TypeVar("T")

def first(items: list[T]) -> T | None:
    return items[0] if items else None

# WRONG: TypeVar without bound when needed
T = TypeVar("T")

def serialize(obj: T) -> str:
    return obj.to_json()  # T has no to_json method

# RIGHT: TypeVar with bound
from typing import Protocol

class Serializable(Protocol):
    def to_json(self) -> str: ...

T = TypeVar("T", bound=Serializable)

def serialize(obj: T) -> str:
    return obj.to_json()
```

## Self Type (Python 3.11+)

```python
# WRONG: Returning class name in method (breaks inheritance)
class Builder:
    def with_name(self, name: str) -> "Builder":
        self.name = name
        return self  # Subclasses return wrong type

# RIGHT: Use Self for fluent interfaces
from typing import Self

class Builder:
    def with_name(self, name: str) -> Self:
        self.name = name
        return self

class AdvancedBuilder(Builder):
    def with_options(self, opts: dict) -> Self:
        self.opts = opts
        return self  # Returns AdvancedBuilder, not Builder
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `List[str]` | Deprecated in 3.9+ | `list[str]` |
| `Optional[X]` | Verbose | `X \| None` (3.10+) |
| `def func():` | Missing return type | `def func() -> None:` |
| `-> Any` | Loses type info | Use TypeVar |
| TypeVar without bound | No method access | Add `bound=Protocol` |
| `-> "ClassName"` in method | Breaks inheritance | `-> Self` (3.11+) |
