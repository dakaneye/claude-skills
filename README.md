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
