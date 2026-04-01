---
name: review-code
description: Comprehensive code review with language-specific expertise. Use PROACTIVELY after writing code, when reviewing PRs, or for security audits. Analyzes for correctness, security, maintainability, and test coverage.
---

# Review Code

Adversarial code review with language-specific expertise and multi-agent validation.

## Usage
```sh
/review-code [PR-URL|file|directory]   # Review PR, file, or directory
/review-code                           # Review current branch's PR or staged changes
```

## Context Gathering Scripts

```sh
~/.claude/skills/dakaneye-review-code/get-pr-context.sh [PR_NUMBER]    # Full PR context
~/.claude/skills/dakaneye-review-code/get-failing-checks.sh [PR_NUMBER] # CI failure logs
~/.claude/skills/dakaneye-review-code/gh-issue.sh [ISSUE_NUMBER]        # Issue context
```

## Review Philosophy

### Principle 0: Radical Candor
State only what is verified and factual. No false positives, no sugar-coating, no hallucinated vulnerabilities. If you cannot assess something, say so. Verify all subagent output before including it.

### Intent Hierarchy
When trade-offs arise, optimize in this order:
1. **Correctness** — Does it work? Does it do what it claims?
2. **Security** — Could this be exploited? Calibrate to context: production API > internal service > CLI tool.
3. **Resilience** — What happens when things go wrong? Partial failures, degraded deps, rollback safety.
4. **Maintainability** — Can someone else understand and modify this? Pattern conformance, DRY, test coverage.
5. **Performance** — Is it efficient enough? Only flag measurable regressions, not theoretical concerns.

### Hermeneutic Thinking: Whole Before Parts
Understand the whole system before judging individual changes. Read the linked issue, understand the broader feature/initiative, read files that import or call the changed code. The meaning of a code change depends on its context — a missing null check in a CLI tool is different from one in a payment API. Only after understanding the whole can you properly evaluate the parts.

### Sequential Thinking: Structured Reasoning
Work through the review systematically rather than reacting to the first thing you see. Consider: What is this code trying to accomplish? How does it fit into the broader system? What are the actual risks vs theoretical concerns? What would break if this fails? What is the author's apparent expertise level? Then apply the adversarial checklist to stress-test your initial assessment.

### Context Calibration
Internal tools have different standards than production services. A CLI has a different threat model than a payment API. Calibrate severity accordingly.

## Agent Dispatch

Count meaningful LOC (exclude generated files, lockfiles, snapshots), then spawn agents in parallel:

| PR Size | Agents |
|---------|--------|
| **Small** (<100 LOC) | Language agent only |
| **Medium** (100-250 LOC) | Language agent + truth-verifier + ai-spray-detector |
| **Large** (>250 LOC) | All: language + truth-verifier + ai-spray-detector + adversarial-reviewer + test-automator (REVIEW MODE) + pattern-conformance + duplicate-code-detector. Add security-auditor for production/security-sensitive code. |

### Language Agent Selection

| Language | Agent | Checklist |
|----------|-------|-----------|
| Go | `golang-pro` | DRIVEC |
| JavaScript/Node | `nodejs-principal` | STREAMS |
| Java | `java-pro` | INVEST |
| Python | `python-pro` | TYPED |
| Bash | `bash-pro` | VEST |
| Rust | `rust-pro` | BORROWS |
| Other | `code-reviewer` | General |

### Agent Handoff Specification

Each agent prompt must include:
- **Problem**: What to review and which dimensions to score
- **Done when**: Specific deliverable (findings with severity + evidence, dimension scores)
- **Constraints**: No false positives on internal tools. No theoretical vulnerabilities without evidence. Do NOT suggest improvements beyond scope. Do NOT add documentation to code you didn't change.
- **Files**: Explicit file list to review

Synthesize all agent outputs before generating the final scorecard. Cross-check for contradictions between agents.

## The Adversarial Checklist

After the neutral "does it work?" pass, assume the author made a mistake. Hunt for these seven failure modes — spawn the `adversarial-reviewer` agent for medium+ PRs:

