# Claude Development Guidelines for claude-review-code

## Project Overview

PRPM skill package providing comprehensive code review capabilities for Claude Code.

## Structure

```
skills/review-code/SKILL.md    Main skill entry point
agents/                        12 specialized review subagents
scripts/                       PR context helper scripts (bash)
rules/                         Language quality checklists
concepts/                      Deep dive documentation
patterns/                      Design pattern references
```

## Key Patterns

### Skill Files
- Main skill at `skills/review-code/SKILL.md`
- Agents reference relative paths: `concepts/code-review.md` not `~/.claude/concepts/code-review.md`
- Scripts auto-detect repo from git remote (no hardcoded defaults)

### Path References
- Use `~/.claude/` paths for user-facing documentation (README, usage examples)
- Use relative paths in agent `implements:` sections
- Scripts output to `~/.claude/prs/` for PR context caching

### Scripts
- All scripts use `set -Eeuo pipefail`
- Auto-detect repo from git remote when possible
- Portable bash (no bashisms that break on different systems)

## Quality Gates

Before committing, all gates must pass:

```bash
# 1. Validate prpm.json
jq empty prpm.json

# 2. Check required files exist
test -f skills/review-code/SKILL.md
test -f README.md
test -f LICENSE

# 3. Validate scripts are executable
for f in scripts/*.sh; do test -x "$f" || echo "Not executable: $f"; done

# 4. Shellcheck scripts
shellcheck scripts/*.sh

# 5. Check for machine-specific references
! grep -r '/Users/' --include='*.md' --include='*.sh' .
! grep -r 'chainguard-dev' --include='*.md' --include='*.sh' . | grep -v 'Sam Newman'

# 6. Verify no dangling file references
# (check that files referenced in agents/skills exist)
```

## Pre-Push Checklist

Before pushing:

1. All quality gates pass
2. prpm.json version updated if releasing
3. README reflects any new features
4. No hardcoded personal paths or repos

## Releasing

See `CONTRIBUTING.md` for full release documentation.

```bash
# 1. Update version in prpm.json
# 2. Commit version bump
git add prpm.json && git commit -m "chore: bump version to X.Y.Z"
git push origin main

# 3. Tag and push
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

CI will automatically publish to PRPM on tag push.

### Token Expiry

If release fails with auth errors, refresh the PRPM token:

```bash
prpm login
gh secret set PRPM_TOKEN --repo dakaneye/claude-review-code < <(jq -r '.token' ~/.prpmrc)
```

## File Reference Conventions

PRPM installs all files flat into `~/.claude/skills/dakaneye-review-code/`. Reference paths accordingly:

| Context | Path Style | Example |
|---------|------------|---------|
| PRPM paths | `~/.claude/skills/dakaneye-review-code/` | `~/.claude/skills/dakaneye-review-code/get-pr-context.sh` |
| Agent implements | Relative filename | `code-review.md` |
| Agent deep dives | `~/.claude/skills/dakaneye-review-code/` | `~/.claude/skills/dakaneye-review-code/go-*.md` |
| Script output | `~/.claude/` | `~/.claude/prs/<owner>-<repo>/` |

## Adding New Content

### New Language Support
1. Add `rules/<lang>.md` with mnemonic checklist
2. Add `concepts/language-standards/<lang>/` deep dives
3. Add `agents/<lang>-pro.md` expert agent
4. Update SKILL.md language agent table
5. Update README language checklist table

### New Pattern
1. Add to appropriate `patterns/` subdirectory
2. Update `patterns/INDEX.md` if significant
3. Reference from relevant agents if applicable
