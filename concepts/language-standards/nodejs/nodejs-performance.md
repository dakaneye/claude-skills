# Node.js Performance Patterns

> O(n²) anti-patterns, async efficiency, and avoiding repeated work.

## O(n²) Loop Anti-Patterns

```javascript
// WRONG: Array.find inside loop = O(n²)
for (const order of orders) {
  const customer = customers.find(c => c.id === order.customerId);
  processOrder(order, customer);
}

// RIGHT: Build Map first = O(n)
const customerMap = new Map(customers.map(c => [c.id, c]));
for (const order of orders) {
  const customer = customerMap.get(order.customerId);
  processOrder(order, customer);
}
```

## Sequential Awaits

```javascript
// WRONG: Sequential when independent
const user = await fetchUser(id);
const orders = await fetchOrders(id);
const preferences = await fetchPreferences(id);

// RIGHT: Parallel with Promise.all
const [user, orders, preferences] = await Promise.all([
  fetchUser(id),
  fetchOrders(id),
  fetchPreferences(id),
]);
```

## Repeated Parsing/Compilation

```javascript
// WRONG: Regex compiled on every call
function isValid(input) {
  return /^[a-z0-9]+$/i.test(input);  // Compiled each time in hot path
}

// RIGHT: Compile once
const VALID_PATTERN = /^[a-z0-9]+$/i;
function isValid(input) {
  return VALID_PATTERN.test(input);
}

// WRONG: JSON.parse in loop
for (const row of rows) {
  const data = JSON.parse(row.jsonColumn);  // Parse every iteration
}

// RIGHT: Parse once or stream
const parsed = rows.map(row => ({ ...row, data: JSON.parse(row.jsonColumn) }));
```

## String Building in Loops

```javascript
// WRONG: String concatenation in loop
let html = '';
for (const item of items) {
  html += `<li>${item.name}</li>`;  // Creates new string each time
}

// RIGHT: Array join
const html = items.map(item => `<li>${item.name}</li>`).join('');
```

## Unnecessary Array Creation

```javascript
// WRONG: Creating intermediate arrays
const result = data
  .filter(x => x.active)
  .map(x => x.value)
  .filter(v => v > 0)
  .map(v => v * 2);  // 4 intermediate arrays

// RIGHT: Single pass when possible
const result = [];
for (const x of data) {
  if (x.active && x.value > 0) {
    result.push(x.value * 2);
  }
}

// Or use reduce for functional style
const result = data.reduce((acc, x) => {
  if (x.active && x.value > 0) acc.push(x.value * 2);
  return acc;
}, []);
```

## Repeated Config/File Reads

```javascript
// WRONG: Reading config on every request
async function handleRequest(req) {
  const config = await fs.readFile('config.json', 'utf8');  // I/O every time!
  const settings = JSON.parse(config);
  // ...
}

// RIGHT: Read once, cache
let cachedConfig = null;
async function getConfig() {
  if (!cachedConfig) {
    cachedConfig = JSON.parse(await fs.readFile('config.json', 'utf8'));
  }
  return cachedConfig;
}
```

---

## Common Performance Issues

| Pattern | Complexity | Fix |
|---------|------------|-----|
| `array.find()` in loop | O(n²) | Build `Map` first |
| Sequential `await` | O(n) when O(1) | `Promise.all` |
| Regex in function | Recompiled each call | Hoist to module level |
| `string += ...` in loop | O(n²) | Array + `join()` |
| Chained `.filter().map()` | Multiple passes | Single `for` loop |
| `readFile` per request | I/O on hot path | Cache result |

---

## When to Optimize

1. **Measure first**: Use `--prof` or benchmarks
2. **Hot paths only**: Don't optimize cold code
3. **Algorithmic first**: O(n) beats micro-optimization
4. **Document why**: Optimized code is less readable

```javascript
// Document optimizations
// Using Map for O(1) lookup - processing 10k+ orders per request
const customerMap = new Map(customers.map(c => [c.id, c]));
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `for (x) { arr.find() }` | O(n²) | Build Map first |
| `await a; await b; await c;` | Sequential | `Promise.all([a, b, c])` |
| `new RegExp()` in function | Recompiled | Module-level constant |
| `str += ...` in loop | O(n²) string copies | Array + join |
| `.filter().map().filter()` | 3 array copies | Single loop |
| `readFile` on each request | Repeated I/O | Cache or read at startup |
