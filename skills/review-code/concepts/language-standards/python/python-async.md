# Python Async Patterns

> async/await, asyncio.gather, and async context managers.

## Common Async Mistakes

```python
# WRONG: Blocking call in async function
async def fetch_data(url: str) -> dict:
    response = requests.get(url)  # Blocks the event loop!
    return response.json()

# RIGHT: Use async HTTP client
import httpx

async def fetch_data(url: str) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.json()

# WRONG: Sequential awaits when parallel is possible
async def fetch_all(urls: list[str]) -> list[dict]:
    results = []
    for url in urls:
        results.append(await fetch_data(url))  # Sequential!
    return results

# RIGHT: Concurrent execution with gather
import asyncio

async def fetch_all(urls: list[str]) -> list[dict]:
    tasks = [fetch_data(url) for url in urls]
    return await asyncio.gather(*tasks)

# BETTER (Python 3.11+): TaskGroup for structured concurrency
async def fetch_all(urls: list[str]) -> list[dict]:
    results = []
    async with asyncio.TaskGroup() as tg:
        for url in urls:
            tg.create_task(fetch_and_append(url, results))
    return results
# TaskGroup cancels all tasks on first exception, cleaner than gather

# WRONG: Not handling cancellation
async def long_running_task():
    while True:
        await do_work()
        await asyncio.sleep(1)

# RIGHT: Handle cancellation gracefully
async def long_running_task():
    try:
        while True:
            await do_work()
            await asyncio.sleep(1)
    except asyncio.CancelledError:
        await cleanup()
        raise  # Re-raise to propagate cancellation

# WRONG: Mixing sync and async incorrectly
def sync_wrapper():
    return asyncio.run(async_function())  # Creates new event loop each time

# RIGHT: Use proper async context or run_in_executor
async def main():
    result = await async_function()  # Already in async context

# For sync code that must call async:
def sync_entry_point():
    asyncio.run(main())  # Single entry point
```

## Async Context Managers

```python
# WRONG: Sync context manager in async code
class DatabasePool:
    def __enter__(self):
        self.conn = create_connection()  # Blocking!
        return self

    def __exit__(self, *args):
        self.conn.close()

# RIGHT: Async context manager
class DatabasePool:
    async def __aenter__(self) -> "DatabasePool":
        self.conn = await create_connection()
        return self

    async def __aexit__(self, *args) -> bool:
        await self.conn.close()
        return False

async def query():
    async with DatabasePool() as pool:
        return await pool.execute("SELECT 1")

# Or use contextlib
from contextlib import asynccontextmanager

@asynccontextmanager
async def database_pool():
    conn = await create_connection()
    try:
        yield conn
    finally:
        await conn.close()
```

## Timeout Patterns

```python
# Timeout on async operation
async def fetch_with_timeout(url: str, timeout: float = 10.0) -> dict:
    async with asyncio.timeout(timeout):
        return await fetch_data(url)

# Or using wait_for
result = await asyncio.wait_for(fetch_data(url), timeout=10.0)
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `requests.get()` in async | Blocks event loop | Use `httpx.AsyncClient` |
| `for url: await fetch(url)` | Sequential | `asyncio.gather(*tasks)` |
| `asyncio.gather()` | No auto-cancel on error | `TaskGroup` (3.11+) |
| No `CancelledError` handling | Unclean shutdown | Catch, cleanup, re-raise |
| `asyncio.run()` in async | Nested event loop | Just `await` |
| Sync `__enter__` | Blocks | Use `__aenter__` |
