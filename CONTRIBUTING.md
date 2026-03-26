# Contributing

Contributions are welcome! Here's how to help.

## Development

```bash
git clone https://github.com/dakaneye/claude-review-code.git
cd claude-review-code
```

## Structure

```
claude-review-code/
├── skills/review-code/SKILL.md  # Main skill entry point
├── agents/                       # Specialized review agents
├── scripts/                      # PR context helper scripts
├── rules/                        # Language quality checklists
├── concepts/                     # Deep dive documentation
└── patterns/                     # Design pattern references
```

## Before Submitting

1. Test changes with Claude Code
2. Ensure scripts are executable and portable (bash, not bashisms)
3. Follow existing markdown formatting
4. Update README if adding new features

## Pull Requests

- Keep changes focused on one concern
- Explain the "why" in your PR description
- Follow existing patterns in the codebase

## Adding Language Support

To add a new language:

1. Create `rules/<lang>.md` with a mnemonic checklist (see existing examples)
2. Create `concepts/language-standards/<lang>/` with deep dive files
3. Create `agents/<lang>-pro.md` with language-specific expertise
4. Update `skills/review-code/SKILL.md` language agent selection table
5. Add AI anti-pattern detection signals for the language

## Reporting Issues

- Use the issue templates
- Include Claude Code version
- Provide reproduction steps if reporting a bug