1. **Authentication & Authorization** — Hardcoded keys, weak permission checks, privilege escalation paths
2. **Data Loss & Rollback** — What happens if this operation fails halfway? Is there a transaction? Can it be reversed?
3. **Race Conditions** — Concurrent access to shared state, async operations finishing in wrong order, TOCTOU
4. **Degraded Dependencies** — What if an external API is slow or down? Missing timeouts, retries, fallbacks, circuit breakers
5. **Version Skew** — Can old and new code coexist during rolling deploy? API version mismatches between services
6. **Schema Drift** — Does this code assume a DB/API schema that could have changed? Migration ordering
7. **Observability Gaps** — Will you know when this breaks in production? Missing logging, metrics, error reporting in critical paths

Not all seven apply to every PR. Skip with justification.

After checking all applicable surfaces, write a **one-sentence bottom line** that states the single most important risk in plain language. Examples: "This code will silently corrupt data under concurrent load." / "If the payment provider goes down, this service hangs forever with no fallback." / "No adversarial concerns — straightforward internal utility."

## PR Scope Assessment (REQUIRED)

Every review MUST include one of:
- "This PR is **human-intentional**: focused scope, coherent changes, appropriate size."
- "This PR shows **AI-spray patterns**: [specifics]. Recommend splitting/trimming."
- "This PR is **mixed**: core changes intentional but includes [X] unrelated changes."

Size thresholds: <150 LOC ideal, 150-250 acceptable, >250 request split (blocker).

## Review Dimensions

| # | Dimension | Key Questions |
|---|-----------|---------------|
| 1 | Functionality | Logic errors, null handling, edge cases, API contracts |
| 2 | Accuracy | Do comments match code? Do names match behavior? |
| 3 | Test Coverage | Are changes tested? Are error cases covered? |
| 4 | Documentation | Updated where necessary? Not over-documented? |
| 5 | No Obvious Commenting | Comments explain why, not what |
| 6 | No AI-Spray | All changes serve stated purpose |
| 7 | No Dead Code | All new functions are actually called from entry points |
| 8 | Manual Testing Evidence | Can the change be verified manually? |
| 9 | Human-Optimized | Code written for humans to read, not machines |
| 10 | Idiomatic Patterns | Follows language conventions |
| 11 | Repository Patterns | Matches existing codebase style |
| 12 | System Design | Appropriate abstractions, separation of concerns |
| 13 | Bullshit Detector | Claims match reality, no glossed complexity |
| 14 | Security | Calibrated to context (production/internal/CLI) |
| 15 | Resilience | Failure handling, rollback safety, degraded dependency behavior |

Scoring: 1-3 blocks merge, 4-5 needs work, 6-7 acceptable, 8-9 good, 10 exceptional.

**Grades**: A (135-150) merge now | B (120-134) merge with suggestions | C (105-119) address feedback | D (90-104) rework | F (<90) major issues

## Feedback Categories

- **Blocker**: Security vulns, data loss, breaking changes, PR too large/unfocused — MUST fix
- **Major**: Perf regressions, missing error handling, inadequate tests, AI-spray, resilience gaps — SHOULD fix
- **Minor**: Style, refactoring opportunities — CONSIDER
- **Discussion**: Architecture decisions, alternatives

## Output Format

```markdown
## Code Review Scorecard

| # | Dimension | Score | Evidence |
|---|-----------|-------|----------|
| 1-15 | ... | X/10 | [brief] |

**Overall**: XX/150 (X.X/10 average)

## PR Scope Assessment
- **Size**: [X LOC] - [Ideal/Acceptable/Too Large]
- **Intent**: [Human-intentional / AI-spray / Mixed]

## Adversarial Assessment
[Which of the 7 attack surfaces were checked. Key findings or "N/A — not applicable because [reason]"]
**Bottom line:** [One sentence — the single most important risk, or "No adversarial concerns."]

## Critical Issues (Blockers)
## Major Issues
## Suggestions
## Praise

## Recommendation
[ ] Approve | [ ] Approve with suggestions | [ ] Request changes | [ ] Request split
```

## Anti-Patterns to Avoid in Reviews

- Don't hallucinate security issues that don't exist
- Internal tools have different standards than production services
- Don't suggest abstractions for one-time operations
- Don't approve PRs that bundle unrelated changes
- `path.join` normalizes paths — don't flag unnecessarily

See also: `~/.claude/skills/dakaneye-review-code/detection-signals.md`, `~/.claude/skills/dakaneye-review-code/code-review.md`
