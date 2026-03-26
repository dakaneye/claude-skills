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

## Releasing

Releases are published to [PRPM](https://prpm.dev) via GitHub Actions on tag push.

### Release Flow

1. **Update version** in `prpm.json`
2. **Commit** the version bump:
   ```bash
   git add prpm.json
   git commit -m "chore: bump version to X.Y.Z"
   git push origin main
   ```
3. **Tag and push**:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

CI will automatically publish to PRPM and create a GitHub Release.

### PRPM Token Refresh

The `PRPM_TOKEN` secret is a JWT from GitHub OAuth that **expires periodically**. If the release workflow fails with auth errors:

1. **Re-authenticate locally**:
   ```bash
   prpm login
   ```

2. **Update the GitHub secret**:
   ```bash
   gh secret set PRPM_TOKEN --repo dakaneye/claude-review-code < <(jq -r '.token' ~/.prpmrc)
   ```

3. **Retry the release** (delete and re-push tag, or push a new version)

### Manual Release (Alternative)

If CI is unavailable, publish directly:

```bash
prpm publish --dry-run  # Validate first
prpm publish            # Publish to registry
```
