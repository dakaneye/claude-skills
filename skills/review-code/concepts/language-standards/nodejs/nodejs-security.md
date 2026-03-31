# Node.js Security Patterns

> Child process safety, input validation, eval dangers, and ReDoS prevention.

## Child Process Safety

```javascript
// WRONG: Command injection vulnerability
import { exec } from 'node:child_process';

function searchFiles(pattern) {
  exec(`grep -r "${pattern}" ./src`);  // Shell injection!
}

// RIGHT: Use execFile with argument array
import { execFile } from 'node:child_process';

function searchFiles(pattern) {
  execFile('grep', ['-r', pattern, './src']);  // No shell
}

// RIGHT: Or use spawn with explicit shell: false
import { spawn } from 'node:child_process';

const proc = spawn('grep', ['-r', pattern, './src'], {
  shell: false  // Explicit (default, but be clear)
});
```

## Never Use eval

```javascript
// WRONG: Dynamic code execution
const config = eval(configString);
const fn = new Function('x', userCode);

// RIGHT: Use JSON for data
const config = JSON.parse(configString);

// RIGHT: Use a sandbox if dynamic code is required
import { VM } from 'vm2';  // Or similar sandbox
const vm = new VM({ sandbox: {} });
vm.run(userCode);
```

## Input Validation

```javascript
// WRONG: Trust and use
function processUserData(data) {
  return query(`SELECT * FROM users WHERE id = ${data.id}`);
}

// RIGHT: Validate shape and type
import { z } from 'zod';  // Or similar

const UserInput = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100),
  email: z.string().email()
});

function processUserData(data) {
  const validated = UserInput.parse(data);  // Throws if invalid
  return query('SELECT * FROM users WHERE id = ?', [validated.id]);
}
```

## Regex DoS Prevention

```javascript
// WRONG: Catastrophic backtracking
const emailRegex = /^([a-zA-Z0-9]+)+@example\.com$/;
'a'.repeat(25) + '!';  // Hangs

// RIGHT: Avoid nested quantifiers
const emailRegex = /^[a-zA-Z0-9]+@example\.com$/;

// RIGHT: Use safe-regex to check patterns
import safeRegex from 'safe-regex';
if (!safeRegex(pattern)) {
  throw new Error('Potentially unsafe regex pattern');
}
```

## Path Traversal Prevention

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

## Security Checklist

### Input Handling
- [ ] All user input validated before use
- [ ] Schema validation (zod, ajv) at API boundaries
- [ ] Path traversal checks for file operations
- [ ] SQL parameterized queries (no string interpolation)

### Code Execution
- [ ] No `eval()` with any user-influenced data
- [ ] No `new Function()` with user input
- [ ] `execFile` over `exec` (no shell interpolation)
- [ ] `shell: false` explicit on spawn/execFile

### Pattern Matching
- [ ] No nested quantifiers in regex (`(a+)+`)
- [ ] Use `safe-regex` to validate user-provided patterns
- [ ] Set timeouts on regex operations with large inputs

### Dependencies
- [ ] Regular `npm audit` checks
- [ ] Pin versions or use lockfile
- [ ] Minimal dependencies (each is attack surface)

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `exec(userInput)` | Command injection | Use `execFile` with array |
| `eval(json)` | Code execution | Use `JSON.parse()` |
| `new Function(userCode)` | Code execution | Use sandbox (vm2) |
| `query(... + id)` | SQL injection | Parameterized queries |
| `(a+)+` regex | ReDoS | Avoid nested quantifiers |
| `path.join(base, userInput)` | Path traversal | Validate resolved path |
