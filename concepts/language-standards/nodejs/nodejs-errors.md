# Node.js Error Handling Patterns

> Async/await error handling, Promise patterns, and error propagation.

## Async/Await Error Propagation

```javascript
// WRONG: Swallowed rejection
async function fetchData(url) {
  try {
    const response = await fetch(url);
    return await response.json();
  } catch (error) {
    console.error('Failed:', error);
    // Returns undefined - caller has no idea it failed
  }
}

// RIGHT: Let errors propagate or handle explicitly
async function fetchData(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${url}`);
  }
  return response.json();
}
```

## Error-First Callback to Promise

```javascript
// WRONG: Manual promisification
function readFileAsync(path) {
  return new Promise((resolve, reject) => {
    fs.readFile(path, (err, data) => {
      if (err) reject(err);
      else resolve(data);
    });
  });
}

// RIGHT: Use built-in promises
import { readFile } from 'node:fs/promises';
const data = await readFile(path);

// Or use promisify for legacy APIs
import { promisify } from 'node:util';
const execAsync = promisify(exec);
```

## Error Context Wrapping

```javascript
// WRONG: Loses original stack trace
try {
  await processFile(path);
} catch (error) {
  throw new Error('Processing failed');
}

// WRONG: Redundant "failed to" prefix (Java energy)
throw new Error(`Failed to process file: ${error.message}`);

// RIGHT: Preserve cause, state action directly
try {
  await processFile(path);
} catch (error) {
  throw new Error(`process file ${path}`, { cause: error });
}
```

## Unhandled Rejection Handling

```javascript
// WRONG: Fire-and-forget async in sync context
function handleRequest(req, res) {
  processAsync(req.body);  // Rejection goes nowhere
  res.send('OK');
}

// RIGHT: Handle or propagate
async function handleRequest(req, res) {
  try {
    await processAsync(req.body);
    res.send('OK');
  } catch (error) {
    res.status(500).send('Processing failed');
  }
}
```

---

## Async/Await Patterns

### Sequential vs Parallel Execution

```javascript
// WRONG: Sequential when parallel is possible
async function fetchAll(urls) {
  const results = [];
  for (const url of urls) {
    results.push(await fetch(url));  // One at a time!
  }
  return results;
}

// RIGHT: Parallel execution
async function fetchAll(urls) {
  return Promise.all(urls.map(url => fetch(url)));
}

// RIGHT: Controlled concurrency for many items
import pLimit from 'p-limit';
const limit = pLimit(5);

async function fetchAll(urls) {
  return Promise.all(urls.map(url => limit(() => fetch(url))));
}
```

### Promise.all Error Handling

```javascript
// WRONG: One failure loses all results
const results = await Promise.all(tasks.map(processTask));

// RIGHT: Use allSettled when you need partial results
const results = await Promise.allSettled(tasks.map(processTask));

const succeeded = results
  .filter(r => r.status === 'fulfilled')
  .map(r => r.value);

const failed = results
  .filter(r => r.status === 'rejected')
  .map(r => r.reason);
```

### Async Iterator Patterns

```javascript
// WRONG: Collecting all then processing
const lines = (await readFile(path, 'utf8')).split('\n');
for (const line of lines) {
  await processLine(line);
}

// RIGHT: Stream processing for large files
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';

const rl = createInterface({
  input: createReadStream(path),
  crlfDelay: Infinity
});

for await (const line of rl) {
  await processLine(line);
}
```

---

## Anti-Pattern Summary

| Pattern | Problem | Fix |
|---------|---------|-----|
| `catch { console.error() }` | Swallows error, returns undefined | Re-throw or handle explicitly |
| `new Promise((resolve, reject) => ...)` | Manual promisification | Use `node:fs/promises` or `promisify` |
| `throw new Error('Failed: ' + msg)` | Loses stack trace | Use `{ cause: error }` |
| `processAsync(x)` without await | Unhandled rejection | Always await or attach `.catch()` |
| Sequential `await` in loop | O(n) when O(1) possible | Use `Promise.all` |
