# Claude Development Guidelines for claude-skills

## Project Overview

Monorepo for independently publishable PRPM skill packages. Each skill lives under `skills/<name>/` with its own `prpm.json`, agents, scripts, and supporting content.

## Structure

```
claude-skills/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md           # Skill entry point (no version — PRPM forbids it)
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
- Release workflow auto-bumps version in `prpm.json` (PRPM forbids version in SKILL.md frontmatter)
- Never manually edit the version field

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
1. Update version in `skills/review-code/prpm.json`
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

1. Create `skills/<name>/SKILL.md` with frontmatter (name, description with trigger phrases)
2. Create `skills/<name>/prpm.json` with package definition
3. Create `skills/<name>/evals/evals.json` and `trigger-evals.json`
4. Add any agents, scripts, rules, concepts, patterns under the skill directory
5. Verify: `python3 tests/skill-linter.py && python3 tests/eval-validator.py`
6. Update `README.md` skill listing
7. Tag to release: `git tag -a <name>/v1.0.0 -m "<name> v1.0.0"`
