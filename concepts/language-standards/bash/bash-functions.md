---
title: Bash Functions
topics:
  - local variables
  - namerefs
  - documentation
  - testable structure
version_requirements: Bash 4.0+ (4.3+ for nameref)
---

# Bash Functions

> Local variables, namerefs, documentation, and testable structure.

## Functions Without Local Variables

```bash
# ❌ WRONG: Polluting global scope
calculate_total() {
    sum=0  # Overwrites global $sum!
    for item in "$@"; do
        sum=$((sum + item))
    done
    echo "$sum"
}

result=$(calculate_total 10 20 30)
echo "Sum is $sum"  # $sum is now 60 globally

# ✅ RIGHT: Scoped variables, explicit return via stdout
calculate_total() {
    local sum=0
    local item

    for item in "$@"; do
        (( sum += item ))
    done

    echo "$sum"  # Return value via stdout
}

result=$(calculate_total 10 20 30)
echo "Sum is $result"
```

---

## Nameref Pattern (Bash 4.3+)

```bash
# Return via reference for complex data or avoiding subshell
calculate_total_ref() {
    local -n result_ref=$1  # Nameref to caller's variable
    shift

    local sum=0
    local item

    for item in "$@"; do
        (( sum += item ))
    done

    result_ref=$sum  # Set caller's variable
}

# Usage
calculate_total_ref total 10 20 30
echo "Sum is $total"
```

---

## Function Documentation

```bash
# parse_config - Parse configuration file into associative array
#
# Reads a config file in KEY=VALUE format and populates an
# associative array. Supports comments (#) and empty lines.
#
# Arguments:
#   $1 - Path to configuration file
#   $2 - Name of associative array to populate (nameref)
#
# Returns:
#   0 on success, 1 on error
#
# Example:
#   declare -A config
#   parse_config "/etc/app.conf" config
#   echo "${config[database_host]}"
parse_config() {
    local config_file="$1"
    local -n config_array="$2"

    [[ -f "$config_file" ]] || {
        echo "Error: Config file not found: $config_file" >&2
        return 1
    }

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Trim whitespace
        key="${key#"${key%%[![:space:]]*}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        config_array["$key"]="$value"
    done < "$config_file"
}
```

---

## Testable Script Structure

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Business logic in functions
calculate_checksum() {
    local file="$1"
    # NOTE: sha256sum is GNU coreutils; macOS uses: shasum -a 256
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
}

validate_file() {
    local file="$1"

    [[ -f "$file" ]] || {
        echo "Error: File not found: $file" >&2
        return 1
    }

    [[ -r "$file" ]] || {
        echo "Error: File not readable: $file" >&2
        return 1
    }

    return 0
}

# Main logic
main() {
    local file="${1:-}"

    [[ -n "$file" ]] || {
        echo "Usage: $0 <file>" >&2
        return 1
    }

    validate_file "$file" || return 1

    local checksum
    checksum=$(calculate_checksum "$file")
    echo "$checksum"
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi
```

---

## Script Headers

```bash
#!/usr/bin/env bash
#
# Script: process_logs.sh
# Description: Process and analyze application logs
# Usage: process_logs.sh [OPTIONS] <log_file>
#
# Options:
#   -v, --verbose    Enable verbose output
#   -o, --output     Output file (default: stdout)
#   -h, --help       Show this help message
#
# Examples:
#   process_logs.sh app.log
#   process_logs.sh -v -o report.txt app.log
#
# Requirements:
#   - Bash 4.4+
#   - jq (for JSON parsing)
#
# Author: Your Name
# Version: 1.0.0

set -Eeuo pipefail
```

---

## Return Values

```bash
# Pattern 1: Return via stdout (captured with $())
get_value() {
    echo "result"
}
value=$(get_value)

# Pattern 2: Return via exit status
is_valid() {
    [[ "$1" =~ ^[0-9]+$ ]]
}
if is_valid "$input"; then
    echo "Valid"
fi

# Pattern 3: Return via nameref (no subshell)
get_data() {
    local -n result=$1
    result="computed value"
}
get_data my_var
echo "$my_var"

# Pattern 4: Return via global (discouraged, but sometimes useful)
LAST_ERROR=""
operation() {
    LAST_ERROR="Something failed"
    return 1
}
```

---

---

## Version Requirements

| Feature | Minimum Version |
|---------|-----------------|
| `local` keyword | Bash 2.0 |
| Nameref (`local -n`) | Bash 4.3 |
| `declare -g` (explicit global) | Bash 4.2 |
| `BASH_SOURCE` array | Bash 3.0 |

---

## Quick Reference

| Pattern | Wrong | Right |
|---------|-------|-------|
| Function variables | `var=x` | `local var=x` |
| Return value | Global variable | `echo` + capture with `$()` |
| Complex return | Multiple globals | Nameref: `local -n ref=$1` (Bash 4.3+) |
| Script entry | Run immediately | Guard with `[[ "${BASH_SOURCE[0]}" = "${0}" ]]` |
| Documentation | None | Comment block with arguments, returns, examples |
| Portable checksum | `sha256sum` only | Detect and use `shasum -a 256` on macOS |
