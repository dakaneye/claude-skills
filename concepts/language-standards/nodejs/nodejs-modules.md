# Node.js Module System & Path Handling

> ESM, CommonJS, node: protocol, and platform-safe path operations.

## node: Protocol Imports

```javascript
// WRONG: Ambiguous imports
import fs from 'fs';
import path from 'path';
import { Buffer } from 'buffer';

// RIGHT: Explicit node: protocol (Node 16+)
import fs from 'node:fs';
import path from 'node:path';
import { Buffer } from 'node:buffer';
```

**Why**: The `node:` protocol makes it explicit you're importing a built-in module, preventing npm packages from shadowing core modules (a security concern).

## ESM vs CommonJS

```javascript
// WRONG: Mixed module systems
const path = require('path');  // CommonJS in ESM file
import { readFile } from 'fs';  // ESM import

// RIGHT: Pure ESM (preferred for new code)
import path from 'node:path';
import { readFile } from 'node:fs/promises';

// When CommonJS is required (legacy compatibility):
// Use dynamic import for ESM from CommonJS
const { default: chalk } = await import('chalk');
```

## Package.json Exports Field

```javascript
// WRONG: Relying on deep imports
import { helper } from 'my-package/lib/internal/helper.js';

// package.json - WRONG: No exports field
{
  "main": "index.js"
}

// RIGHT: Proper exports field
{
  "type": "module",
  "exports": {
    ".": "./src/index.js",
    "./utils": "./src/utils.js"
  },
  "engines": {
    "node": ">=18"
  }
}
```

---

## Path Handling

### Platform-Safe Paths

```javascript
// WRONG: Hardcoded separators
const configPath = baseDir + '/' + 'config.json';
const parts = filepath.split('/');

// RIGHT: Use path module
import path from 'node:path';
const configPath = path.join(baseDir, 'config.json');
const parts = filepath.split(path.sep);
```

### import.meta vs __dirname

```javascript
// WRONG: __dirname in ESM (doesn't exist)
const configPath = path.join(__dirname, 'config.json');

// RIGHT: import.meta.dirname (Node 20.11+)
const configPath = path.join(import.meta.dirname, 'config.json');

// RIGHT: For older Node versions
import { fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
```

### Path Traversal Prevention

```javascript
// WRONG: Trusting user input
const userFile = path.join(uploadDir, req.params.filename);
await readFile(userFile);  // User can pass "../../../etc/passwd"

// RIGHT: Validate resolved path
const userFile = path.join(uploadDir, req.params.filename);
const resolved = path.resolve(userFile);

if (!resolved.startsWith(path.resolve(uploadDir) + path.sep)) {
  throw new Error('Path traversal detected');
}
```

---

## Package.json Best Practices

```json
{
  "name": "@myorg/package",
  "version": "1.0.0",
  "type": "module",
  "engines": {
    "node": ">=18"
  },
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "files": [
    "dist"
  ],
  "scripts": {
    "test": "node --test 'src/**/*.test.js'",
    "lint": "eslint src",
    "prepublishOnly": "npm test && npm run lint"
  }
}
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `import fs from 'fs'` | Ambiguous, can be shadowed | Use `node:fs` |
| `require()` in ESM | Module systems mixed | Use `import` |
| `baseDir + '/' + file` | Platform-specific separator | Use `path.join()` |
| `__dirname` in ESM | Doesn't exist | Use `import.meta.dirname` |
| No `exports` field | Deep imports possible | Define explicit exports |
| No `engines` field | Unknown Node version | Specify `"node": ">=18"` |
