---
title: Bash AI Anti-Patterns
topics:
  - AI code smells
  - performance issues
  - ShellCheck compliance
  - unnecessary complexity
version_requirements: N/A (applies to all Bash versions)
---

# Bash AI Anti-Patterns

> Common AI-generated Bash code smells and performance issues.

## Overuse of Backticks

```bash
# ❌ AI Often Generates
result=`command`           # Old style, hard to nest
output=`ls \`pwd\``        # Escaping nightmare

# ✅ Use Instead
result=$(command)          # Modern, nestable
output=$(ls "$(pwd)")      # Clear nesting
```

---

## Unnecessary Subshells

```bash
# ❌ AI Often Generates (when isolation is NOT needed)
(cd /some/dir && command)  # Creates subshell for no reason

# ✅ Use Instead (when you DO need to return to original dir)
pushd /some/dir >/dev/null
command
popd >/dev/null

# Or:
original_dir="$PWD"
cd /some/dir
command
cd "$original_dir"
```

**EXCEPTION**: Subshells ARE intentional when isolating side effects:
```bash
# ✅ INTENTIONAL: Isolate environment changes
(
    export SPECIAL_VAR="value"
    cd /special/dir
    run_isolated_command
)  # Changes don't leak to parent

# ✅ INTENTIONAL: Isolate set options
(
    set +e  # Temporarily allow failures
    risky_command
)  # Parent's set -e is preserved
```

**Rule**: Flag subshells as AI-smell ONLY when there's no isolation benefit.

---

## Parsing ls Output

```bash
# ❌ AI Commonly Generates
for file in $(ls *.txt); do process "$file"; done
files=$(ls -1 /path)

# ✅ Use Instead
for file in *.txt; do
    [[ -e "$file" ]] || continue
    process "$file"
done

# For find:
find /path -type f -print0 | while IFS= read -r -d '' file; do
    process "$file"
done
```

---

## echo vs printf Confusion

```bash
# ❌ AI Mixes These
echo -n "no newline"      # Not portable (-n not POSIX)
echo -e "line1\nline2"    # -e not portable
echo "$var"               # If var starts with -, breaks

# ✅ Use Instead
printf '%s' "no newline"  # Portable, predictable
printf 'line1\nline2\n'
printf '%s\n' "$var"      # Safe with any content
```

---

## Redundant cat (UUOC)

```bash
# ❌ AI Generates UUOC (Useless Use of Cat)
cat file | grep pattern
cat file | head -n 10

# ✅ Use Instead
grep pattern file         # Or: < file grep pattern
head -n 10 file           # Or: < file head -n 10
```

---

## Missing Shellcheck Directives

```bash
# ❌ AI Ignores ShellCheck Warnings
cd "$dir"           # SC2164: Use cd ... || exit
source "$file"      # SC1090: Can't follow source

# ✅ Use Appropriate Directives
# shellcheck disable=SC1090  # Source file is dynamic
source "$config_file"

# Or fix the warning
cd "$dir" || {
    echo "Error: Failed to cd to $dir" >&2
    exit 1
}
```

---

## Performance Anti-Patterns

### Subshell in Loops

```bash
# ❌ WRONG: Spawning subshell on every iteration
while read -r line; do
    result=$(echo "$line" | grep -o 'pattern')  # Fork + exec each line
    echo "$result"
done < file.txt

# ✅ RIGHT: Use built-in parameter expansion
while read -r line; do
    if [[ "$line" =~ pattern ]]; then
        echo "${BASH_REMATCH[0]}"
    fi
done < file.txt

# Or process in single pipeline
grep -o 'pattern' file.txt
```

### External Commands for String Operations

```bash
# ❌ WRONG: External commands for simple operations
basename=$(echo "$path" | sed 's|.*/||')
extension=$(echo "$file" | awk -F. '{print $NF}')
length=$(echo -n "$string" | wc -c)

# ✅ RIGHT: Use parameter expansion
basename="${path##*/}"
extension="${file##*.}"
length="${#string}"

# ❌ WRONG: External command to check substring
if echo "$string" | grep -q "pattern"; then

# ✅ RIGHT: Built-in pattern matching
if [[ "$string" == *"pattern"* ]]; then
```

### Repeated File Reads

```bash
# ❌ WRONG: Reading same file multiple times
lines=$(wc -l < file.txt)
first=$(head -1 file.txt)
last=$(tail -1 file.txt)

