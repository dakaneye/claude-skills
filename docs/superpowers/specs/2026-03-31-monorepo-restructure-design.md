# Monorepo Restructure: claude-review-code → claude-skills

## Summary

Transform `dakaneye/claude-review-code` (single-skill repo) into `dakaneye/claude-skills` (monorepo for independently publishable PRPM skill packages). Start with `review-code` as the sole skill; the structure supports adding more skills with zero infra changes.

## Repo Structure (Target)

```
claude-skills/
├── skills/
│   └── review-code/
│       ├── SKILL.md                    # version in frontmatter, updated by release workflow
│       ├── prpm.json                   # dakaneye-review-code package definition
│       ├── evals/
│       │   ├── evals.json
│       │   └── trigger-evals.json
│       ├── agents/
│       │   ├── ai-spray-detector.md
│       │   ├── bash-pro.md
│       │   ├── code-reviewer.md
│       │   ├── duplicate-code-detector.md
│       │   ├── golang-pro.md
│       │   ├── java-pro.md
│       │   ├── nodejs-principal.md
│       │   ├── pattern-conformance.md
│       │   ├── python-pro.md
│       │   ├── security-auditor.md
│       │   ├── test-automator.md
│       │   └── truth-verifier.md
│       ├── scripts/
│       │   ├── get-failing-checks.sh
│       │   ├── get-pr-context.sh
│       │   ├── gh-issue.sh
│       │   └── pr-context-lib.sh
│       ├── rules/
│       │   ├── bash.md
│       │   ├── go.md
│       │   ├── java.md
│       │   ├── nodejs.md
│       │   ├── python.md
│       │   └── terraform.md
│       ├── concepts/
│       │   ├── code-review.md
│       │   └── language-standards/
│       │       ├── bash/
│       │       ├── go/
│       │       ├── java/
│       │       ├── nodejs/
│       │       ├── python/
│       │       └── terraform/
│       └── patterns/
│           ├── INDEX.md
│           ├── detection-signals.md
│           ├── anti-patterns/
│           ├── architecture/
│           ├── ddd/
│           ├── distributed/
│           ├── enterprise/
│           ├── gof/
│           └── reliability/
├── tests/
│   ├── skill-linter.py                 # scans all skills/*/ — already works
│   └── eval-validator.py               # scans all skills/*/evals/ — already works
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                      # lint + eval + shellcheck across all skills
│   │   └── release.yml                 # per-skill publish via tag prefix
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── dependabot.yml
├── CLAUDE.md
├── README.md                           # collection overview, per-skill install instructions
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
└── LICENSE
```

## Design Decisions

### 1. Self-Contained Skill Directories

Each skill under `skills/<name>/` contains everything it needs: agents, scripts, rules, concepts, patterns, evals, and its own `prpm.json`. This means:

- Adding a skill never conflicts with existing skills
- `prpm.json` file paths are relative to the skill directory
- A skill can be understood by reading one directory

### 2. Per-Skill prpm.json

Each skill has its own `prpm.json` inside `skills/<name>/`. The `files` array uses paths relative to the skill directory (e.g., `agents/golang-pro.md` not `skills/review-code/agents/golang-pro.md`). PRPM publish runs from the skill directory.

### 3. Tag-Driven Versioning

Tags follow the pattern `<skill-name>/v<semver>` (e.g., `review-code/v1.0.5`).

The release workflow:
1. Extracts skill name and version from the tag
2. Checks out the repo
3. Updates `version` in `skills/<name>/prpm.json`
4. Updates `version` in `skills/<name>/SKILL.md` frontmatter
5. Runs `prpm publish` from the skill directory
6. Creates a GitHub Release
7. Pushes a version-bump commit back to main

This makes the tag the single source of truth. No manual version editing.

### 4. CI Across All Skills

The CI workflow runs the same checks for every skill:
- **skill-linter.py** — already scans `skills/*/SKILL.md`
- **eval-validator.py** — already scans `skills/*/evals/`
- **shellcheck** — needs to scan `skills/*/scripts/*.sh` instead of top-level `scripts/`
- **no-hardcoded-paths** — scans all `.md` and `.sh` files
- **validate** — per-skill prpm.json validation (loop over `skills/*/prpm.json`)

### 5. install.sh

The manual install script moves to the skill directory (`skills/review-code/install.sh`) and installs from there. Alternatively, a top-level `install.sh` takes a skill name argument: `./install.sh review-code`. Recommend the latter — one entry point, works for any skill.

### 6. GitHub Repo Rename

Rename `dakaneye/claude-review-code` → `dakaneye/claude-skills`. GitHub auto-redirects the old URL. The PRPM registry entry for `dakaneye-review-code` continues to work; new publishes use the new repo URL.

### 7. README

Top-level README becomes a collection overview:
- List of available skills with one-line descriptions
- Per-skill install instructions (`prpm install dakaneye-review-code`)
- Link to each skill's own README or SKILL.md for details
- Contributing guide for adding new skills

### 8. CLAUDE.md

Updated to reflect multi-skill structure:
- Generic quality gates that apply to all skills
- Per-skill directory conventions
- Adding a new skill checklist

## Migration Plan (High Level)

1. Move `agents/`, `scripts/`, `rules/`, `concepts/`, `patterns/` under `skills/review-code/`
2. Move `prpm.json` to `skills/review-code/prpm.json`, update file paths to be relative
3. Update `install.sh` for new structure
4. Update CI workflow for multi-skill scanning
5. Rewrite release workflow for tag-prefix publishing with auto version bump
6. Update `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`
7. Update skill-linter and eval-validator if needed (likely no changes)
8. Verify all CI checks pass locally
9. Commit, push, verify CI passes on GitHub
10. Rename repo on GitHub (`claude-review-code` → `claude-skills`)
11. Update local git remote

## What This Does NOT Include

- Adding any new skills (review-code only)
- Changing PRPM package name (stays `dakaneye-review-code`)
- Shared libraries between skills (premature — add when needed)
- Workspace/monorepo tooling (unnecessary complexity for markdown + bash)

## Success Criteria

- `python3 tests/skill-linter.py` passes for all skills
- `python3 tests/eval-validator.py` passes for all skills
- `shellcheck -x -S error skills/*/scripts/*.sh` passes
- `prpm publish --dry-run` succeeds from `skills/review-code/`
- Tagging `review-code/v1.0.5` triggers release of only `dakaneye-review-code`
- Adding a future skill requires only: create `skills/<name>/` with SKILL.md + prpm.json + evals
