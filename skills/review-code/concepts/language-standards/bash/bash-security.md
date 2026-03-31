---
title: Bash Security Patterns
topics:
  - input validation
  - command injection
  - option injection
  - path traversal
  - temporary files
severity: BLOCKER - security issues must be fixed
---

# Bash Security Patterns

> Input validation, injection prevention, and safe file handling.

## Unsafe Input Handling

```bash
# ❌ WRONG: Command injection, no validation, eval danger
user_input="$1"
eval "$user_input"  # CRITICAL SECURITY HOLE — NEVER DO THIS

# Unsafe command construction
filename="$1"
rm $filename  # Command injection if filename="important; rm -rf /"

# No validation
port="$1"
nc -l "$port"  # What if port is "80; malicious_command"?

# ✅ RIGHT: Validate inputs, NEVER USE EVAL, use arrays for commands
filename="$1"

# Validate: only alphanumeric, dash, underscore, dot
if [[ ! "$filename" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: Invalid filename format" >&2
    exit 1
fi

# Safe removal with validation and --
rm -f -- "$filename"

# Numeric validation
port="$1"
if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
    echo "Error: Port must be between 1024-65535" >&2
    exit 1
fi
nc -l "$port"

# Dynamic commands: use arrays, NEVER eval
if [[ "$verbose" = "true" ]]; then
    cmd=(curl -v)
else
    cmd=(curl -s)
fi
"${cmd[@]}" https://example.com
```

### ⚠️ EVAL IS FORBIDDEN

**NEVER USE `eval`. Period.** There is no safe way to use `eval` with variable input in AI-generated code.

| If you think you need... | Use this instead |
|--------------------------|------------------|
| Dynamic command building | Arrays: `cmd=(arg1 arg2); "${cmd[@]}"` |
| Variable variable names | Associative arrays: `declare -A data; data[$key]=$value` |
| Dynamic property access | Nameref: `declare -n ref=$varname` (Bash 4.3+) |
| Command from string | Direct execution with validation |

**Why**: `eval` executes arbitrary code. Even "sanitized" input can be exploited. Arrays solve 99% of legitimate use cases for dynamic commands.

---

## Input Validation Pattern

```bash
validate_port() {
    local port="$1"

    # Check format
    [[ "$port" =~ ^[0-9]+$ ]] || {
        echo "Error: Port must be numeric" >&2
        return 1
    }

    # Check range
    (( port >= 1024 && port <= 65535 )) || {
        echo "Error: Port must be between 1024-65535" >&2
        return 1
    }

    return 0
}

# Usage
port="$1"
validate_port "$port" || exit 1
start_server "$port"
```

---

## Prevent Option Injection

**Use `--` to separate options from arguments:**

```bash
# User input could be "-rf" or "--help"
filename="$1"

# ❌ WRONG: treats filename as option if it starts with -
rm "$filename"

# ✅ RIGHT: -- signals end of options
rm -f -- "$filename"

# Also applies to other commands
grep -r "$pattern" -- "$file"
git checkout -- "$file"
```

---

## Sanitize Paths

**Prevent path traversal:**

```bash
sanitize_path() {
    local base_dir="$1"
    local user_path="$2"

    # Resolve to absolute path
    local resolved
    resolved=$(realpath -m "$base_dir/$user_path") || {
        echo "Error: Invalid path" >&2
        return 1
    }

    # Ensure it's within base_dir
    [[ "$resolved" = "$base_dir"* ]] || {
        echo "Error: Path traversal detected" >&2
        return 1
    }

    echo "$resolved"
}

# Usage
safe_path=$(sanitize_path "/var/data" "$user_input") || exit 1
process_file "$safe_path"
```

---

## Secure Temporary Files

```bash
# ❌ WRONG: Predictable temp file (security issue)
tmpfile="/tmp/myapp.$$"

# ✅ RIGHT: Secure temp creation
tmpfile=$(mktemp) || {
    echo "Error: Failed to create temporary file" >&2
    exit 1
}

# Guarantee cleanup
trap 'rm -f "$tmpfile"' EXIT
```

**Why**: Predictable temp paths allow attackers to exploit race conditions. `mktemp` creates unpredictable names with secure permissions.

---

## Quick Reference

| Threat | Wrong | Right |
|--------|-------|-------|
| Command injection | `eval "$input"` | NEVER USE EVAL — use arrays |
| Option injection | `rm "$file"` | `rm -f -- "$file"` |
| Path traversal | Direct use of `$user_path` | `sanitize_path()` |
| Temp file races | `/tmp/app.$$` | `mktemp` |
| Unvalidated input | Use directly | Regex/allowlist validation |

**Note**: `realpath` requires GNU coreutils 8.15+ or macOS 10.15+. For older systems, use Python fallback or manual path resolution.

---

## Validation Patterns

```bash
# Alphanumeric only
[[ "$input" =~ ^[a-zA-Z0-9]+$ ]]

# Filename safe (letters, numbers, dash, underscore, dot)
[[ "$input" =~ ^[a-zA-Z0-9._-]+$ ]]

# Numeric
[[ "$input" =~ ^[0-9]+$ ]]

# IP address (basic)
[[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]

# URL (basic)
[[ "$input" =~ ^https?:// ]]
```