# ✅ RIGHT: Read once, process in memory
mapfile -t content < file.txt
lines="${#content[@]}"
first="${content[0]}"
last="${content[-1]}"
```

### Command Substitution in Conditionals

```bash
# ❌ WRONG: Running command just to check exit status
if [[ $(grep -c "pattern" file.txt) -gt 0 ]]; then

# ✅ RIGHT: Check exit status directly
if grep -q "pattern" file.txt; then

# ❌ WRONG: Capturing output just to test emptiness
if [[ -n "$(find . -name '*.txt')" ]]; then

# ✅ RIGHT: Use exit status
if find . -name '*.txt' -print -quit | grep -q .; then
```

### Inefficient Loops

```bash
# ❌ WRONG: Processing output line-by-line in shell
for file in $(find . -name "*.txt"); do  # Word splitting issues too
    process "$file"
done

# ✅ RIGHT: Use find -exec or xargs
find . -name "*.txt" -exec process {} \;
# Or with xargs for batching
find . -name "*.txt" -print0 | xargs -0 process

# ✅ RIGHT: Use find with while loop for complex logic
while IFS= read -r -d '' file; do
    process "$file"
done < <(find . -name "*.txt" -print0)
```

### Temporary Variables for Single Use

```bash
# ❌ WRONG: Variable used only once
temp=$(some_command)
process "$temp"

# ✅ RIGHT: Inline if no reuse
process "$(some_command)"

# But DO use variable if used multiple times or for clarity
result=$(expensive_command)
log "Got: $result"
process "$result"
```

---

## AI Detection Signals

| Signal | Description | ShellCheck |
|--------|-------------|------------|
| Backticks `` `cmd` `` | Old style, use `$(cmd)` | SC2006 |
| `$(cd dir && cmd)` | Unnecessary subshell (unless intentional) | — |
| `for f in $(ls)` | Parsing ls output | SC2045 |
| `echo -e` or `echo -n` | Not portable | SC2028 |
| `cat file \| cmd` | UUOC | SC2002 |
| No `set -euo pipefail` | Missing strict mode | — |
| No `local` in functions | Global variable pollution | SC2034 |
| `if [ $var = x ]` | Unquoted, use `[[` | SC2086 |
| External cmd for strings | Use parameter expansion | SC2001 |
| `$( cmd )` to check empty | Use exit status | SC2143 |
| `cd` without `\|\| exit` | May continue in wrong dir | SC2164 |
| Unquoted array expansion | Word splitting bugs | SC2068 |
| Mixed declare and assign | Masks return value | SC2155 |

## Additional AI Smells (Not in ShellCheck)

| Signal | Description |
|--------|-------------|
| Over-commenting obvious code | AI explains `# Exit if error` on `exit 1` |
| Defensive checks with `set -u` | Checking `${var:-}` when `set -u` handles it |
| Mixing `echo` and `printf` | Inconsistent output style |
| Not using `readonly` for constants | All caps vars should be `readonly` |
| Verbose variable names | `current_file_being_processed` vs `file` |

---

## ShellCheck Integration

```bash
# .shellcheckrc in project root
enable=all
disable=SC2312  # Example: disable specific check if needed

# External sources
source-path=SCRIPTDIR
external-sources=true
```

**Run ShellCheck:**
```bash
shellcheck script.sh
find . -name "*.sh" -exec shellcheck {} +
shellcheck --format=gcc script.sh  # CI output
```

**Common ShellCheck Warnings:**

| Code | Issue | Fix |
|------|-------|-----|
| SC2086 | Unquoted variable | `"$var"` |
| SC2046 | Unquoted command substitution | `"$(cmd)"` |
| SC2068 | Unquoted array expansion | `"${arr[@]}"` |
| SC2155 | Declare and assign separately | `local var; var=$(cmd)` |
| SC2164 | cd without error check | `cd dir \|\| exit 1` |
| SC1090 | Can't follow dynamic source | `# shellcheck source=./lib.sh` |
| SC2006 | Backticks instead of $() | `$(cmd)` |
| SC2002 | Useless cat | `< file cmd` |
| SC2045 | Parsing ls output | Use glob or find |
| SC2143 | Command substitution for emptiness | `if cmd \| grep -q .` |
| SC2034 | Unused variable | Remove or export |
| SC2001 | sed for simple substitution | `${var//old/new}` |
