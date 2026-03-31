---
globs: "*.py"
---

# Python Quality Rules (TYPED)

## Checklist

### T - Types
- `[MAJOR]` All public functions have complete type annotations
- `[MAJOR]` Built-in generics (`list[str]`) for Python 3.9+; `X | None` for 3.10+
- `[MINOR]` Return type includes `-> None` where applicable

### Y - Yield
- `[MAJOR]` Generators used for large data processing
- `[MINOR]` No unnecessary `list()` wrapping generators

### P - Pathlib
- `[MAJOR]` `pathlib.Path` instead of `os.path`
- `[MINOR]` Path composition with `/` operator; `.read_text()` / `.write_text()`

### E - Exceptions
- `[BLOCKER]` Exceptions chained with `from` to preserve traceback
- `[BLOCKER]` No bare `except:` clauses
- `[MAJOR]` Custom exceptions inherit from appropriate base
- `[MAJOR]` Validation errors raised, not returned as tuples

### D - Dataclass
- `[MAJOR]` `@dataclass` for data containers; `frozen=True` for immutable
- `[MAJOR]` `field(default_factory=list)` for mutable defaults
- `[MAJOR]` Pydantic when validation is needed; TypedDict for dict-like external data

### Additional
- `[MAJOR]` f-strings for formatting EXCEPT in logging (`%s` for lazy evaluation)
- `[MAJOR]` `logger.exception()` for error tracebacks
- `[MAJOR]` Module-level logger: `logging.getLogger(__name__)`
- `[MAJOR]` Context managers for resource handling

## AI Detection Signals

| Signal | Severity | What to Look For |
|--------|----------|------------------|
| Factory/Strategy/Builder class | MAJOR | Over-engineering — use a simple function |
| Comments restating code | MINOR | `# Add a and b` on `return a + b` |
| Singleton pattern (`__new__`) | MAJOR | Cargo cult — use module-level instance or DI |
| Custom stdlib reimplementation | MAJOR | Hand-rolled `flatten()` instead of `itertools.chain` |
| `IFoo` ABC with one impl | MAJOR | Premature abstraction — use Protocol if needed for tests |
| Silent `except: return {}` | BLOCKER | Hiding failures — let caller handle or return None |
| `for x: await y` in loop | MAJOR | Sequential when parallel — use `asyncio.gather` |
| Regex in function body | MAJOR | Recompiled each call — use `re.compile()` at module level |
| `os.path` usage | MINOR | Use `pathlib.Path` for modern path handling |
| String concat in loop | MAJOR | Use `"\n".join(...)` instead |

## Top 3 Anti-Pattern Examples

### Over-engineering with Strategy pattern
```python
# BAD
class UserValidationStrategyFactory:
    def create_strategy(self, user_type: str) -> UserValidationStrategy: ...
class AdminUserValidationStrategy(UserValidationStrategy):
    def validate(self, user: User) -> bool:
        return user.email.endswith("@company.com")

# GOOD
def is_valid_admin(user: User) -> bool:
    return user.email.endswith("@company.com")
```

### Silent exception swallowing
```python
# BAD
def safe_parse_json(data: str) -> dict:
    try: return json.loads(data)
    except json.JSONDecodeError: return {}  # Silent failure

# GOOD
def parse_json(data: str) -> dict:
    return json.loads(data)  # Let caller handle

# OR explicit optional
def try_parse_json(data: str) -> dict | None:
    try: return json.loads(data)
    except json.JSONDecodeError: return None
```

### Sequential async when parallel works
```python
# BAD — sequential, O(n) round-trips
async def fetch_all(ids: list[str]) -> list[Data]:
    results = []
    for id in ids:
        result = await fetch_data(id)
        results.append(result)
    return results

# GOOD — parallel
async def fetch_all(ids: list[str]) -> list[Data]:
    return await asyncio.gather(*[fetch_data(id) for id in ids])
```

## Deep Dives
See `~/.claude/skills/dakaneye-review-code/` (python-*.md files) for focused files on types, exceptions, patterns, paths, datastructures, async, testing, logging, and AI anti-patterns.
