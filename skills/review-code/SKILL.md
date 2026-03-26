---
name: review-code
description: Comprehensive code review with language-specific expertise. Use PROACTIVELY after writing code, when reviewing PRs, or for security audits. Analyzes for correctness, security, maintainability, and test coverage.
---

# Review Code

Comprehensive code review with language-specific expertise, truth-focused analysis, and deep sequential thinking.

## Usage
```sh
/review-code [PR-URL|file|directory]   # Review PR, file, or directory
/review-code                           # Review current branch's PR or staged changes
```

## Context Gathering Scripts

```sh
~/.claude/skills/review-code/get-pr-context.sh [PR_NUMBER]    # Full PR context
~/.claude/skills/review-code/get-failing-checks.sh [PR_NUMBER] # CI failure logs
~/.claude/skills/review-code/gh-issue.sh [ISSUE_NUMBER]        # Issue context
```

## Core Principles

### Principle 0: Radical Candor - Truth Above All

- **ABSOLUTE TRUTHFULNESS**: State only what is real, verified, and factual
- **NO FALSE POSITIVES**: Don't hallucinate security issues or theoretical vulnerabilities
- **NO SUGAR-COATING**: If code is bad, say it directly with specific reasoning
- **FAIL BY TELLING THE TRUTH**: If you cannot assess something, say so clearly
- **VERIFY SUBAGENT OUTPUT**: Always inspect results from language agents for accuracy

Key phrases: "That approach will not work because...", "This is factually inaccurate...", "Based on verifiable evidence..."

## Process

### 1. Size-Based Agent Strategy

Count meaningful LOC (exclude generated files, lockfiles, snapshots), then spawn agents:

#### Small PRs (<100 LOC)
Spawn **one** language-specific agent only:
```
Task(subagent_type="<lang-agent>", prompt="Review quality. Apply <MNEMONIC> checklist + AI detection signals. Check for dead code: trace from entry points to verify all new functions are actually called. Files: ...")
```

#### Medium PRs (100-250 LOC)
Spawn **three** agents in parallel:
```
Task(subagent_type="<lang-agent>", prompt="Review quality. Apply <MNEMONIC> checklist. Score dimensions 9, 10. Files: ...")
Task(subagent_type="truth-verifier", prompt="Verify code matches claims. CRITICAL: Trace call graphs from public entry points - flag functions/types that are defined and tested but NEVER CALLED from main paths (dead code). Score dimensions 1, 2, 7, 13. Files: ...")
Task(subagent_type="ai-spray-detector", prompt="Detect AI bloat and scope creep. Score dimensions 5, 6. PR context: ...")
```

#### Large PRs (>250 LOC)
Spawn **full cluster** in parallel:
```
Task(subagent_type="<lang-agent>", prompt="Review quality. Apply <MNEMONIC> checklist. Score dimensions 9, 10.")
Task(subagent_type="truth-verifier", prompt="Verify code matches claims. CRITICAL: Trace call graphs from public entry points - flag functions/types that are defined and tested but NEVER CALLED from main paths (dead code). Score dimensions 1, 2, 7, 13.")
Task(subagent_type="ai-spray-detector", prompt="Detect AI bloat. Score dimensions 5, 6.")
Task(subagent_type="test-automator", prompt="REVIEW MODE: Assess test quality. Score dimensions 3, 8. Do NOT write tests.")
Task(subagent_type="pattern-conformance", prompt="Find existing patterns this code should use. Score dimensions 4, 11, 12.")
Task(subagent_type="duplicate-code-detector", prompt="Find DRY violations and copy-paste code.")
Task(subagent_type="security-auditor", prompt="Deep security review.") # Only for production/security-sensitive code
```

#### Language Agent Selection

| Language | Agent | Checklist |
|----------|-------|-----------|
| Go | `golang-pro` | DRIVEC |
| JavaScript/Node | `nodejs-principal` | STREAMS |
| Java | `java-pro` | INVEST |
| Python | `python-pro` | TYPED |
| Bash | `bash-pro` | VEST |
| Other | `code-reviewer` | General |

