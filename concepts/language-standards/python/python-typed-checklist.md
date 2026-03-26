# TYPED Checklist for Python Code Review

> Quick reference mnemonic for Python code review. Load focused files for deep patterns.

## Version Check First

Check `pyproject.toml` or `setup.py` for target Python version before applying patterns:

| Target | Type Syntax | Union Syntax | Modern Features |
|--------|-------------|--------------|-----------------|
| 3.12+ | `list[str]` | `X \| None` | `match`, `TaskGroup`, `@override` |
| 3.11 | `list[str]` | `X \| None` | `Self`, `TaskGroup`, `ExceptionGroup` |
| 3.10 | `list[str]` | `X \| None` | `match` statements |
| 3.9 | `list[str]` | `Optional[X]` | Use `from __future__ import annotations` |
| <3.9 | `List[str]` | `Optional[X]` | Import from `typing` module |

## Before Generating Python Code

Load these files to prevent common LLM issues:

1. **Always**: `python-ai-antipatterns.md` - Prevents over-engineering, cargo-cult patterns
2. **If writing APIs**: `python-types.md` - Complete type annotations
3. **If handling errors**: `python-exceptions.md` - Proper chaining, no bare except
4. **If using async**: `python-async.md` - TaskGroup, proper concurrency
5. **If logging**: `python-logging.md` - Lazy evaluation, structured logging

---

## The TYPED Checklist

- **T**ypes - Complete annotations on public APIs
- **Y**ield - Use generators for memory efficiency
- **P**athlib - Modern path handling, not os.path
- **E**xceptions - Chain them, don't swallow them
- **D**ataclass - Right tool for your data structure

---

## Quick Reference by Section

### Types
- [ ] All public functions have complete type annotations
- [ ] Using built-in generics (`list[str]` not `List[str]`) for Python 3.9+
- [ ] Using `X | None` instead of `Optional[X]` for Python 3.10+
- [ ] Return type includes `-> None` where applicable
- [ ] TypeVars have appropriate bounds when needed

### Yield
- [ ] Generators used for large data processing
- [ ] No unnecessary list creation (`for x in generator` not `for x in list(generator)`)
- [ ] Generator expressions for simple transformations
- [ ] Memory-efficient iteration with `itertools` where applicable

### Pathlib
- [ ] Using `pathlib.Path` instead of `os.path`
- [ ] Path composition with `/` operator
- [ ] Using `.read_text()`, `.write_text()` for simple file I/O
- [ ] Using `.glob()` instead of `glob.glob()`

### Exceptions
- [ ] Exceptions chained with `from` to preserve traceback
- [ ] No bare `except:` clauses
- [ ] Custom exceptions inherit from appropriate base
- [ ] Exceptions used for exceptional cases, not control flow
- [ ] Validation errors raised, not returned as tuples

### Dataclass
- [ ] Using `@dataclass` for simple data containers
- [ ] Using `field(default_factory=list)` for mutable defaults
- [ ] Using `frozen=True` for immutable data
- [ ] Using Pydantic when validation is needed
- [ ] Using TypedDict for dict-like external data

### Additional Checks
- [ ] f-strings for formatting (except in logging)
- [ ] `%s` formatting in logging calls (lazy evaluation)
- [ ] `logger.exception()` for error tracebacks
- [ ] Module-level logger with `__name__`
- [ ] Context managers for resource handling
- [ ] Imports organized (stdlib, third-party, local)
- [ ] Docstrings match implementation
- [ ] Tests use fixtures, not duplicate setup
- [ ] No AI-generated over-engineering
- [ ] No reinvented stdlib functionality

---

## Focused Files

Load these for deep patterns:

| File | When to Load |
|------|--------------|
| `python-types.md` | Type hints, TypeVar, generics, Self |
| `python-exceptions.md` | Exception handling, custom exceptions |
| `python-patterns.md` | Comprehensions, generators, context managers |
| `python-paths.md` | pathlib usage, path traversal prevention |
| `python-datastructures.md` | dataclass, TypedDict, Pydantic, slots |
| `python-async.md` | async/await, TaskGroup, concurrency |
| `python-testing.md` | pytest fixtures, parametrize |
| `python-logging.md` | Lazy evaluation, structured logging |
| `python-ai-antipatterns.md` | AI code smells, security, performance |
