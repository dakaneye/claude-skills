# Python Logging

> Lazy evaluation, structured logging, and logger best practices.

## Lazy Evaluation

```python
# WRONG: f-string evaluated even if level disabled
logger.debug(f"Processing {expensive_repr(obj)}")  # Always computes expensive_repr()

# RIGHT: % formatting with lazy evaluation
logger.debug("Processing %s", obj)  # Only computed if DEBUG enabled

# WRONG: String concatenation
logger.info("User " + user.name + " logged in")

# RIGHT: % formatting
logger.info("User %s logged in", user.name)

# WRONG: .format() in logging
logger.warning("Failed after {} retries".format(count))

# RIGHT: % formatting
logger.warning("Failed after %d retries", count)
```

## Logger Instantiation

```python
# WRONG: Using root logger
import logging
logging.info("Something happened")  # Goes to root logger

# RIGHT: Module-level logger
import logging

logger = logging.getLogger(__name__)

def process():
    logger.info("Processing started")

# WRONG: Creating logger in function (creates new logger each call)
def process():
    logger = logging.getLogger("myapp")
    logger.info("...")

# RIGHT: Module-level, __name__ matches module hierarchy
logger = logging.getLogger(__name__)
```

## Structured Logging

```python
# WRONG: Embedding structured data in message
logger.info(f"Order completed: order_id={order.id}, user={user.id}, total={total}")

# RIGHT: Use extra for structured data
logger.info(
    "Order completed",
    extra={
        "order_id": order.id,
        "user_id": user.id,
        "total": total,
    }
)

# With structlog or python-json-logger, extra fields become JSON keys
```

## Exception Logging

```python
# WRONG: Losing traceback
try:
    risky_operation()
except Exception as e:
    logger.error(f"Operation failed: {e}")  # No traceback

# RIGHT: Use exception() for full traceback
try:
    risky_operation()
except Exception:
    logger.exception("Operation failed")  # Includes full traceback

# Or explicitly with exc_info
try:
    risky_operation()
except Exception as e:
    logger.error("Operation failed: %s", e, exc_info=True)
```

## Log Levels

```python
# Use appropriate levels
logger.debug("Detailed trace info")      # Development only
logger.info("Normal operation events")   # Production milestones
logger.warning("Recoverable issues")     # Should investigate
logger.error("Failures requiring action") # Needs attention
logger.critical("System-breaking issues") # Immediate action

# WRONG: Using wrong level
logger.info("Failed to connect to database")  # This is an error!
logger.error("Starting server")               # This is info!
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `logger.debug(f"...")` | Eager evaluation | `logger.debug("...", arg)` |
| `logging.info()` | Root logger | `logger = logging.getLogger(__name__)` |
| `logger.error(str(e))` | Lost traceback | `logger.exception("msg")` |
| Data in message string | Hard to parse | Use `extra={}` dict |
| Logger in function | Creates new each call | Module-level logger |