**IMPORTANT**: Synthesize all agent outputs before generating the final scorecard.

### 2. Hermeneutic Circle: Understand the Whole FIRST

Before examining code details:

- What feature/system does this PR belong to?
- Read linked issue, epic, or project description
- Read files that import/call the changed code and vice versa
- What conventions does this codebase follow?
- Is this part of a larger initiative?

Only after understanding the whole can you properly evaluate the parts.

### 3. Sequential Thinking Analysis (10 iterations minimum)

1. What is this code trying to accomplish?
2. How does this fit into the broader system?
3. What are the actual risks vs theoretical concerns?
4. What patterns exist in the codebase already?
5. What would break if this code fails?
6. Is this internal tooling or production-facing?
7. What is the author's apparent expertise level?
8. Are there existing tests that define expected behavior?
9. What dependencies are being used and why?
10. Does this change introduce any breaking changes?

**Devil's Advocacy** (11-12): Argue FOR and AGAINST merging as-is.

### 4. PR Scope & Hygiene Assessment (REQUIRED)

#### Size
- **Ideal**: <150 LOC | **Acceptable**: 150-250 LOC | **Too Large**: >250 LOC (blocker)

#### AI-Spray Red Flags
- 10+ files for a "simple fix"
- Comprehensive docs added to every function in scope
- Refactoring surrounding code that wasn't broken
- New utility functions duplicating existing functionality
- "While I was here" changes expanding scope

#### Required Statement
Every review MUST include one of:
- "This PR is **human-intentional**: focused scope, coherent changes, appropriate size."
- "This PR shows **AI-spray patterns**: [issues]. Recommend splitting/trimming."
- "This PR is **mixed**: core changes intentional but includes [X] unrelated changes."

### 5. Review Dimensions

- **Correctness**: Logic errors, null handling, edge cases, API contracts
- **Security**: Production: full OWASP. Internal tools: pragmatic. CLI: different threat model.
- **Performance**: O(n) analysis, resource leaks, N+1 queries, async patterns
- **Inefficiency**: O(n^2) loops, repeated lookups, sequential I/O, regex in loops
- **Maintainability**: Clarity, DRY, SOLID, test coverage
- **Dead Code (CRITICAL)**: Functions/types defined and tested but never called from main entry points. Trace call graphs. Parameters accepted but ignored. Code that passes tests but isn't wired into the system is WORSE than missing code.

## Feedback Categories

- **Blocker**: Security vulns, data loss, breaking changes, PR too large/unfocused — MUST fix
- **Major**: Perf regressions, missing error handling, inadequate tests, AI-spray — SHOULD fix
- **Minor**: Style, refactoring opportunities — CONSIDER
- **Discussion**: Architecture decisions, alternatives

## Staff Eyes Required (REQUIRED OUTPUT)

Flag specific locations where human judgment is irreplaceable. AI code *feels* right but often isn't—include your assessment with each flag.

### Categories

| Category | What to Flag | What Claude CAN'T Verify |
|----------|--------------|--------------------------|
| **INTENT** | Business logic, product decisions, domain constraints | Unstated requirements, regulatory context, "should we build this?" |
| **BOUNDARY** | Auth, authz, input validation, secrets, trust transitions | Threat model adequacy, permission granularity, "who should access what?" |
| **INTEGRATION** | API contracts, schema changes, migrations, cross-system calls | All consumers, backward compatibility, rollback cost, partial failure handling |
| **CONCURRENCY** | Races, locks, channels, shared state, async ordering | Ordering assumptions, visibility guarantees, context cancellation interactions |
| **EXISTENCE** | Package imports, API calls, library methods | Third-party APIs not in context window—hallucination risk increases with obscurity |

### Flag Format

