---
title: Bash VEST Checklist
mnemonic: VEST
areas:
  - Variables
  - Errors
  - Security
  - Testing
version_requirements: Bash 4.0+ (4.4+ for advanced features)
---

# Bash VEST Checklist

> Quick reference mnemonic for Bash code review quality checks.

## The VEST Mnemonic

### **V** - Variables
- [ ] `[BLOCKER]` All expansions quoted: `"$var"` not `$var`
- [ ] `[BLOCKER]` Arrays use `"${arr[@]}"` not `$arr`
- [ ] `[MAJOR]` Function variables are `local`
- [ ] `[MAJOR]` Required vars checked: `${VAR:?error}`
- [ ] `[STYLE]` Defaults set: `${VAR:-default}`

### **E** - Errors
- [ ] `[BLOCKER]` Script starts with `set -Eeuo pipefail`
- [ ] `[BLOCKER]` `trap` handles cleanup on EXIT
- [ ] `[MAJOR]` Error messages go to stderr: `>&2`
- [ ] `[MAJOR]` Failed commands have context: `|| { echo "Error: ..."; exit 1; }`
- [ ] `[MAJOR]` Temp files cleaned up in trap

### **S** - Security
- [ ] `[BLOCKER]` User inputs validated (regex/allowlist)
- [ ] `[BLOCKER]` No `eval` — EVER (use arrays for dynamic commands)
- [ ] `[BLOCKER]` Option injection prevented with `--`
- [ ] `[MAJOR]` Paths sanitized (no traversal)
- [ ] `[MAJOR]` Temp files via `mktemp`, not predictable names

### **T** - Testing
- [ ] `[MAJOR]` Functions testable (side-effect free)
- [ ] `[MAJOR]` Script sourceable without executing: `[[ "${BASH_SOURCE[0]}" = "${0}" ]]`
- [ ] `[MAJOR]` Uses `[[` not `[` for conditionals
- [ ] `[BLOCKER]` Loops don't parse `ls` output
- [ ] `[MAJOR]` ShellCheck warnings addressed

---

## Quick Quality Checklist

**Basics:**
- [ ] `[BLOCKER]` Shebang is `#!/usr/bin/env bash`
- [ ] `[BLOCKER]` `set -Eeuo pipefail` at top
- [ ] `[BLOCKER]` All variables quoted
- [ ] `[BLOCKER]` Arrays properly expanded
- [ ] `[MAJOR]` `local` used for function variables

**Error Handling:**
- [ ] `[BLOCKER]` `trap` for cleanup
- [ ] `[MAJOR]` Error context in all failure paths
- [ ] `[MAJOR]` No silent failures
- [ ] `[MAJOR]` Errors to stderr

**Security:**
- [ ] `[BLOCKER]` Inputs validated
- [ ] `[BLOCKER]` No `eval` — EVER
- [ ] `[MAJOR]` Temp files via `mktemp`
- [ ] `[BLOCKER]` Option injection prevented with `--`

**Portability:**
- [ ] `[MAJOR]` Works on Linux and macOS
- [ ] `[STYLE]` Bash version documented if using 4.4+ features
- [ ] `[MAJOR]` Platform differences handled (GNU vs BSD)

**Tools:**
- [ ] `[MAJOR]` ShellCheck passes (all warnings addressed)
- [ ] `[STYLE]` shfmt formatted

---

## The Golden Rules

1. **Always quote variable expansions** unless you explicitly need word splitting
2. **Use `set -Eeuo pipefail`** at the start of every script
3. **Use `[[` for conditionals**, not `[` (unless POSIX required)
4. **Use `local`** for all function variables
5. **Validate all inputs** before using them
6. **Use `mktemp`** for temp files, `trap` for cleanup
7. **Use arrays** for lists, not space-separated strings
8. **Run ShellCheck** and fix all warnings
9. **Use `--`** to prevent option injection
10. **Test your scripts** - write BATS tests for critical logic

## Severity Guide

| Marker | Meaning | Action |
|--------|---------|--------|
| `[BLOCKER]` | Security risk, data loss, or critical bug | MUST fix before merge |
| `[MAJOR]` | Reliability issue, hard-to-debug behavior | SHOULD fix |
| `[STYLE]` | Best practice, maintainability | CONSIDER fixing |

---

## Related Files

For detailed patterns and examples:
- `bash-variables.md` - Quoting, expansion, arrays
- `bash-errors.md` - Error handling, traps, strict mode, debugging
- `bash-security.md` - Input validation, injection prevention
- `bash-conditionals.md` - `[[` vs `[`, numeric comparisons
- `bash-loops.md` - Safe iteration, process substitution
- `bash-functions.md` - Local variables, documentation
- `bash-portability.md` - GNU vs BSD, platform differences
- `bash-testing.md` - BATS framework, mocking, CI integration
- `bash-ai-antipatterns.md` - AI code smells, performance
