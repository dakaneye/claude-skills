---
title: Bash Portability
topics:
  - GNU vs BSD
  - shebang selection
  - platform detection
  - POSIX compliance
version_requirements: Document minimum Bash version in script headers
---

# Bash Portability

> GNU vs BSD, shebang selection, and cross-platform patterns.

## Shebang Selection

```bash
# ✅ Prefer env for portability (finds bash in PATH)
#!/usr/bin/env bash

# ❌ Direct path less portable (bash location varies)
#!/bin/bash           # Common on Linux
#!/usr/local/bin/bash # Common on macOS/BSD
```

---

## Bash vs POSIX

**Know when you're using Bash-specific features:**

```bash
# Bash-specific (not POSIX)
[[ ]]                    # Extended test
(( ))                    # Arithmetic
${var:offset:length}     # Substring expansion
${var//pattern/replace}  # Pattern replacement
[[ $str =~ regex ]]      # Regex matching
mapfile/readarray        # Read into array
declare -A assoc         # Associative arrays

# POSIX-compatible alternatives
[ ]              # Basic test (but less safe)
expr             # Arithmetic (external command)
${var#pattern}   # Remove prefix
${var%pattern}   # Remove suffix
case/esac        # Pattern matching
while read       # Read lines
```

---

## Platform Differences

### GNU vs BSD date

```bash
if date --version >/dev/null 2>&1; then
    # GNU date
    yesterday=$(date -d "yesterday" +%Y-%m-%d)
else
    # BSD date (macOS)
    yesterday=$(date -v-1d +%Y-%m-%d)
fi
```

### GNU vs BSD sed

```bash
if sed --version >/dev/null 2>&1; then
    # GNU sed
    sed -i 's/old/new/' file
else
    # BSD sed requires empty string for -i
    sed -i '' 's/old/new/' file
fi

# ✅ Portable approach: avoid -i, use temp file
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
sed 's/old/new/' file > "$tmp" && mv "$tmp" file
```

### GNU vs BSD readlink

```bash
# GNU readlink -f (canonical path)
# BSD readlink doesn't support -f

# Portable alternative
if command -v realpath >/dev/null 2>&1; then
    full_path=$(realpath "$path")
else
    # Python fallback
    full_path=$(python3 -c "import os; print(os.path.realpath('$path'))")
fi
```

### GNU vs BSD stat

```bash
# File size
if stat --version >/dev/null 2>&1; then
    # GNU stat
    size=$(stat -c %s "$file")
else
    # BSD stat
    size=$(stat -f %z "$file")
fi
```

### GNU vs BSD find

```bash
# -print0 works on both, but some options differ

# GNU find: -printf
find . -name "*.txt" -printf '%f\n'

# BSD find: no -printf, use basename in exec
find . -name "*.txt" -exec basename {} \;
```

---

## Feature Detection

```bash
# Check for command existence
command -v jq >/dev/null 2>&1 || {
    echo "Error: jq is required but not installed" >&2
    exit 1
}

# Check Bash version for features
if (( BASH_VERSINFO[0] < 4 )); then
    echo "Error: Bash 4+ required for associative arrays" >&2
    exit 1
fi

# Check for GNU vs BSD
is_gnu() {
    "$1" --version 2>&1 | grep -q GNU
}

if is_gnu date; then
    # Use GNU date syntax
fi
```

---

## Portable Patterns

### Arithmetic

```bash
# Portable (POSIX)
count=$(( count + 1 ))

# Bash-specific but cleaner
(( count++ ))
```

### Conditionals

```bash
# POSIX
if [ "$var" = "value" ]; then

# Bash (safer, more features)
if [[ "$var" = "value" ]]; then
```

### Arrays

```bash
# POSIX: no arrays, use positional parameters
set -- item1 item2 item3
for item in "$@"; do
    echo "$item"
done

# Bash: proper arrays
items=(item1 item2 item3)
for item in "${items[@]}"; do
    echo "$item"
done
```

---

## Documentation Requirements

```bash
#!/usr/bin/env bash
#
# Requirements:
#   - Bash 4.4+ (uses nameref, associative arrays)
#   - GNU coreutils or BSD equivalents
#   - jq 1.6+
#
# Tested on:
#   - Ubuntu 22.04 (GNU)
#   - macOS 13 (BSD)
```

---

---

## Missing Utilities on macOS/BSD

These GNU utilities are NOT available by default on macOS:

| Utility | GNU | macOS Alternative |
|---------|-----|-------------------|
| `timeout` | `timeout 30s cmd` | `gtimeout` (brew) or custom function |
| `readlink -f` | Canonical path | `realpath` or `python3 -c "import os; print(os.path.realpath('$path'))"` |
| `sha256sum` | Checksum | `shasum -a 256` |
| `md5sum` | Checksum | `md5` |
| `grep -P` | PCRE regex | Not available; use `grep -E` or `perl` |
| `xargs -r` | No-run-if-empty | Not available; check if input exists first |
| `numfmt` | Number formatting | Not available; use `awk` or `printf` |
| `tar --transform` | Rename in archive | Not available; use `gtar` (brew) |

### Portable timeout Implementation

```bash
# Portable timeout for macOS/BSD
run_with_timeout() {
    local timeout_secs=$1
    shift

    if command -v timeout &>/dev/null; then
        timeout "${timeout_secs}s" "$@"
    elif command -v gtimeout &>/dev/null; then
        gtimeout "${timeout_secs}s" "$@"
    else
        # Fallback using background job
        "$@" &
        local pid=$!
        ( sleep "$timeout_secs"; kill "$pid" 2>/dev/null ) &
        local killer=$!
        wait "$pid" 2>/dev/null
        local result=$?
        kill "$killer" 2>/dev/null
        return "$result"
    fi
}
```

### Portable xargs (no -r flag)

```bash
# ❌ WRONG: GNU-only
find . -name "*.tmp" -print0 | xargs -0 -r rm

# ✅ RIGHT: Portable (check if input exists)
files=$(find . -name "*.tmp")
if [[ -n "$files" ]]; then
    find . -name "*.tmp" -print0 | xargs -0 rm
fi

# Or use find -exec directly
find . -name "*.tmp" -exec rm {} +
```

---

## Quick Reference

| Feature | GNU | BSD |
|---------|-----|-----|
| sed in-place | `sed -i 's/x/y/'` | `sed -i '' 's/x/y/'` |
| date yesterday | `date -d yesterday` | `date -v-1d` |
| stat file size | `stat -c %s` | `stat -f %z` |
| readlink canonical | `readlink -f` | `realpath` or Python |
| find printf | `find -printf` | Use `-exec basename` |
| timeout | `timeout 30s cmd` | `gtimeout` or custom |
| xargs no-run-if-empty | `xargs -r` | Check input first |
| sha256sum | `sha256sum file` | `shasum -a 256 file` |
| grep PCRE | `grep -P 'pattern'` | `grep -E` or `perl -ne` |

**Portable strategy**: Detect platform with `--version` check, then use appropriate syntax, or use temp file workarounds.
