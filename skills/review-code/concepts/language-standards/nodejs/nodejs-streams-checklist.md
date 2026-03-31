# STREAMS Checklist for Node.js Code Review

> Quick reference mnemonic for Node.js code review. Load focused files for deep patterns.

## The STREAMS Checklist

- **S**ecurity: Input validation, no eval, safe child_process
- **T**ypes: JSDoc annotations, explicit return types, null checks
- **R**euse: Use stdlib (node:*), don't reinvent path/url parsing
- **E**rrors: Proper async error handling, no swallowed rejections
- **A**sync: Correct await patterns, Promise.all for parallel work
- **M**odules: ESM with node: protocol, proper exports field
- **S**implicity: No over-abstraction, match existing patterns

---

## Quick Reference by Section

### Security
- [ ] No `eval()` or `new Function()` with user input
- [ ] `execFile` over `exec` for child processes
- [ ] Path traversal checks for user-provided paths
- [ ] Input validation with schema library (zod, ajv)
- [ ] Regex patterns checked for ReDoS

### Types
- [ ] JSDoc annotations on public functions
- [ ] `@ts-check` enabled in critical files
- [ ] Explicit null/undefined handling
- [ ] Return types documented

### Reuse
- [ ] `node:` protocol for built-in imports
- [ ] Standard library used (URL, path, etc.)
- [ ] npm-package-arg for package parsing
- [ ] node:test for testing (not heavyweight frameworks)

### Errors
- [ ] Async errors propagate (not swallowed)
- [ ] Error cause chain preserved (`{ cause: error }`)
- [ ] No bare `catch {}` blocks
- [ ] Unhandled rejection handler for top-level

### Async
- [ ] `Promise.all` for parallel independent work
- [ ] `Promise.allSettled` when partial results needed
- [ ] Streams for large data processing
- [ ] AbortController for cancellation

### Modules
- [ ] `"type": "module"` in package.json
- [ ] Proper `exports` field configured
- [ ] `engines` field specifies Node version
- [ ] `import.meta.dirname` over `__dirname`

### Simplicity
- [ ] No `utils.js` dumping grounds
- [ ] No over-abstraction (YAGNI)
- [ ] No premature caching/optimization
- [ ] Matches existing project patterns
- [ ] String replacements use `/g` flag or `replaceAll()`

---

## Focused Files

Load these for deep patterns:

| File | When to Load |
|------|--------------|
| `nodejs-errors.md` | Async error handling, Promise patterns |
| `nodejs-modules.md` | ESM, imports, path handling |
| `nodejs-types.md` | JSDoc, type safety, null checks |
| `nodejs-stdlib.md` | Built-in APIs, streams |
| `nodejs-security.md` | Input validation, child_process, ReDoS |
| `nodejs-testing.md` | node:test patterns |
| `nodejs-ai-antipatterns.md` | AI code smells, DRY |
| `nodejs-performance.md` | O(n²) patterns, async efficiency |
