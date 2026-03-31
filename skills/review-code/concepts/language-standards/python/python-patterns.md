# Pythonic Patterns

> List comprehensions, generators, context managers, and string formatting.

## List Comprehensions vs Loops

```python
# WRONG: Loop when comprehension is clearer
results = []
for item in items:
    if item.is_valid():
        results.append(item.name.upper())

# RIGHT: List comprehension
results = [item.name.upper() for item in items if item.is_valid()]

# WRONG: Nested comprehension that's unreadable
matrix = [[row[i] for row in data] for i in range(len(data[0]))]

# RIGHT: Use a function for complex transformations
def transpose(data: list[list[T]]) -> list[list[T]]:
    """Transpose a 2D matrix."""
    if not data:
        return []
    return [[row[i] for row in data] for i in range(len(data[0]))]

matrix = transpose(data)

# WRONG: Comprehension with side effects
[print(x) for x in items]  # Creates useless list

# RIGHT: Use a loop for side effects
for x in items:
    print(x)
```

## Generators for Memory Efficiency

```python
# WRONG: Loading everything into memory
def read_large_file(path: str) -> list[str]:
    with open(path) as f:
        return [process_line(line) for line in f]  # Entire file in memory

# RIGHT: Generator for large data
def read_large_file(path: str) -> Iterator[str]:
    with open(path) as f:
        for line in f:
            yield process_line(line)

# WRONG: Eager evaluation when lazy is better
def find_matches(items: list[Item], pattern: str) -> list[Item]:
    return [item for item in items if pattern in item.name]

all_matches = find_matches(huge_list, "test")
first_match = all_matches[0]  # Processed entire list for one item

# RIGHT: Generator expression or generator function
def find_matches(items: Iterable[Item], pattern: str) -> Iterator[Item]:
    return (item for item in items if pattern in item.name)

first_match = next(find_matches(huge_list, "test"), None)
```

## Context Managers

```python
# WRONG: Manual resource management
f = open("data.txt")
try:
    data = f.read()
finally:
    f.close()

# RIGHT: Context manager
with open("data.txt") as f:
    data = f.read()

# WRONG: Multiple context managers poorly formatted
with open("input.txt") as inp:
    with open("output.txt", "w") as out:
        out.write(inp.read())

# RIGHT: Multiple context managers (Python 3.10+ or parenthesized)
with (
    open("input.txt") as inp,
    open("output.txt", "w") as out,
):
    out.write(inp.read())

# RIGHT: Implement context manager protocol
class DatabaseConnection:
    def __enter__(self) -> "DatabaseConnection":
        self.conn = psycopg2.connect(...)
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> bool:
        self.conn.close()
        return False  # Don't suppress exceptions

# Automatic cleanup
with DatabaseConnection() as db:
    db.execute(query)
```

## String Formatting

```python
# WRONG: Using % formatting (legacy)
message = "User %s has %d items" % (name, count)

# WRONG: Using .format() for simple cases
message = "User {} has {} items".format(name, count)

# RIGHT: f-strings for readability (Python 3.6+)
message = f"User {name} has {count} items"

# WRONG: f-string with complex expressions
result = f"Total: {sum(item.price * item.qty for item in cart):.2f}"

# RIGHT: Compute first, format separately
total = sum(item.price * item.qty for item in cart)
result = f"Total: {total:.2f}"

# When to use .format(): Dynamic format strings
template = config.get("message_template")  # "Hello, {name}!"
message = template.format(name=user.name)

# WRONG: f-string in logging (evaluates even if not logged)
logger.debug(f"Processing {expensive_repr(obj)}")

# RIGHT: Use % formatting in logging (lazy evaluation)
logger.debug("Processing %s", obj)
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| Loop to build list | Verbose | List comprehension |
| `[print(x) for x in items]` | Side effects in comprehension | Use `for` loop |
| `return [x for x in huge_list]` | Memory | Use generator |
| Nested `with` blocks | Ugly | Parenthesized `with` |
| `"Hello %s" % name` | Legacy | f-string |
| `logger.debug(f"...")` | Eager eval | `logger.debug("...", arg)` |
