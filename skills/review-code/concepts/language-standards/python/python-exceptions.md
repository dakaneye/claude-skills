# Python Exception Handling

> Exception chaining, custom exceptions, and return values vs exceptions.

## Exception Chaining

```python
# WRONG: Swallowing the original exception
def load_config(path: str) -> Config:
    try:
        with open(path) as f:
            return parse_config(f.read())
    except FileNotFoundError:
        raise ConfigError("Config file not found")  # Original traceback lost

# RIGHT: Chain exceptions with 'from'
def load_config(path: str) -> Config:
    try:
        with open(path) as f:
            return parse_config(f.read())
    except FileNotFoundError as e:
        raise ConfigError(f"Config file not found: {path}") from e

# WRONG: Bare except clause
try:
    risky_operation()
except:  # Catches SystemExit, KeyboardInterrupt
    log.error("Something went wrong")

# RIGHT: Catch specific exceptions
try:
    risky_operation()
except (ValueError, TypeError) as e:
    log.error("Invalid operation: %s", e)
except Exception as e:
    log.exception("Unexpected error")
    raise
```

## Return Values vs Exceptions

```python
# WRONG: Using exceptions for control flow
def find_user(user_id: int) -> User:
    user = db.query(User).filter_by(id=user_id).first()
    if user is None:
        raise UserNotFoundError(user_id)  # Expected case, not exceptional
    return user

# Caller must catch everywhere
try:
    user = find_user(123)
except UserNotFoundError:
    user = create_default_user()

# RIGHT: Return None for expected "not found" cases
def find_user(user_id: int) -> User | None:
    return db.query(User).filter_by(id=user_id).first()

# Caller handles naturally
user = find_user(123) or create_default_user()

# WRONG: Returning error codes (Go envy)
def validate(data: dict) -> tuple[bool, str | None]:
    if "name" not in data:
        return False, "missing name"
    return True, None

# RIGHT: Raise for validation failures (these ARE exceptional)
class ValidationError(Exception):
    def __init__(self, field: str, message: str) -> None:
        self.field = field
        super().__init__(f"{field}: {message}")

def validate(data: dict) -> None:
    if "name" not in data:
        raise ValidationError("name", "field is required")
```

## Custom Exception Hierarchy

```python
# WRONG: Flat exception hierarchy
class ConfigError(Exception): pass
class ConfigNotFoundError(Exception): pass
class ConfigParseError(Exception): pass
class ConfigValidationError(Exception): pass

# Caller can't catch "all config errors" easily

# RIGHT: Hierarchical exceptions
class ConfigError(Exception):
    """Base exception for configuration errors."""
    pass

class ConfigNotFoundError(ConfigError):
    """Raised when config file doesn't exist."""
    def __init__(self, path: str) -> None:
        self.path = path
        super().__init__(f"Config not found: {path}")

class ConfigParseError(ConfigError):
    """Raised when config file is malformed."""
    def __init__(self, path: str, line: int, detail: str) -> None:
        self.path = path
        self.line = line
        super().__init__(f"{path}:{line}: {detail}")

# Caller can catch broadly or specifically
try:
    config = load_config("app.yaml")
except ConfigNotFoundError:
    config = get_default_config()
except ConfigError as e:
    log.error("Config error: %s", e)
    raise SystemExit(1)
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `raise Error("msg")` | Lost traceback | `raise Error("msg") from e` |
| `except:` | Catches SystemExit | `except Exception:` |
| `raise NotFound` for missing | Control flow abuse | Return `None` |
| `return (False, "error")` | Go envy | Raise exception |
| Flat exceptions | Hard to catch groups | Use hierarchy |
