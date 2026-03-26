# review-code Skill for Claude Code

[![CI](https://github.com/dakaneye/claude-review-code/actions/workflows/ci.yml/badge.svg)](https://github.com/dakaneye/claude-review-code/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive code review skill with language-specific expertise, truth-focused analysis, and deep sequential thinking.

## Installation

### Via PRPM (Recommended)

```bash
prpm install review-code
```

This installs to `~/.claude/skills/review-code/` with all files as flat siblings.

### Manual Installation

For a structured installation with separate directories:

```bash
git clone https://github.com/dakaneye/claude-review-code.git
cd claude-review-code
./install.sh
```

The manual installer creates the full directory structure in `~/.claude/`.

## Usage

### In Claude Code

```bash
# Review a PR
/review-code https://github.com/org/repo/pull/123

# Review staged changes
/review-code

# Review a specific file or directory
/review-code src/auth/
```

### Helper Scripts

After PRPM install:
```bash
~/.claude/skills/review-code/get-pr-context.sh 123
~/.claude/skills/review-code/get-failing-checks.sh 123
~/.claude/skills/review-code/gh-issue.sh 456
```

After manual install:
```bash
~/.claude/scripts/get-pr-context.sh 123
~/.claude/scripts/get-failing-checks.sh 123
~/.claude/scripts/gh-issue.sh 456
```

## Features

- **Size-based agent strategy**: Spawns appropriate number of review agents based on PR size
- **12 custom subagents**: Language experts, truth-verifier, ai-spray-detector, pattern-conformance, etc.
- **Language-specific checklists**: DRIVEC (Go), STREAMS (Node), INVEST (Java), TYPED (Python), VEST (Bash), STATELOCK (Terraform)
- **AI detection signals**: Identifies over-engineering, dead code, AI-spray patterns
- **14-dimension scorecard**: Comprehensive evaluation with letter grades
- **Staff Eyes Required**: Flags locations needing human judgment
- **Hermeneutic analysis**: Understands context before judging details

## Language Checklists

| Language | Mnemonic | Focus Areas |
|----------|----------|-------------|
| Go | DRIVEC | DRY, Receivers, Interfaces, Validation, Errors, Context |
| Node.js | STREAMS | Security, Types, Reuse, Errors, Async, Modules, Simplicity |
| Java | INVEST | Immutability, Nulls, Validation, Exceptions, Standard lib, Testing |
| Python | TYPED | Types, Yield, Pathlib, Exceptions, Dataclass |
| Bash | VEST | Variables, Errors, Security, Testing |
| Terraform | STATELOCK | Style, Types, Architecture, Testing, Environments, Locking, OIDC, CI/CD, Keep simple |

## Contents

```
claude-review-code/
├── skills/review-code/SKILL.md   # Main skill definition
├── agents/                       # 12 specialized review agents
├── scripts/                      # PR context helper scripts
├── rules/                        # Language quality checklists
├── concepts/                     # Deep dive documentation
│   └── language-standards/       # Per-language references
└── patterns/                     # Design pattern library
    ├── anti-patterns/            # God Object, Anemic Domain, etc.
    ├── architecture/             # Clean, Hexagonal, CQRS, etc.
    ├── gof/                      # Gang of Four patterns
    └── reliability/              # Circuit Breaker, Retry, etc.
```

## Requirements

- Claude Code CLI
- `gh` CLI (GitHub CLI) for PR/issue context
- Git

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
