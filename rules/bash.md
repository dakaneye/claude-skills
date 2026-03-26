---
globs: "*.sh"
---

# Bash Quality Rules (VEST)

## Checklist

### V - Variables
- `[BLOCKER]` All expansions quoted: `"$var"` not `$var`
- `[BLOCKER]` Arrays use `"${arr[@]}"` not `$arr`
- `[MAJOR]` Function variables are `local`
- `[MAJOR]` Required vars checked: `${VAR:?error}`

### E - Errors
- `[BLOCKER]` Script starts with `set -Eeuo pipefail`
- `[BLOCKER]` `trap` handles cleanup on EXIT
- `[MAJOR]` Error messages go to stderr: `>&2`
- `[MAJOR]` Failed commands have context: `|| { echo "Error: ..." >&2; exit 1; }`
- `[MAJOR]` Temp files cleaned up in trap

### S - Security
- `[BLOCKER]` User inputs validated (regex/allowlist)
- `[BLOCKER]` No `eval` — EVER (use arrays for dynamic commands)
- `[BLOCKER]` Option injection prevented with `--`
- `[MAJOR]` Paths sanitized (no traversal)
- `[MAJOR]` Temp files via `mktemp`, not predictable names

### T - Testing
- `[BLOCKER]` Loops don't parse `ls` output
- `[MAJOR]` Uses `[[` not `[` for conditionals
- `[MAJOR]` ShellCheck warnings addressed
- `[MAJOR]` Script sourceable without executing: `[[ "${BASH_SOURCE[0]}" = "${0}" ]]`

### Basics
- `[BLOCKER]` Shebang is `#!/usr/bin/env bash`
- `[MAJOR]` Works on Linux and macOS (GNU vs BSD differences handled)

## AI Detection Signals

| Signal | Severity | ShellCheck | What to Look For |
|--------|----------|------------|------------------|
| Backticks `` `cmd` `` | MAJOR | SC2006 | Old style — use `$(cmd)` |
| `for f in $(ls)` | BLOCKER | SC2045 | Parsing ls output — use glob or find |
| `echo -e` / `echo -n` | MAJOR | SC2028 | Not portable — use `printf` |
| `cat file \| cmd` | MINOR | SC2002 | UUOC — use `< file cmd` or `cmd file` |
| No `set -euo pipefail` | BLOCKER | — | Missing strict mode |
| No `local` in functions | MAJOR | SC2034 | Global variable pollution |
| `if [ $var = x ]` | BLOCKER | SC2086 | Unquoted — use `[[ "$var" = x ]]` |
| External cmd for strings | MAJOR | SC2001 | Use `${var//old/new}` expansion |
| `cd` without `\|\| exit` | MAJOR | SC2164 | May continue in wrong directory |
| Mixed declare and assign | MAJOR | SC2155 | Masks return value — separate them |
| Subshell in loop body | MAJOR | — | Fork+exec each iteration |
| Over-commenting obvious code | MINOR | — | `# Exit if error` on `exit 1` |

## Top 3 Anti-Pattern Examples

### Parsing ls output
```bash
# BAD — word splitting, globbing bugs
for file in $(ls *.txt); do process "$file"; done

# GOOD
for file in *.txt; do
    [[ -e "$file" ]] || continue
    process "$file"
done
```

### External commands for string operations
```bash
# BAD — spawns subshell for trivial ops
basename=$(echo "$path" | sed 's|.*/||')
extension=$(echo "$file" | awk -F. '{print $NF}')

# GOOD — built-in parameter expansion
basename="${path##*/}"
extension="${file##*.}"
```

### Subshell in loop body
```bash
# BAD — fork+exec on every line
while read -r line; do
    result=$(echo "$line" | grep -o 'pattern')
done < file.txt

# GOOD — built-in regex
while read -r line; do
    if [[ "$line" =~ pattern ]]; then
        echo "${BASH_REMATCH[0]}"
    fi
done < file.txt
```

## Deep Dives
See `~/.claude/concepts/language-standards/bash/` for focused files on variables, errors, security, conditionals, loops, functions, portability, testing, and AI anti-patterns.
