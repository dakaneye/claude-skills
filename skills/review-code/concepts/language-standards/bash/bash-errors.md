---
title: Bash Error Handling
topics:
  - strict mode
  - error traps
  - debugging
  - signal handling
  - temporary files
version_requirements: Bash 4.0+ (4.4+ for inherit_errexit)
---

# Bash Error Handling

> Strict mode, traps, debugging, and contextual error messages.

## Missing Error Handling

```bash
# ❌ WRONG: Silent failures, unclear error context
#!/bin/bash
# No error handling, continues on failures
cd /some/path
rm important_file
curl https://api.example.com/data > output.json

# ✅ RIGHT: Strict mode, error trapping, contextual messages
#!/usr/bin/env bash
set -Eeuo pipefail  # Exit on error, undefined vars, pipe failures

# Error trap for stack trace
trap 'error_handler $? $LINENO' ERR

error_handler() {
    local exit_code=$1
    local line_number=$2
    echo "Error: Command failed at line $line_number with exit code $exit_code" >&2
    exit "$exit_code"
}

# Always add context to errors
cd /some/path || {
    echo "Error: Failed to change to directory /some/path" >&2
    exit 1
}

rm important_file || {
    echo "Error: Failed to remove important_file" >&2
    exit 1
}

curl -fsSL https://api.example.com/data > output.json || {
    echo "Error: Failed to fetch data from API" >&2
    exit 1
}
```

**Why**: Bash continues executing after errors by default.

---

## set Options Explained

```bash
set -Eeuo pipefail
```

| Option | Effect |
|--------|--------|
| `-e` | Exit immediately when command fails |
| `-E` | Inherit ERR trap in functions/subshells |
| `-u` | Treat unset variables as errors |
| `-o pipefail` | Fail pipelines if any command fails (not just last) |

**Caveats with `set -e`:**
- ERR trap does NOT trigger in `if` conditions: `if cmd; then` won't trap even if `cmd` fails
- ERR trap does NOT trigger in `while`/`until` tests
- Commands in `&&` or `||` chains don't trigger ERR trap if expected to fail
- **Bash 4.4+**: Use `shopt -s inherit_errexit` for better subshell error propagation

---

## Unsafe Temporary Files

```bash
# ❌ WRONG: Predictable paths, race conditions, no cleanup
tmpfile="/tmp/myapp.$$"
echo "data" > "$tmpfile"
# Oops, script crashes, file never cleaned up
process "$tmpfile"
rm "$tmpfile"

# ✅ RIGHT: Secure temp creation with guaranteed cleanup
tmpfile=$(mktemp) || {
    echo "Error: Failed to create temporary file" >&2
    exit 1
}

# Guarantee cleanup even on errors
trap 'rm -f "$tmpfile"' EXIT

echo "data" > "$tmpfile"
process "$tmpfile"
# No manual rm needed - trap handles it
```

**Why**: Predictable temp paths allow attackers to exploit race conditions. `mktemp` creates unpredictable names with secure permissions. `trap EXIT` guarantees cleanup even if the script crashes.

---

## Process Management & Signals

```bash
# Proper signal handling
cleanup() {
    echo "Cleaning up..." >&2
    # Kill background jobs (NOTE: xargs -r is GNU-only, not available on macOS)
    # Portable alternative:
    local pids
    pids=$(jobs -p)
    if [[ -n "$pids" ]]; then
        kill $pids 2>/dev/null || true
    fi
    # Remove temp files
    rm -rf "$tmpdir"
}

trap cleanup EXIT INT TERM

# Start background processes
tmpdir=$(mktemp -d)
long_running_task &
pid1=$!
another_task &
pid2=$!

# Wait for specific process
wait "$pid1" || {
    echo "Error: long_running_task failed" >&2
    exit 1
}

# Wait for all background jobs
wait
```

---

## Error Pattern Reference

```bash
# Pattern: Command with error context
command || {
    echo "Error: Descriptive message" >&2
    exit 1
}

# Pattern: Error trap for debugging
trap 'echo "Error at line $LINENO: $BASH_COMMAND" >&2' ERR

# Pattern: Cleanup on any exit
trap cleanup EXIT

# Pattern: Check command success
if ! command; then
    echo "Error: command failed" >&2
    exit 1
fi
```

---

---

## Debugging Techniques

```bash
# Enable trace mode (prints each command before execution)
set -x

# Custom trace prefix showing file, line, and function
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# Debug trap for stepping through commands
trap 'echo "DEBUG: $BASH_COMMAND" >&2' DEBUG

# Opt-in trace mode via flag
if [[ "${TRACE:-}" = "1" ]]; then
    set -x
fi

# Verbose mode pattern
VERBOSE="${VERBOSE:-0}"
debug() {
    (( VERBOSE )) && echo "[DEBUG] $*" >&2
}

# Temporarily disable strict mode when expecting failures
set +e
possibly_failing_command
exit_code=$?
set -e
if (( exit_code != 0 )); then
    echo "Command failed with code $exit_code" >&2
fi
```

---

## Quick Reference

| Pattern | Wrong | Right |
|---------|-------|-------|
| Script start | `#!/bin/bash` | `#!/usr/bin/env bash` + `set -Eeuo pipefail` |
| Temp files | `/tmp/app.$$` | `mktemp` + `trap EXIT` |
| Error messages | `echo "error"` | `echo "Error: ..." >&2` |
| Command failure | silent | `|| { echo "msg" >&2; exit 1; }` |
| Cleanup | manual `rm` | `trap cleanup EXIT` |
| Kill background jobs | `jobs -p \| xargs -r kill` | Check if pids exist first (portable) |
| Debug mode | Always on | Opt-in via `TRACE=1` or `--debug` flag |
