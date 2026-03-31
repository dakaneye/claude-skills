# Node.js Standard Library Usage

> Don't reinvent built-ins. Proper use of URL, path, streams, and node:test.

## Don't Reinvent Built-ins

```javascript
// WRONG: Custom URL parsing
function getHostname(urlString) {
  const match = urlString.match(/^https?:\/\/([^\/]+)/);
  return match ? match[1] : null;
}

// RIGHT: Use URL API
function getHostname(urlString) {
  return new URL(urlString).hostname;
}

// WRONG: Custom base64
function toBase64(str) {
  return Buffer.from(str).toString('base64');
}

// RIGHT: For web compatibility, but Buffer is fine in Node
const encoded = Buffer.from(str).toString('base64');
```

## Use Built-in Test Runner

```javascript
// WRONG: Jest for simple Node projects (heavy dependency)
// package.json
{ "devDependencies": { "jest": "^29.0.0" } }

// RIGHT: node:test (Node 18+)
import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

describe('Calculator', () => {
  it('adds numbers correctly', () => {
    assert.equal(add(2, 3), 5);
  });
});
```

## AbortController for Cancellation

```javascript
// WRONG: Custom timeout logic
async function fetchWithTimeout(url, ms) {
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error('Timeout')), ms);
  });

  try {
    return await Promise.race([fetch(url), timeoutPromise]);
  } finally {
    clearTimeout(timeoutId);
  }
}

// RIGHT: AbortController (standard API)
async function fetchWithTimeout(url, ms) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), ms);

  try {
    return await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timeoutId);
  }
}
```

---

## Stream Patterns

### When to Use Streams

```javascript
// WRONG: Loading entire file into memory
const data = await readFile(largePath);
const transformed = transform(data);
await writeFile(outputPath, transformed);

// RIGHT: Stream processing for large files
import { createReadStream, createWriteStream } from 'node:fs';
import { pipeline } from 'node:stream/promises';

await pipeline(
  createReadStream(inputPath),
  transformStream,
  createWriteStream(outputPath)
);
```

### Backpressure Handling

```javascript
// WRONG: Ignoring backpressure
readable.on('data', chunk => {
  writable.write(chunk);  // May buffer indefinitely!
});

// RIGHT: Respect backpressure
import { pipeline } from 'node:stream/promises';

await pipeline(readable, writable);

// Or manually:
readable.on('data', chunk => {
  const canContinue = writable.write(chunk);
  if (!canContinue) {
    readable.pause();
    writable.once('drain', () => readable.resume());
  }
});
```

### Modern Stream Creation

```javascript
// WRONG: Old callback-style transform
const { Transform } = require('stream');

class MyTransform extends Transform {
  _transform(chunk, encoding, callback) {
    callback(null, chunk.toString().toUpperCase());
  }
}

// RIGHT: Async generator for simple transforms
async function* uppercase(source) {
  for await (const chunk of source) {
    yield chunk.toString().toUpperCase();
  }
}

// Use with pipeline
import { Readable } from 'node:stream';
await pipeline(
  inputStream,
  Readable.from(uppercase(inputStream)),
  outputStream
);
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| Custom URL regex | Fragile, incomplete | Use `new URL()` |
| Custom timeout Promise | Complex, error-prone | Use `AbortController` |
| Jest for simple projects | Heavy dependency | Use `node:test` |
| `readFile` for large files | Memory exhaustion | Use streams |
| Ignoring backpressure | Memory leak | Use `pipeline()` |
| `Transform` class | Verbose | Use async generators |
