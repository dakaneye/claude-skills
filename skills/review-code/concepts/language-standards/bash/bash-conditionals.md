---
title: Bash Conditionals
topics:
  - "[[ vs ["
  - numeric comparisons
  - string comparisons
  - file tests
version_requirements: Bash 3.0+ ([[ ]] syntax)
---

# Bash Conditionals

> `[[` vs `[`, numeric comparisons, and safe testing patterns.

## Incorrect Conditionals

```bash
# ❌ WRONG: Using test `[` instead of `[[`
if [ $var = "value" ]; then  # Breaks if var is empty or contains spaces
    echo "match"
fi

if [ "$count" > 5 ]; then  # STRING comparison, not numeric! Broken.
    echo "greater"
fi

if [ "$str" ]; then  # Unclear: checking if non-empty?
    echo "has value"
fi

# ✅ RIGHT: Use `[[` for strings, `(())` for numbers, explicit checks
if [[ "$var" = "value" ]]; then  # Handles empty/spaces safely
    echo "match"
fi

# Arithmetic comparison
if (( count > 5 )); then  # Numeric comparison
    echo "greater"
fi

# Explicit emptiness checks
if [[ -n "$str" ]]; then  # Explicitly check if non-empty
    echo "has value"
fi

if [[ -z "$str" ]]; then  # Explicitly check if empty
    echo "empty"
fi
```

**Why**: `[` is the old test command with many quirks. `[[` is Bash-specific but safer (handles empty vars, allows `&&`/`||`, supports regex with `=~`).

---

## `[[` vs `[` Comparison

| Feature | `[` (test) | `[[` (Bash) |
|---------|-----------|-------------|
| Empty variable handling | Breaks | Safe |
| Word splitting | Yes (quotes required) | No |
| Globbing | Yes | Controlled with `==` |
| Regex | No | Yes with `=~` |
| Logical operators | `-a`, `-o` | `&&`, `\|\|` |
| Pattern matching | No | Yes with `==` |

---

## Numeric Comparisons

```bash
# ❌ WRONG: String operators for numbers
if [[ "$a" > "$b" ]]; then  # Lexicographic comparison!
    echo "greater"
fi

# ✅ RIGHT: Arithmetic context
if (( a > b )); then
    echo "greater"
fi

# Or numeric operators in [[
if [[ "$a" -gt "$b" ]]; then
    echo "greater"
fi
```

**Arithmetic operators in `[[`**: `-eq`, `-ne`, `-lt`, `-le`, `-gt`, `-ge`

**Arithmetic operators in `(())`**: `==`, `!=`, `<`, `<=`, `>`, `>=`

---

## String Comparisons

```bash
# Equality
if [[ "$str" = "value" ]]; then   # Single = is fine in [[
if [[ "$str" == "value" ]]; then  # Double == also works

# Pattern matching (glob)
if [[ "$str" == *.txt ]]; then
    echo "Text file"
fi

# Regex matching
if [[ "$str" =~ ^[0-9]+$ ]]; then
    echo "Numeric"
fi

# Case-insensitive comparison
if [[ "${str,,}" = "${other,,}" ]]; then
    echo "Equal (case-insensitive)"
fi
```

---

## File Tests

```bash
# File existence and type
[[ -e "$file" ]]  # Exists (any type)
[[ -f "$file" ]]  # Regular file
[[ -d "$file" ]]  # Directory
[[ -L "$file" ]]  # Symbolic link
[[ -s "$file" ]]  # Exists and non-empty

# Permissions
[[ -r "$file" ]]  # Readable
[[ -w "$file" ]]  # Writable
[[ -x "$file" ]]  # Executable

# Comparison
[[ "$file1" -nt "$file2" ]]  # Newer than
[[ "$file1" -ot "$file2" ]]  # Older than
```

---

## Compound Conditionals

```bash
# ❌ WRONG: Old style
if [ -f "$file" -a -r "$file" ]; then

# ✅ RIGHT: Bash style with &&/||
if [[ -f "$file" && -r "$file" ]]; then
    echo "File exists and is readable"
fi

# Negation
if [[ ! -e "$file" ]]; then
    echo "File does not exist"
fi

# Complex conditions
if [[ ( "$a" = "x" || "$a" = "y" ) && -n "$b" ]]; then
    echo "Condition met"
fi
```

---

---

## Advanced Tests (Bash 4.2+)

```bash
# Check if variable is set (even if empty) - Bash 4.2+
[[ -v varname ]]

# Check if variable is a nameref - Bash 4.3+
[[ -R varname ]]

# Check if file modified since last read
[[ -N "$file" ]]
```

---

## Quick Reference

| Test | Wrong | Right |
|------|-------|-------|
| String equality | `[ $var = "x" ]` | `[[ "$var" = "x" ]]` |
| Numeric comparison | `[ "$a" > "$b" ]` | `(( a > b ))` |
| Empty check | `[ "$str" ]` | `[[ -n "$str" ]]` |
| File exists | `[ -e $file ]` | `[[ -e "$file" ]]` |
| Multiple conditions | `[ -f "$f" -a -r "$f" ]` | `[[ -f "$f" && -r "$f" ]]` |
| Variable is set | N/A | `[[ -v varname ]]` (Bash 4.2+) |
