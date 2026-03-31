---
title: Bash Variables & Expansion
topics:
  - quoting
  - parameter expansion
  - arrays
  - function variables
version_requirements: Bash 4.0+ (4.3+ for nameref)
---

# Bash Variables & Expansion

> Quoting, parameter expansion, and array handling patterns.

## Unquoted Variable Expansions

**The #1 source of Bash bugs.**

```bash
# ❌ WRONG: Word splitting and globbing bugs
files=$1
rm $files  # DANGEROUS: splits on spaces, globs patterns

if [ $status = "success" ]; then  # Breaks if $status is empty
    echo $message  # Word splitting
fi

# ✅ RIGHT: Always quote variable expansions
files="$1"
rm -- "$files"  # Safe: treats as single argument, -- prevents option injection

if [[ "$status" = "success" ]]; then  # [[ handles empty vars safely
    echo "$message"
fi
```

**Why**: Unquoted expansions cause word splitting (spaces become separate arguments) and pathname expansion (globs like `*` expand).

---

## Parameter Expansion Features

```bash
# Default values
${var:-default}        # Use default if var is unset or empty
${var:=default}        # Assign default if var is unset or empty
${var:?error message}  # Exit with error if var is unset or empty
${var:+alternate}      # Use alternate if var is set and non-empty

# String manipulation
${var#pattern}         # Remove shortest match from beginning
${var##pattern}        # Remove longest match from beginning
${var%pattern}         # Remove shortest match from end
${var%%pattern}        # Remove longest match from end
${var/pattern/string}  # Replace first match
${var//pattern/string} # Replace all matches
${var^}                # Uppercase first character
${var^^}               # Uppercase all
${var,}                # Lowercase first character
${var,,}               # Lowercase all

# Length and substrings
${#var}                # Length of string
${var:offset}          # Substring from offset to end
${var:offset:length}   # Substring of length from offset
```

### Practical Examples

```bash
# Required variables with error messages
CONFIG_FILE="${CONFIG_FILE:?Error: CONFIG_FILE environment variable required}"

# Defaults for optional variables
LOG_LEVEL="${LOG_LEVEL:-info}"
TIMEOUT="${TIMEOUT:-30}"

# Extract filename components
filepath="/path/to/file.tar.gz"
dirname="${filepath%/*}"          # /path/to
filename="${filepath##*/}"        # file.tar.gz
basename="${filename%%.*}"        # file
extension="${filename#*.}"        # tar.gz
single_ext="${filename##*.}"      # gz

# Transform strings
name="john_doe"
echo "${name//_/ }"     # john doe (replace _ with space)
echo "${name^^}"        # JOHN_DOE (uppercase)

# Conditional defaults
${DEBUG:+--verbose}     # Expands to --verbose if DEBUG is set, empty otherwise
command ${DEBUG:+--verbose} --output result.txt
```

---

## Array Usage

```bash
# ❌ WRONG: Treating array as string
files=("file1.txt" "file 2.txt" "file3.txt")
for file in $files; do  # Only processes first element, word-splits
    echo "$file"
done

echo $files  # Only prints first element
rm ${files}  # Only removes first element

# Broken array construction
args="--verbose --output result.txt"  # String, not array
mycommand $args  # Word splitting breaks arguments with spaces

# ✅ RIGHT: Proper array operations
files=("file1.txt" "file 2.txt" "file3.txt")
for file in "${files[@]}"; do  # @ expands to separate words
    echo "$file"
done

# Correct expansions
echo "${files[@]}"  # All elements, properly quoted
rm -f -- "${files[@]}"  # Remove all files safely

# Array for command arguments
args=(--verbose --output "result.txt")
mycommand "${args[@]}"  # Preserves argument boundaries

# Read output into array
mapfile -t lines < <(command)  # -t removes trailing newlines

# Array with proper quoting
declare -a packages=(
    "package1"
    "package with spaces"
    "package3"
)
```

**Key insight**: Use `"${array[@]}"` to expand all elements as separate words. `$array` without brackets only references the first element.

### `"${arr[@]}"` vs `"${arr[*]}"`

```bash
arr=("one" "two" "three")

# "${arr[@]}" - Each element becomes a separate word
for item in "${arr[@]}"; do
    echo "Item: $item"
done
# Output: Item: one \n Item: two \n Item: three

# "${arr[*]}" - All elements joined by first char of IFS
IFS=","
echo "${arr[*]}"  # Output: one,two,three

# Practical use: CSV generation
IFS=","
csv="${arr[*]}"
echo "$csv"  # one,two,three
```

**Rule**: Use `"${arr[@]}"` for iteration (99% of cases). Use `"${arr[*]}"` only when joining elements with a delimiter.

---

## Function Variables

```bash
# ❌ WRONG: Global pollution
calculate_total() {
    sum=0  # Overwrites global $sum!
    for item in "$@"; do
        sum=$((sum + item))
    done
    echo "$sum"
}

result=$(calculate_total 10 20 30)
echo "Sum is $sum"  # $sum is now 60 globally

# ✅ RIGHT: Local variables, clear return conventions
calculate_total() {
    local sum=0
    local item

    for item in "$@"; do
        (( sum += item ))
    done

    echo "$sum"  # Return value via stdout
}

# Or use nameref for "return" via reference (Bash 4.3+)
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
result=$(calculate_total 10 20 30)
calculate_total_ref total 10 20 30
```

**Why**: Without `local`, functions modify global variables, causing hard-to-debug side effects.

---

## Quick Reference

| Pattern | Wrong | Right |
|---------|-------|-------|
| Variable expansion | `$var` | `"$var"` |
| Array iteration | `$arr` | `"${arr[@]}"` |
| Function vars | `var=x` | `local var=x` |
| Required var | no check | `${VAR:?msg}` |
| Default value | `if [ -z "$VAR" ]; then VAR=x; fi` | `${VAR:-default}` |
