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

1. Create `skills/<name>/SKILL.md` with frontmatter (name, description with trigger phrases)
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
