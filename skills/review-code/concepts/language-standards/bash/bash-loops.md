---
title: Bash Loops & Iteration
topics:
  - safe iteration
  - process substitution
  - subshell variables
  - find patterns
version_requirements: Bash 4.0+ (4.4+ for mapfile -d)
---

# Bash Loops & Iteration

> Safe iteration, process substitution, and avoiding subshell issues.

## Parsing Command Output in Loops

```bash
# ❌ WRONG: Subshell in for loop, broken with spaces/newlines
for file in $(find . -name "*.txt"); do
    process "$file"  # Breaks with spaces in filenames
done

# Also wrong - loses exit status
find . -name "*.txt" | while read file; do
    count=$((count + 1))  # count not visible outside loop (subshell)
done
echo "$count"  # Empty or wrong value

# ✅ RIGHT: Process substitution with NUL delimiter
while IFS= read -r -d '' file; do
    process "$file"
done < <(find . -name "*.txt" -print0)

# Alternative: read into array first
mapfile -d '' files < <(find . -name "*.txt" -print0)
for file in "${files[@]}"; do
    process "$file"
done

# For simple cases: use glob directly
shopt -s globstar  # Enable ** pattern
for file in ./**/*.txt; do
    [[ -e "$file" ]] || continue
    process "$file"
done
```

**Why**: Command substitution `$()` word-splits on spaces and newlines. Pipes create subshells, so variable changes inside `while` don't persist. Use process substitution `<()` to avoid subshells.

---

## Process Substitution

```bash
# Compare output of two commands
diff <(sort file1.txt) <(sort file2.txt)

# Multiple inputs
paste <(cut -f1 data.txt) <(cut -f3 data.txt)

# Avoid subshell in while loop
while IFS= read -r line; do
    count=$((count + 1))  # Variable persists
done < <(generate_data)

# Read into array
declare -a results
while IFS= read -r line; do
    results+=("$line")
done < <(query_database)
```

---

## Safe Glob Iteration

```bash
# ❌ WRONG: Parsing ls output
for file in $(ls *.txt); do
    process "$file"
done

# ✅ RIGHT: Use glob directly
for file in *.txt; do
    [[ -e "$file" ]] || continue  # Handle no-match case
    process "$file"
done

# With nullglob (returns empty if no matches)
shopt -s nullglob
for file in *.txt; do
    process "$file"
done
shopt -u nullglob

# Recursive with globstar
shopt -s globstar
for file in **/*.txt; do
    [[ -f "$file" ]] || continue
    process "$file"
done
```

---

## find Best Practices

```bash
# Simple execution
find . -name "*.txt" -exec process {} \;

# Batch execution (faster)
find . -name "*.txt" -exec process {} +

# With xargs for more control
find . -name "*.txt" -print0 | xargs -0 process

# Complex logic in while loop
while IFS= read -r -d '' file; do
    if [[ "$file" == *important* ]]; then
        process_important "$file"
    else
        process_normal "$file"
    fi
done < <(find . -name "*.txt" -print0)
```

---

## Reading Files Line by Line

```bash
# ❌ WRONG: Loses IFS and doesn't handle backslashes
while read line; do
    echo "$line"
done < file.txt

# ✅ RIGHT: Preserve IFS, handle backslashes
while IFS= read -r line; do
    echo "$line"
done < file.txt

# Read into array
mapfile -t lines < file.txt
for line in "${lines[@]}"; do
    echo "$line"
done
```

---

## C-Style Loops

```bash
# Numeric iteration
for (( i = 0; i < 10; i++ )); do
    echo "Iteration $i"
done

# Range with brace expansion
for i in {1..10}; do
    echo "Number $i"
done

# Range with step
for i in {0..20..2}; do  # 0, 2, 4, ..., 20
    echo "Even: $i"
done
```

---

---

## Version Requirements

| Feature | Minimum Version |
|---------|-----------------|
| `globstar` (`**`) | Bash 4.0 |
| `mapfile`/`readarray` | Bash 4.0 |
| `mapfile -d ''` (custom delimiter) | Bash 4.4 |
| `readarray -t` (trim newlines) | Bash 4.0 |

---

## Quick Reference

| Pattern | Wrong | Right |
|---------|-------|-------|
| Iterate files | `for f in $(ls)` | `for f in *; do [[ -e "$f" ]] \|\| continue` |
| Read command output | `for x in $(cmd)` | `while read -r x; do ... done < <(cmd)` |
| Preserve variables | `cmd \| while read` | `while read < <(cmd)` |
| Handle spaces | `find \| while read` | `find -print0 \| while read -r -d ''` |
| Simple file read | `cat file \| while read` | `while read < file` |
| Recursive glob | `find . -name "*.txt"` | `shopt -s globstar; for f in **/*.txt` (Bash 4+) |
