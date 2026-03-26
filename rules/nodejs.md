---
globs: "*.{js,ts,mjs,cjs}"
---

# Node.js Quality Rules (STREAMS)

## Checklist

### S - Security
- `[BLOCKER]` No `eval()` or `new Function()` with user input
- `[BLOCKER]` `execFile` over `exec` for child processes
- `[MAJOR]` Path traversal checks for user-provided paths
- `[MAJOR]` Regex patterns checked for ReDoS

### T - Types
- `[MAJOR]` JSDoc annotations on public functions
- `[MAJOR]` Explicit null/undefined handling
- `[MINOR]` `@ts-check` enabled in critical files

### R - Reuse
- `[MAJOR]` `node:` protocol for built-in imports
- `[MAJOR]` Standard library used (URL, path, etc.) — don't reinvent
- `[MAJOR]` `npm-package-arg` for package parsing, not custom regex
- `[MAJOR]` `node:test` for testing (not heavyweight frameworks)

### E - Errors
- `[BLOCKER]` Async errors propagate (not swallowed)
- `[MAJOR]` Error cause chain preserved (`{ cause: error }`)
- `[MAJOR]` No bare `catch {}` blocks

### A - Async
- `[MAJOR]` `Promise.all` for parallel independent work
- `[MAJOR]` `Promise.allSettled` when partial results needed
- `[MAJOR]` AbortController for cancellation

### M - Modules
- `[MAJOR]` `"type": "module"` in package.json
- `[MAJOR]` Proper `exports` field configured
- `[MINOR]` `import.meta.dirname` over `__dirname`

### S - Simplicity
- `[MAJOR]` No `utils.js` dumping grounds — use specific module names
- `[MAJOR]` No over-abstraction (YAGNI)
- `[MAJOR]` String replacements use `/g` flag or `replaceAll()`
- `[MAJOR]` Matches existing project patterns

## AI Detection Signals

| Signal | Severity | What to Look For |
|--------|----------|------------------|
| `utils.js` created | MAJOR | Dumping ground for trivial helpers |
| Factory/Manager/Service suffix | MAJOR | Over-abstraction — use direct class/function |
| Unused config options | MAJOR | Premature flexibility |
| Cache without TTL/invalidation | BLOCKER | Memory leak — premature optimization |
| Custom npm format parsing | MAJOR | Reinventing `npm-package-arg` |
| `.replace(str, str)` | MAJOR | Only first occurrence — use `.replaceAll()` or `/g` |
| Duplicated conditionals | MAJOR | Poor method layering — DRY violation |
| Comments describing unimplemented features | BLOCKER | AI hallucination |
| `exec()` with string interpolation | BLOCKER | Command injection — use `execFile` |
| TOCTOU file checks | MAJOR | `existsSync` then `readFileSync` — use try/catch |

## Top 3 Anti-Pattern Examples

### Over-abstraction
```javascript
// BAD
class UserRepositoryFactory {
  createRepository(type) { switch (type) { case 'postgres': ... } }
}
// You only have one database. YAGNI.

// GOOD
class UserRepository {
  constructor(db) { this.db = db; }
  async find(id) { return this.db.query('SELECT ...', [id]); }
}
```

### String replace without global flag
```javascript
// BAD — only replaces first occurrence
const escaped = input.replace('%20', ' ');

// GOOD
const escaped = input.replaceAll('%20', ' ');
// OR: input.replace(/%20/g, ' ');
```

### DRY violation — duplicated conditionals
```javascript
// BAD
function formatName(pkg) {
  return pkg.scope ? `@${pkg.scope}/${pkg.name}` : pkg.name;
}
function formatPurl(pkg) {
  if (pkg.scope) return `pkg:npm/@${pkg.scope}/${pkg.name}@${pkg.version}`;
  return `pkg:npm/${pkg.name}@${pkg.version}`;
}

// GOOD — layer methods
function formatName(pkg) { return pkg.scope ? `@${pkg.scope}/${pkg.name}` : pkg.name; }
function formatCoordinates(pkg) { return `${formatName(pkg)}@${pkg.version}`; }
function formatPurl(pkg) { return `pkg:npm/${formatCoordinates(pkg)}`; }
```

## Deep Dives
See `~/.claude/skills/review-code/` (nodejs-*.md files) for focused files on errors, modules, types, stdlib, security, testing, AI anti-patterns, and performance.