```
#### [CATEGORY] One-line description
**Location:** `path/file.go:42-58` | ~Nm | MUST VERIFY or SHOULD VERIFY
**Verify:** Specific question the human must answer
**Assessment:** [Observed: X] [Gap: Y] [Confidence: HIGH/MED/LOW]
```

### Severity

- **MUST VERIFY** — Do not merge without human confirmation
- **SHOULD VERIFY** — Worth checking, probably fine if skipped

### Confidence (per CLAUDE.md)

- **HIGH** — Verified through code reading; remaining risk is human context/intent
- **MED** — Pattern appears standard, but runtime/integration behavior unverifiable
- **LOW** — Potential issue; insufficient context to assess likelihood or severity

### Calibration Rules

1. **Maximum 5 flags** — More than 5? PR needs decomposition.
2. **Total time < 15 minutes** — Exceeds this? Over-flagging or PR too large.
3. **Justify zero flags on sensitive code** — If PR touches auth/payments/migrations and you flag nothing, state why.
4. **Be specific** — "This is complex" is not actionable.

### Do NOT Flag

- Style issues (formatting, naming)
- Bugs the AI can fix itself
- Missing tests (separate concern)
- "Looks suspicious" without a verification question
- Every database query or API call

### When to Skip

State "No locations require staff verification" when:
- Pure refactors with comprehensive tests
- Trivial changes (<20 LOC), no architectural impact
- Docs-only or test-only (unless testing critical paths)

If skipping on sensitive code, add: "This PR modifies [auth/payments/etc]. No flags because [specific reason]."

## The 14-Dimension Scorecard (REQUIRED OUTPUT)

| Score | Meaning |
|-------|---------|
| 1-3 | Significant problems, blocks merge |
| 4-5 | Below standard, needs work |
| 6-7 | Acceptable, minor issues |
| 8-9 | Good to excellent |
| 10 | Exceptional |

### Dimensions
1. **Functionality** 2. **Accuracy** 3. **Test Coverage** 4. **Documentation** 5. **No Obvious Commenting** 6. **No AI-Spray** 7. **No Dead Code** 8. **Manual Testing Evidence** 9. **Human-Optimized** 10. **Idiomatic Patterns** 11. **Repository Patterns** 12. **System Design** 13. **Bullshit Detector** 14. **Security** (OWASP for production, pragmatic for internal tools, appropriate for CLI threat model)

**Grades**: A (126-140) merge now | B (112-125) merge with suggestions | C (98-111) address feedback | D (84-97) rework | F (<84) major issues

## Output Format

```markdown
## Code Review Scorecard

| # | Dimension | Score | Evidence |
|---|-----------|-------|----------|
| 1-14 | ... | X/10 | [brief] |

**Overall**: XX/140 (X.X/10 average)

## PR Scope Assessment
- **Size**: [X LOC] - [Ideal/Acceptable/Too Large]
- **Intent**: [Human-intentional / AI-spray / Mixed]

## Hermeneutic Assessment
**The Parts**: What do changes accomplish?
**The Whole**: What feature/system does this belong to?
**The Truth**: What is actually happening, stripped of PR description spin?

## Critical Issues (Blockers)
## Major Issues
## Suggestions
## Praise

## Recommendation
[ ] Approve | [ ] Approve with suggestions | [ ] Request changes | [ ] Request split

## Staff Eyes Required

#### [CATEGORY] Description
**Location:** `path:lines` | ~Nm | MUST/SHOULD VERIFY
**Verify:** Question for human
**Assessment:** [Observed: X] [Gap: Y] [Confidence: H/M/L]

**Total: ~Xm** (or "No locations require staff verification")
```

## Anti-Patterns to Avoid in Reviews

- Don't hallucinate security issues that don't exist
- `path.join` normalizes paths — don't flag unnecessarily
- Internal tools have different standards than production services
- Don't suggest abstractions for one-time operations
- Don't approve PRs that bundle unrelated changes

See also: `~/.claude/skills/review-code/detection-signals.md`, `~/.claude/skills/review-code/code-review.md`
