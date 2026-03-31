# Node.js Testing Patterns

> node:test structure, mocking, async patterns, and test organization.

## node:test Structure

```javascript
import { describe, it, before, after, beforeEach, mock } from 'node:test';
import assert from 'node:assert/strict';

describe('UserService', () => {
  let service;
  let mockDb;

  beforeEach(() => {
    mockDb = {
      query: mock.fn(() => Promise.resolve([]))
    };
    service = new UserService(mockDb);
  });

  it('returns empty array when no users', async () => {
    const users = await service.getAll();
    assert.deepEqual(users, []);
  });

  it('calls database with correct query', async () => {
    await service.getAll();
    assert.equal(mockDb.query.mock.calls.length, 1);
    assert.equal(mockDb.query.mock.calls[0].arguments[0], 'SELECT * FROM users');
  });
});
```

## Test File Organization

```javascript
// WRONG: Tests far from implementation
// src/services/user.js
// tests/unit/services/user.test.js

// RIGHT: Tests next to implementation
// src/services/user.js
// src/services/user.test.js

// package.json
{
  "scripts": {
    "test": "node --test 'src/**/*.test.js'"
  }
}
```

## Snapshot Testing with node:test

```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

describe('formatOutput', () => {
  it('formats user data correctly', (t) => {
    const result = formatOutput({ name: 'Alice', age: 30 });

    // Node 22.3+ has snapshot testing
    t.assert.snapshot(result);
  });
});
```

## Async Test Patterns

```javascript
// WRONG: Not awaiting async assertions
it('fetches user', () => {
  const user = service.getUser(1);  // Missing await!
  assert.equal(user.name, 'Alice');  // Comparing Promise to string
});

// RIGHT: Proper async test
it('fetches user', async () => {
  const user = await service.getUser(1);
  assert.equal(user.name, 'Alice');
});

// RIGHT: Testing for rejection
it('throws on invalid id', async () => {
  await assert.rejects(
    service.getUser(-1),
    { message: /invalid id/i }
  );
});
```

---

## Mocking Patterns

### Function Mocking

```javascript
import { mock } from 'node:test';

const mockFn = mock.fn((x) => x * 2);

mockFn(5);
mockFn(10);

assert.equal(mockFn.mock.calls.length, 2);
assert.deepEqual(mockFn.mock.calls[0].arguments, [5]);
assert.equal(mockFn.mock.calls[0].result, 10);
```

### Module Mocking

```javascript
import { mock } from 'node:test';

// Mock a module before importing
mock.module('node:fs/promises', {
  namedExports: {
    readFile: mock.fn(() => Promise.resolve('mocked content'))
  }
});

// Now import the module that uses fs
const { processFile } = await import('./processor.js');
```

### Resetting Mocks

```javascript
beforeEach(() => {
  mockFn.mock.resetCalls();  // Clear call history
  // or
  mockFn.mock.restore();     // Restore original implementation
});
```

---

## Test Organization Patterns

### Arrange-Act-Assert

```javascript
it('calculates total with discount', () => {
  // Arrange
  const cart = new Cart();
  cart.addItem({ price: 100, quantity: 2 });
  cart.applyDiscount(0.1);

  // Act
  const total = cart.getTotal();

  // Assert
  assert.equal(total, 180);
});
```

### Table-Driven Tests

```javascript
const testCases = [
  { input: '', expected: false, description: 'empty string' },
  { input: 'abc', expected: false, description: 'no numbers' },
  { input: '123', expected: true, description: 'all numbers' },
  { input: 'abc123', expected: true, description: 'mixed' },
];

for (const { input, expected, description } of testCases) {
  it(`hasNumbers returns ${expected} for ${description}`, () => {
    assert.equal(hasNumbers(input), expected);
  });
}
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| Tests in `tests/` dir | Hard to find | Colocate with source |
| `it('test', () => { asyncFn() })` | Promise not awaited | Use `async () => { await }` |
| No mocks | Tests hit real services | Use `mock.fn()` |
| Jest for simple projects | Heavy dependency | Use `node:test` |
| Testing implementation | Brittle tests | Test behavior, not internals |
| No assertion message | Unclear failures | Add descriptive message |
