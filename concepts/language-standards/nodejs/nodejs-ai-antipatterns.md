# Node.js AI Anti-Patterns

> Common patterns in AI-generated code: over-abstraction, unnecessary utils, DRY violations.

## Over-Abstraction

```javascript
// WRONG: AI loves AbstractFactoryManagerService
class UserRepositoryFactory {
  createRepository(type) {
    switch (type) {
      case 'postgres': return new PostgresUserRepository();
      case 'memory': return new InMemoryUserRepository();
    }
  }
}

// You only have one database. YAGNI.

// RIGHT: Direct implementation
class UserRepository {
  constructor(db) {
    this.db = db;
  }

  async find(id) {
    return this.db.query('SELECT * FROM users WHERE id = ?', [id]);
  }
}
```

## Unnecessary Utility Modules

```javascript
// WRONG: Creating utils.js for trivial operations
// utils.js
export const isNonEmptyString = (s) => typeof s === 'string' && s.length > 0;
export const isPositiveNumber = (n) => typeof n === 'number' && n > 0;

// RIGHT: Inline simple checks
if (typeof name === 'string' && name.length > 0) {
  // ...
}
```

## Excessive Configuration

```javascript
// WRONG: Configuration for everything
const config = {
  database: {
    connection: {
      pool: {
        min: process.env.DB_POOL_MIN || 2,
        max: process.env.DB_POOL_MAX || 10,
        acquireTimeout: process.env.DB_ACQUIRE_TIMEOUT || 30000,
        idleTimeout: process.env.DB_IDLE_TIMEOUT || 10000,
        // 20 more options...
      }
    }
  }
};

// RIGHT: Sensible defaults, configure only what varies
const pool = createPool(process.env.DATABASE_URL, {
  max: parseInt(process.env.DB_POOL_MAX ?? '10')
});
```

## Premature Optimization

```javascript
// WRONG: AI adds caching "for performance"
const cache = new Map();

function getUser(id) {
  if (cache.has(id)) {
    return cache.get(id);
  }
  const user = db.query('SELECT * FROM users WHERE id = ?', [id]);
  cache.set(id, user);
  return user;
}

// Problems:
// - No TTL (stale data forever)
// - No max size (memory leak)
// - No invalidation strategy
// - You don't even have performance problems yet!

// RIGHT: Add caching when you measure a need
function getUser(id) {
  return db.query('SELECT * FROM users WHERE id = ?', [id]);
}
```

## Reinventing Package Parsing

```javascript
// WRONG: Custom package name parsing
function parsePackageName(spec) {
  const match = spec.match(/^(@[^/]+\/)?([^@]+)@?(.*)$/);
  return {
    scope: match[1]?.slice(1, -1),
    name: match[2],
    version: match[3] || 'latest'
  };
}

// RIGHT: Use npm-package-arg (battle-tested)
import npa from 'npm-package-arg';

const parsed = npa('lodash@^4.0.0');
// { name: 'lodash', fetchSpec: '^4.0.0', type: 'range', ... }
```

## String Replace Without Global Flag

```javascript
// WRONG: Only replaces first occurrence
const escaped = input.replace('%20', ' ');
const cleaned = str.replace('\n', '');

// RIGHT: Global replacement
const escaped = input.replaceAll('%20', ' ');
// OR
const escaped = input.replace(/%20/g, ' ');
```

---

## DRY Violations

### Method Layering

```javascript
// WRONG: Duplicated logic across methods
function formatName(pkg) {
  if (pkg.scope) {
    return `@${pkg.scope}/${pkg.name}`;
  }
  return pkg.name;
}

function formatPurl(pkg) {
  if (pkg.scope) {
    return `pkg:npm/@${pkg.scope}/${pkg.name}@${pkg.version}`;
  }
  return `pkg:npm/${pkg.name}@${pkg.version}`;
}

function formatCoordinates(pkg) {
  if (pkg.scope) {
    return `@${pkg.scope}/${pkg.name}@${pkg.version}`;
  }
  return `${pkg.name}@${pkg.version}`;
}

// RIGHT: Layer properly
function formatName(pkg) {
  return pkg.scope ? `@${pkg.scope}/${pkg.name}` : pkg.name;
}

function formatCoordinates(pkg) {
  return `${formatName(pkg)}@${pkg.version}`;
}

function formatPurl(pkg) {
  return `pkg:npm/${formatCoordinates(pkg)}`;
}
```

---

## Documentation vs Implementation

### Comments Must Match Code

```javascript
// WRONG: Comment describes non-existent behavior
/**
 * Parses package name with support for:
 * - Scoped packages (@babel/core)
 * - Version ranges (lodash@^4.0.0)
 * - Git URLs (git+https://...)
 */
function parsePackageName(name) {
  // Only handles name, no version, no git URLs
  return { name };
}

// RIGHT: Document actual behavior
/**
 * Extracts the package name from a simple package specifier.
 * Does NOT handle version ranges or git URLs.
 * For full specifier parsing, use npm-package-arg.
 */
function parsePackageName(name) {
  return { name };
}
```

---

## AI Detection Signals

| Signal | Description |
|--------|-------------|
| `utils.js` created | Dumping ground for trivial helpers |
| Factory/Manager/Service suffix | Over-abstraction |
| Unused config options | Premature flexibility |
| Cache without TTL/invalidation | Premature optimization |
| Custom parsing for npm formats | Reinventing npm-package-arg |
| `.replace(str, str)` | Missing `/g` flag |
| Duplicated conditionals | Poor method layering |
| Comments describing unimplemented features | AI hallucination |

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `UserRepositoryFactory` | YAGNI | Direct `UserRepository` |
| `utils.js` | Unnecessary abstraction | Inline simple checks |
| 20+ config options | Over-engineering | Sensible defaults |
| `Map` cache everywhere | No invalidation | Add when measured |
| Custom npm parsing regex | Fragile | Use `npm-package-arg` |
| `.replace(a, b)` | Only first match | Use `.replaceAll()` or `/g` |
| Duplicated conditionals | DRY violation | Layer methods |
