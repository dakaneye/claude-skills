# Node.js Type Safety Patterns

> JSDoc annotations, @ts-check, and explicit null handling for JavaScript.

## JSDoc for Type Hints

```javascript
// WRONG: No type information
function processItems(items, options) {
  // What shape is items? What options exist?
}

// RIGHT: JSDoc with types
/**
 * Process items with the given options.
 * @param {Array<{id: string, value: number}>} items - Items to process
 * @param {Object} options - Processing options
 * @param {boolean} [options.parallel=false] - Run in parallel
 * @param {number} [options.limit=10] - Concurrency limit
 * @returns {Promise<ProcessResult[]>}
 */
async function processItems(items, options = {}) {
  const { parallel = false, limit = 10 } = options;
  // ...
}
```

## @ts-check for JavaScript

```javascript
// Enable TypeScript checking in JS files
// @ts-check

/** @type {Map<string, number>} */
const cache = new Map();

cache.set('key', 'value');  // Error: string not assignable to number
```

## Explicit Null Handling

```javascript
// WRONG: Implicit null propagation
function getUserName(user) {
  return user.profile.name;  // Crashes if profile is null
}

// RIGHT: Optional chaining with fallback
function getUserName(user) {
  return user?.profile?.name ?? 'Unknown';
}

// RIGHT: Explicit validation when null is an error
function getUserName(user) {
  if (!user?.profile?.name) {
    throw new Error('User profile name is required');
  }
  return user.profile.name;
}
```

---

## Common Type Patterns

### Function Signatures

```javascript
/**
 * @typedef {Object} BuildOptions
 * @property {string} target - Build target (e.g., 'node', 'browser')
 * @property {boolean} [minify=false] - Whether to minify output
 * @property {string[]} [externals=[]] - External dependencies
 */

/**
 * Build the project with given options.
 * @param {BuildOptions} options
 * @returns {Promise<{success: boolean, output: string}>}
 */
async function build(options) {
  // ...
}
```

### Generic Types

```javascript
/**
 * @template T
 * @param {T[]} items
 * @param {(item: T) => boolean} predicate
 * @returns {T | undefined}
 */
function findFirst(items, predicate) {
  return items.find(predicate);
}
```

### Union Types

```javascript
/**
 * @param {string | string[]} input
 * @returns {string[]}
 */
function normalizeToArray(input) {
  return Array.isArray(input) ? input : [input];
}
```

---

## Type Guard Patterns

```javascript
/**
 * @param {unknown} value
 * @returns {value is string}
 */
function isString(value) {
  return typeof value === 'string';
}

/**
 * @param {unknown} value
 * @returns {value is {id: string, name: string}}
 */
function isUser(value) {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'name' in value
  );
}
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| No JSDoc on public API | Unknown types | Add `@param` and `@returns` |
| `user.profile.name` | Crashes on null | Use `user?.profile?.name` |
| Missing `@ts-check` | No type errors caught | Add `// @ts-check` |
| `any` everywhere | No type safety | Define proper types with `@typedef` |
| No default values | Undefined handling scattered | Use `options = {}` + destructuring |
