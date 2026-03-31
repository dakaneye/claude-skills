# Monorepo Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `dakaneye/claude-review-code` into `dakaneye/claude-skills`, a monorepo where each skill is self-contained and independently publishable via PRPM.

**Architecture:** Each skill lives under `skills/<name>/` with its own `prpm.json`, agents, scripts, rules, concepts, patterns, and evals. CI scans all skills generically. Release workflow uses tag prefixes (`<skill>/v<semver>`) to publish individual skills with automatic version bumping.

**Tech Stack:** Git, GitHub Actions, Python 3.12 (linter/validator), ShellCheck, PRPM, Bash

---

### Task 1: Move review-code content into self-contained skill directory

**Files:**
- Move: `agents/*.md` → `skills/review-code/agents/`
- Move: `scripts/*.sh` → `skills/review-code/scripts/`
- Move: `rules/*.md` → `skills/review-code/rules/`
- Move: `concepts/` → `skills/review-code/concepts/`
- Move: `patterns/` → `skills/review-code/patterns/`
- Move: `prpm.json` → `skills/review-code/prpm.json`

- [ ] **Step 1: Move all directories under skills/review-code/**

```bash
cd /Users/samueldacanay/dev/personal/claude-review-code

git mv agents skills/review-code/agents
git mv scripts skills/review-code/scripts
git mv rules skills/review-code/rules
git mv concepts skills/review-code/concepts
git mv patterns skills/review-code/patterns
git mv prpm.json skills/review-code/prpm.json
```

- [ ] **Step 2: Verify the move**

Run: `find skills/review-code -type f | wc -l`
Expected: 100+ files (all content files now under skills/review-code/)

Run: `ls agents/ concepts/ patterns/ rules/ scripts/ prpm.json 2>&1`
Expected: All return "No such file or directory"

- [ ] **Step 3: Commit the move**

```bash
git add -A
git commit -m "refactor: move review-code content into self-contained skill directory

Moves agents/, scripts/, rules/, concepts/, patterns/, and prpm.json
under skills/review-code/ to support multi-skill monorepo structure."
```

---

### Task 2: Update prpm.json file paths

The `files` array in `prpm.json` currently uses repo-root-relative paths (e.g., `agents/golang-pro.md`). After the move, `prpm publish` runs from `skills/review-code/`, so paths must be relative to that directory. The paths happen to already be correct since the files are now at `skills/review-code/agents/golang-pro.md` and PRPM resolves from the directory containing `prpm.json`.

**Files:**
- Modify: `skills/review-code/prpm.json`

- [ ] **Step 1: Update the repository URL**

In `skills/review-code/prpm.json`, change:
```json
"repository": "https://github.com/dakaneye/claude-review-code"
```
to:
```json
"repository": "https://github.com/dakaneye/claude-skills"
```

- [ ] **Step 2: Add evals to files array**

Add these entries to the `files` array in `skills/review-code/prpm.json`:
```json
"skills/review-code/evals/evals.json",
"skills/review-code/evals/trigger-evals.json",
```

Wait — the files array uses paths like `agents/golang-pro.md`, not `skills/review-code/agents/golang-pro.md`. These are relative to where `prpm.json` lives. Since `prpm.json` is now at `skills/review-code/prpm.json`, the current paths (`agents/golang-pro.md`) resolve correctly because `skills/review-code/agents/golang-pro.md` exists.

For evals, add:
```json
"evals/evals.json",
"evals/trigger-evals.json",
```

Also add the SKILL.md entry if missing:
```json
"SKILL.md",
```

And remove `skills/review-code/SKILL.md` if it exists in the array — that was the old repo-root-relative path.

- [ ] **Step 3: Verify prpm.json is valid and paths resolve**

Run: `cd skills/review-code && jq empty prpm.json && echo "valid JSON"`
Expected: `valid JSON`

Run: `cd skills/review-code && jq -r '.files[]' prpm.json | while read f; do [ -f "$f" ] || echo "MISSING: $f"; done`
Expected: No output (all files exist)

- [ ] **Step 4: Commit**

```bash
git add skills/review-code/prpm.json
git commit -m "fix: update prpm.json paths for monorepo structure"
```

---

### Task 3: Update internal path references in skill files

All agents, rules, and the SKILL.md reference `~/.claude/skills/dakaneye-review-code/` for deep dive files. These paths are used at runtime when PRPM installs the skill — PRPM flattens everything into `~/.claude/skills/dakaneye-review-code/`. These paths are correct for installed usage and should NOT change.

However, we need to verify no paths reference repo-root-relative locations that broke during the move.

**Files:**
- Verify: `skills/review-code/SKILL.md`
- Verify: `skills/review-code/agents/*.md`
- Verify: `skills/review-code/rules/*.md`

- [ ] **Step 1: Verify all `~/.claude/skills/dakaneye-review-code/` references are intact**

Run: `grep -r "dakaneye-review-code" skills/review-code/ | wc -l`
Expected: 15+ matches (these are correct — they're runtime install paths)

- [ ] **Step 2: Check for any broken relative path references**

Run: `grep -rn '\.\./\|\./' skills/review-code/agents/ skills/review-code/rules/ skills/review-code/SKILL.md || echo "No relative paths found"`
Expected: No relative paths that reference old repo-root structure

- [ ] **Step 3: No commit needed if nothing changed**

---

### Task 4: Update CI workflow for multi-skill structure

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Update the CI workflow**

Replace the full contents of `.github/workflows/ci.yml` with:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Validate prpm.json for each skill
        run: |
          for manifest in skills/*/prpm.json; do
            echo "Validating $manifest..."
            jq empty "$manifest" || { echo "Error: $manifest is not valid JSON"; exit 1; }
          done
          echo "All prpm.json files valid"

      - name: Check required files exist
        run: |
          required_files=(
            "README.md"
            "LICENSE"
          )
          for file in "${required_files[@]}"; do
            if [ ! -f "$file" ]; then
              echo "Error: Required file missing: $file"
              exit 1
            fi
          done
          # Each skill must have a SKILL.md
          for skill_dir in skills/*/; do
            if [ ! -f "${skill_dir}SKILL.md" ]; then
              echo "Error: Missing SKILL.md in $skill_dir"
              exit 1
            fi
          done
          echo "All required files present"

      - name: Validate scripts are executable
        run: |
          found=0
          for script in skills/*/scripts/*.sh; do
            [ -f "$script" ] || continue
            found=1
            if [ ! -x "$script" ]; then
              echo "Error: $script is not executable"
              exit 1
            fi
          done
          if [ "$found" -eq 0 ]; then
            echo "No scripts found to validate"
          else
            echo "All scripts are executable"
          fi

      - name: Count package files
        run: |
          for skill_dir in skills/*/; do
            skill_name=$(basename "$skill_dir")
            echo "=== $skill_name ==="
            echo "  Files: $(find "$skill_dir" -type f | wc -l | tr -d ' ')"
          done
          echo "Total files: $(find . -type f -not -path './.git/*' -not -path './docs/*' | wc -l | tr -d ' ')"

  skill-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5
        with:
          python-version: "3.12"

      - name: Run skill linter
        run: python3 tests/skill-linter.py

  eval-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5
        with:
          python-version: "3.12"

      - name: Validate eval files
        run: python3 tests/eval-validator.py

  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Run ShellCheck
        # TODO: tighten to -S warning after fixing SC2034/SC2155 in existing scripts
        run: |
          shopt -s nullglob
          scripts=(skills/*/scripts/*.sh)
          if [ ${#scripts[@]} -eq 0 ]; then
            echo "No scripts to check"
            exit 0
          fi
          shellcheck -x -S error "${scripts[@]}"

  no-hardcoded-paths:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

      - name: Check for machine-specific paths
        run: |
          # Exclude CLAUDE.md which documents the grep command itself
          if grep -r '/Users/' --include='*.md' --include='*.sh' --exclude='CLAUDE.md' .; then
            echo "Error: Found machine-specific /Users/ paths"
            exit 1
          fi
          echo "No hardcoded paths found"
```

- [ ] **Step 2: Verify CI checks pass locally**

Run: `python3 tests/skill-linter.py`
Expected: 1 passing, 0 failing

Run: `python3 tests/eval-validator.py`
Expected: "All evals valid"

Run: `shellcheck -x -S error skills/*/scripts/*.sh`
Expected: exit 0

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: update workflow for multi-skill monorepo structure"
```

---

### Task 5: Rewrite release workflow for tag-prefix publishing

**Files:**
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Write the new release workflow**

Replace `.github/workflows/release.yml` with:

```yaml
name: Release

on:
  push:
    tags:
      # Match tags like review-code/v1.0.5
      - '*/v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
        with:
          # Need full history + write access to push version bump commit
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Parse tag
        id: tag
        run: |
          TAG="${GITHUB_REF#refs/tags/}"
          SKILL_NAME="${TAG%%/v*}"
          VERSION="${TAG#*/v}"
          SKILL_DIR="skills/${SKILL_NAME}"

          if [ ! -d "$SKILL_DIR" ]; then
            echo "Error: Skill directory not found: $SKILL_DIR"
            exit 1
          fi

          echo "skill_name=$SKILL_NAME" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "skill_dir=$SKILL_DIR" >> "$GITHUB_OUTPUT"
          echo "Publishing $SKILL_NAME v$VERSION from $SKILL_DIR"

      - name: Update version in prpm.json
        run: |
          cd "${{ steps.tag.outputs.skill_dir }}"
          jq --arg v "${{ steps.tag.outputs.version }}" '.version = $v' prpm.json > prpm.json.tmp
          mv prpm.json.tmp prpm.json

      - name: Update version in SKILL.md frontmatter
        run: |
          cd "${{ steps.tag.outputs.skill_dir }}"
          sed -i "s/^version: .*/version: ${{ steps.tag.outputs.version }}/" SKILL.md

      - name: Setup Node.js
        uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4
        with:
          node-version: '22'

      - name: Install PRPM
        run: npm install -g prpm

      - name: Configure PRPM authentication
        run: |
          cat > ~/.prpmrc << EOF
          {
            "registryUrl": "https://registry.prpm.dev",
            "token": "${{ secrets.PRPM_TOKEN }}"
          }
          EOF

      - name: Validate package
        run: cd "${{ steps.tag.outputs.skill_dir }}" && prpm publish --dry-run

      - name: Publish to PRPM
        run: cd "${{ steps.tag.outputs.skill_dir }}" && prpm publish

      - name: Create GitHub Release
        uses: softprops/action-gh-release@153bb8e04406b158c6c84fc1615b65b24149a1fe # v2
        with:
          name: "${{ steps.tag.outputs.skill_name }} v${{ steps.tag.outputs.version }}"
          generate_release_notes: true

      - name: Push version bump commit
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add "${{ steps.tag.outputs.skill_dir }}/prpm.json" "${{ steps.tag.outputs.skill_dir }}/SKILL.md"
          git commit -m "chore(${{ steps.tag.outputs.skill_name }}): bump version to ${{ steps.tag.outputs.version }}" || echo "No version changes to commit"
          git push origin HEAD:main
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: rewrite release workflow for per-skill tag-prefix publishing

Tags like review-code/v1.0.5 trigger publish for that skill only.
Workflow auto-bumps version in prpm.json and SKILL.md frontmatter."
```

---

### Task 6: Update install.sh for monorepo structure

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Rewrite install.sh to accept a skill name argument**

Replace `install.sh` with:

```bash
#!/usr/bin/env bash

# Skill installer for dakaneye/claude-skills
# Installs a skill into ~/.claude/skills/dakaneye-<skill-name>/
# Uses the same flat structure as PRPM for consistency
#
# Usage: ./install.sh <skill-name>
# Example: ./install.sh review-code

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    echo "Usage: $0 <skill-name>"
    echo ""
    echo "Available skills:"
    for skill_dir in "$SCRIPT_DIR"/skills/*/; do
        [[ -d "$skill_dir" ]] || continue
        local name
        name=$(basename "$skill_dir")
        echo "  - $name"
    done
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

SKILL_NAME="$1"
SKILL_SRC="$SCRIPT_DIR/skills/$SKILL_NAME"
TARGET_DIR="${HOME}/.claude/skills/dakaneye-${SKILL_NAME}"

if [[ ! -d "$SKILL_SRC" ]]; then
    log_error "Skill not found: $SKILL_NAME"
    usage
fi

if [[ ! -f "$SKILL_SRC/SKILL.md" ]]; then
    log_error "No SKILL.md found in $SKILL_SRC"
    exit 1
fi

# Backup existing installation
if [[ -d "$TARGET_DIR" ]]; then
    backup="${TARGET_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "Backing up existing installation to $backup"
    mv "$TARGET_DIR" "$backup"
fi

# Copy all files to flat structure (matching PRPM behavior)
log_info "Installing $SKILL_NAME to $TARGET_DIR (flat structure)..."
mkdir -p "$TARGET_DIR"

# SKILL.md
cp "$SKILL_SRC/SKILL.md" "$TARGET_DIR/"

# Scripts (make executable)
for script in "$SKILL_SRC"/scripts/*.sh; do
    [[ -f "$script" ]] || continue
    cp "$script" "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/$(basename "$script")"
done

# Flat markdown files from agents/, rules/
for dir in agents rules; do
    for file in "$SKILL_SRC/$dir"/*.md; do
        [[ -f "$file" ]] || continue
        cp "$file" "$TARGET_DIR/"
    done
done

# Concepts (flatten nested structure)
if [[ -d "$SKILL_SRC/concepts" ]]; then
    find "$SKILL_SRC/concepts" -name '*.md' -type f -exec cp {} "$TARGET_DIR/" \;
fi

# Patterns (flatten nested structure)
if [[ -d "$SKILL_SRC/patterns" ]]; then
    find "$SKILL_SRC/patterns" -name '*.md' -type f -exec cp {} "$TARGET_DIR/" \;
fi

# README and LICENSE from repo root
cp "$SCRIPT_DIR/README.md" "$TARGET_DIR/"
cp "$SCRIPT_DIR/LICENSE" "$TARGET_DIR/"

# Verify
file_count=$(find "$TARGET_DIR" -type f | wc -l | tr -d ' ')
log_info "Installed $file_count files"

if [[ -f "$TARGET_DIR/SKILL.md" ]]; then
    log_info "Installation complete: $TARGET_DIR"
else
    log_error "Installation may be incomplete — SKILL.md not found in target"
    exit 1
fi

echo ""
echo "=== Installed: dakaneye-${SKILL_NAME} ==="
echo "Location: $TARGET_DIR"
echo "Invoke:   /$(basename "$SKILL_NAME")"
```

- [ ] **Step 2: Verify the script is valid**

Run: `bash -n install.sh`
Expected: exit 0 (no syntax errors)

Run: `shellcheck -x -S error install.sh`
Expected: exit 0

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "refactor: rewrite install.sh for multi-skill monorepo

Accepts skill name argument: ./install.sh review-code
Lists available skills if no argument provided."
```

---

### Task 7: Update CLAUDE.md for monorepo structure

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Rewrite CLAUDE.md**

Replace `CLAUDE.md` with content reflecting the multi-skill monorepo:

```markdown
# Claude Development Guidelines for claude-skills

## Project Overview

Monorepo for independently publishable PRPM skill packages. Each skill lives under `skills/<name>/` with its own `prpm.json`, agents, scripts, and supporting content.

## Structure

```
claude-skills/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md           # Skill entry point (version in frontmatter)
│       ├── prpm.json          # PRPM package definition
│       ├── evals/             # Reasoning and trigger evals
│       ├── agents/            # Specialized subagents
│       ├── scripts/           # Helper scripts
│       ├── rules/             # Language quality checklists
│       ├── concepts/          # Deep dive documentation
│       └── patterns/          # Design pattern references
├── tests/                     # Linter and eval validator (scan all skills)
├── .github/workflows/         # CI + per-skill release
├── CLAUDE.md
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

## Key Patterns

### Skills Are Self-Contained
Each skill directory contains everything it needs. No shared code between skills. This keeps skills independently publishable.

### Path References
- Use `~/.claude/skills/dakaneye-<skill-name>/` in agent/rule files (runtime PRPM install path)
- Use relative paths within a skill directory for file references in `prpm.json`
- Scripts auto-detect repo from git remote (no hardcoded defaults)

### Versioning
- Tags drive releases: `<skill-name>/v<semver>` (e.g., `review-code/v1.0.5`)
- Release workflow auto-bumps version in `prpm.json` and `SKILL.md` frontmatter
- Never manually edit version fields

### Scripts
- All scripts use `set -Eeuo pipefail`
- Auto-detect repo from git remote when possible
- Portable bash (no bashisms that break on different systems)

## Quality Gates

Before committing, all gates must pass:

```bash
# 1. Validate all prpm.json files
for f in skills/*/prpm.json; do jq empty "$f"; done

# 2. Each skill has a SKILL.md
for d in skills/*/; do test -f "${d}SKILL.md"; done

# 3. Validate scripts are executable
for f in skills/*/scripts/*.sh; do test -x "$f" || echo "Not executable: $f"; done

# 4. Shellcheck scripts
shellcheck -x -S error skills/*/scripts/*.sh

# 5. Skill linter
python3 tests/skill-linter.py

# 6. Eval validator
python3 tests/eval-validator.py

# 7. Check for machine-specific references
! grep -r '/Users/' --include='*.md' --include='*.sh' --exclude='CLAUDE.md' .
```

## Pre-Push Checklist

1. All quality gates pass
2. No hardcoded personal paths or repos

## Releasing

```bash
# Tag triggers the release — version is auto-bumped by CI
git tag -a review-code/v1.0.5 -m "review-code v1.0.5"
git push origin review-code/v1.0.5
```

CI will:
1. Update version in `skills/review-code/prpm.json` and `SKILL.md`
2. Publish to PRPM
3. Create GitHub Release
4. Push version bump commit to main

### Token Expiry

If release fails with auth errors, refresh the PRPM token:

```bash
prpm login
gh secret set PRPM_TOKEN --repo dakaneye/claude-skills < <(jq -r '.token' ~/.prpmrc)
```

## Adding a New Skill

1. Create `skills/<name>/SKILL.md` with frontmatter (name, version, description)
2. Create `skills/<name>/prpm.json` with package definition
3. Create `skills/<name>/evals/evals.json` and `trigger-evals.json`
4. Add any agents, scripts, rules, concepts, patterns under the skill directory
5. Verify: `python3 tests/skill-linter.py && python3 tests/eval-validator.py`
6. Update `README.md` skill listing
7. Tag to release: `git tag -a <name>/v1.0.0 -m "<name> v1.0.0"`
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for multi-skill monorepo"
```

---

### Task 8: Update README.md as collection overview

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite README.md**

Replace `README.md` with a collection overview. Keep the review-code documentation but frame it as one skill in a collection:

```markdown
# Claude Skills by dakaneye

[![CI](https://github.com/dakaneye/claude-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/dakaneye/claude-skills/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Curated skill packages for Claude Code. Each skill is independently installable via [PRPM](https://prpm.dev).

## Available Skills

| Skill | Package | Description |
|-------|---------|-------------|
| [review-code](skills/review-code/) | `dakaneye-review-code` | Comprehensive code review with language-specific expertise, truth-focused analysis, and deep sequential thinking |

## Installation

### Via PRPM (Recommended)

```bash
# Install a specific skill
prpm install dakaneye-review-code
```

### Manual Installation

```bash
git clone https://github.com/dakaneye/claude-skills.git
cd claude-skills
./install.sh review-code
```

## review-code

Full-spectrum code review covering correctness, security, maintainability, and test coverage.

### Supported Languages

| Language | Checklist | Expert Agent |
|----------|-----------|-------------|
| Go | DRIVEC | golang-pro |
| Node.js | STREAMS | nodejs-principal |
| Java | INVEST | java-pro |
| Python | TYPED | python-pro |
| Bash | VEST | bash-pro |
| Terraform | STATELOCK | terraform-specialist |

### Usage

```bash
# Review a PR
/review-code https://github.com/org/repo/pull/123

# Review staged changes
/review-code

# Review a specific file or directory
/review-code src/auth/
```

### What It Reviews

- **14-dimension quality scorecard** with weighted scoring
- **Language-specific checklists** (DRIVEC, STREAMS, INVEST, TYPED, VEST, STATELOCK)
- **AI-spray detection** identifying over-engineered AI-generated code
- **Security audit** covering OWASP Top 10
- **Pattern conformance** against 40+ design patterns
- **Truth verification** ensuring code matches its claims

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

[MIT](LICENSE)
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README as multi-skill collection overview"
```

---

### Task 9: Update CONTRIBUTING.md

**Files:**
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Rewrite CONTRIBUTING.md for monorepo**

Replace `CONTRIBUTING.md` with:

```markdown
# Contributing

Contributions are welcome! Here's how to help.

## Development

```bash
git clone https://github.com/dakaneye/claude-skills.git
cd claude-skills
```

## Structure

```
claude-skills/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md        # Skill entry point
│       ├── prpm.json       # Package definition
│       ├── evals/          # Reasoning and trigger evals
│       ├── agents/         # Specialized subagents
│       ├── scripts/        # Helper scripts
│       ├── rules/          # Language quality checklists
│       ├── concepts/       # Deep dive documentation
│       └── patterns/       # Design pattern references
├── tests/                  # Shared linter and eval validator
└── .github/workflows/      # CI and release
```

## Before Submitting

1. Run the quality gates:
   ```bash
   python3 tests/skill-linter.py
   python3 tests/eval-validator.py
   shellcheck -x -S error skills/*/scripts/*.sh
   ```
2. Ensure scripts are executable and portable
3. Follow existing markdown formatting
4. Update README if adding new features

## Pull Requests

- Keep changes focused on one skill
- Explain the "why" in your PR description
- Follow existing patterns in the codebase

## Adding a New Skill

1. Create `skills/<name>/SKILL.md` with frontmatter (name, version, description with trigger phrases)
2. Create `skills/<name>/prpm.json` with package definition
3. Create `skills/<name>/evals/evals.json` (reasoning evals) and `trigger-evals.json`
4. Add supporting content (agents, scripts, rules, concepts, patterns) as needed
5. Verify linter and eval validator pass
6. Update README.md skill listing

## Adding Language Support to review-code

1. Create `skills/review-code/rules/<lang>.md` with a mnemonic checklist
2. Create `skills/review-code/concepts/language-standards/<lang>/` with deep dive files
3. Create `skills/review-code/agents/<lang>-pro.md` with language-specific expertise
4. Update `skills/review-code/SKILL.md` language agent selection table
5. Add AI anti-pattern detection signals for the language

## Releasing

Tags drive releases. The release workflow auto-bumps versions.

```bash
git tag -a <skill-name>/v<semver> -m "<skill-name> v<semver>"
git push origin <skill-name>/v<semver>
```

### Token Expiry

If release fails with auth errors:

```bash
prpm login
gh secret set PRPM_TOKEN --repo dakaneye/claude-skills < <(jq -r '.token' ~/.prpmrc)
```

## Reporting Issues

- Use the issue templates
- Include Claude Code version
```

- [ ] **Step 2: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: update CONTRIBUTING.md for multi-skill monorepo"
```

---

### Task 10: Verify everything passes end-to-end

**Files:** None (verification only)

- [ ] **Step 1: Run skill linter**

Run: `python3 tests/skill-linter.py`
Expected: `"passing": 1, "failing": 0`

- [ ] **Step 2: Run eval validator**

Run: `python3 tests/eval-validator.py`
Expected: `All evals valid`

- [ ] **Step 3: Run shellcheck**

Run: `shellcheck -x -S error skills/*/scripts/*.sh`
Expected: exit 0

Run: `shellcheck -x -S error install.sh`
Expected: exit 0

- [ ] **Step 4: Validate prpm.json paths resolve**

Run: `cd skills/review-code && jq -r '.files[]' prpm.json | while read f; do [ -f "$f" ] || echo "MISSING: $f"; done`
Expected: No output

- [ ] **Step 5: Check no hardcoded paths**

Run: `grep -r '/Users/' --include='*.md' --include='*.sh' --exclude='CLAUDE.md' . || echo "clean"`
Expected: `clean`

- [ ] **Step 6: Validate install.sh syntax**

Run: `bash -n install.sh`
Expected: exit 0

- [ ] **Step 7: Dry-run PRPM publish**

Run: `cd skills/review-code && prpm publish --dry-run`
Expected: Validation passes (may fail if not logged in — that's OK locally)

---

### Task 11: Rename repo on GitHub

This task is manual and happens after all code changes are pushed and CI passes.

- [ ] **Step 1: Push all changes and verify CI passes**

Run: `git push origin main`
Then check: https://github.com/dakaneye/claude-review-code/actions

- [ ] **Step 2: Rename the repository**

Run: `gh repo rename claude-skills --repo dakaneye/claude-review-code --yes`

- [ ] **Step 3: Update local git remote**

Run: `git remote set-url origin git@github.com:dakaneye/claude-skills.git`

- [ ] **Step 4: Update PRPM token secret (repo name changed)**

Run: `gh secret set PRPM_TOKEN --repo dakaneye/claude-skills < <(jq -r '.token' ~/.prpmrc)`

- [ ] **Step 5: Verify redirect works**

Run: `curl -sI https://github.com/dakaneye/claude-review-code | head -5`
Expected: 301 redirect to `https://github.com/dakaneye/claude-skills`

- [ ] **Step 6: Tag a release to verify the full pipeline**

```bash
git tag -a review-code/v1.1.0 -m "review-code v1.1.0 — first release from monorepo"
git push origin review-code/v1.1.0
```

Check: https://github.com/dakaneye/claude-skills/actions
Expected: Release workflow publishes `dakaneye-review-code` v1.1.0
