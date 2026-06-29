# Stage 1 — Find

Gather context, dispatch the review fleet, score the 15 dimensions, and draft
the scorecard plus the postable comment. This stage **discovers and drafts**; it
does not refine, audit, or finalize — those are later stages. Everything you
produce here is a draft.

This is the orchestration stage — run it on a capable model. It dispatches
language and adversarial agents whose findings you synthesize; the depth of the
review lives in how well you dispatch and cross-check them.

## Input

- A PR URL, file, or directory to review.
- The mode (other-PR / own-code) — see SKILL.md § Mode Detection.
- The artifacts directory to persist into (other-PR mode): the caller supplies
  it, or default to
  `~/.claude/code-reviews/<owner>-<repo>/<YYYY-MM-DD>/<pr#>-<slug>/`.

## Output

- **Other-PR mode**: write a DRAFT `comment.md` (postable comment, per
  `concepts/output-format.md`) and a DRAFT `review.md` (scorecard, per the same
  file) into the artifacts directory. The Gate Evidence block is NOT written
  yet — Stage 3 (gate) writes it. The comment is raw: not yet framed/humanized
  (Stage 2, clarify) or audited (Stage 3, gate).
- **Own-code mode**: the scorecard prose alone — no `comment.md`, no disk save.

Do not emit the review as finished. The review does not exist until it has been
clarified, audited, and emitted.

## Procedure

### 1. Gather context

```sh
~/.claude/skills/review-code/scripts/get-pr-context.sh [PR_NUMBER]    # Full PR context
~/.claude/skills/review-code/scripts/get-failing-checks.sh [PR_NUMBER] # CI failure logs
~/.claude/skills/review-code/scripts/gh-issue.sh [ISSUE_NUMBER]        # Issue context
```

Read the linked issue and the broader initiative. Read files that import or call
the changed code (SKILL.md § Hermeneutic Thinking — whole before parts).

### 2. Pick the mode

See SKILL.md § Mode Detection. The mode decides the output shape (postable
comment vs scorecard-only) and who the prose is written for.

### 3. Dispatch agents by size

Count meaningful LOC (exclude generated files, lockfiles, snapshots), then spawn
agents in parallel:

| PR Size | Agents |
|---------|--------|
| **Small** (<100 LOC) | Language agent only |
| **Medium** (100-250 LOC) | Language agent + truth-verifier + ai-spray-detector |
| **Large** (>250 LOC) | All: language + truth-verifier + ai-spray-detector + adversarial-reviewer + test-automator (REVIEW MODE) + pattern-conformance + duplicate-code-detector. Add security-auditor for production/security-sensitive code. |

The `truth-verifier` here reviews the **code**. It is a different job from the
Self-Audit Gate's `truth-verifier` (Stage 3), which reviews your **drafted
review**. Do not let one stand in for the other.

#### Language Agent Selection

| Language | Agent | Checklist |
|----------|-------|-----------|
| Go | `golang-pro` | DRIVEC |
| JavaScript/Node | `nodejs-principal` | STREAMS |
| Java | `java-pro` | INVEST |
| Python | `python-pro` | TYPED |
| Bash | `bash-pro` | VEST |
| Rust | `rust-pro` | BORROWS |
| Other | `code-reviewer` | General |

#### Agent Handoff Specification

Each agent prompt must include:
- **Problem**: What to review and which dimensions to score
- **Done when**: Specific deliverable (findings with severity + evidence, dimension scores)
- **Constraints**: No false positives on internal tools. No theoretical vulnerabilities without evidence. Do NOT gold-plate — no improvements, abstractions, or features beyond the diff's scope. Do NOT add documentation to code you didn't change. (Genuine pre-existing *bugs* in the code the diff touches are the exception — surface them as non-blocking follow-ups; see Pre-Existing Issues.)
- **Files**: Explicit file list to review

Synthesize all agent outputs before generating the final scorecard. Cross-check
for contradictions between agents.

### 4. Run the adversarial checklist

After the neutral "does it work?" pass, assume the author made a mistake. Hunt
for these seven failure modes — spawn the `adversarial-reviewer` agent for
medium+ PRs:

1. **Authentication & Authorization** — Hardcoded keys, weak permission checks, privilege escalation paths
2. **Data Loss & Rollback** — What happens if this operation fails halfway? Is there a transaction? Can it be reversed?
3. **Race Conditions** — Concurrent access to shared state, async operations finishing in wrong order, TOCTOU
4. **Degraded Dependencies** — What if an external API is slow or down? Missing timeouts, retries, fallbacks, circuit breakers
5. **Version Skew** — Can old and new code coexist during rolling deploy? API version mismatches between services
6. **Schema Drift** — Does this code assume a DB/API schema that could have changed? Migration ordering
7. **Observability Gaps** — Will you know when this breaks in production? Missing logging, metrics, error reporting in critical paths

Not all seven apply to every PR. Skip with justification. After checking all
applicable surfaces, write a **one-sentence bottom line** that states the single
most important risk in plain language.

### 5. PR Scope Assessment (REQUIRED)

Every review MUST include one of:
- "This PR is **human-intentional**: focused scope, coherent changes, appropriate size."
- "This PR shows **AI-spray patterns**: [specifics]. Recommend splitting/trimming."
- "This PR is **mixed**: core changes intentional but includes [X] unrelated changes."

Size thresholds: <150 LOC ideal, 150-250 acceptable, >250 request split (blocker).

### 6. Score the 15 dimensions

Score per SKILL.md § Review Dimensions. Draft the scorecard and the raw feedback.

Feedback categories:
- **Blocker**: Security vulns, data loss, breaking changes, PR too large/unfocused — MUST fix
- **Major**: Perf regressions, missing error handling, inadequate tests, AI-spray, resilience gaps — SHOULD fix
- **Minor**: Style, refactoring opportunities — CONSIDER
- **Discussion**: Architecture decisions, alternatives

#### Pre-Existing Issues (don't bury a real bug)

"Stay in scope" means don't gold-plate — don't demand refactors, abstractions,
or features the diff never set out to add. It does **not** mean staying silent
about a genuine defect you can see in the code the diff touches. When you spot a
real bug that predates this PR:

- Report it as a **non-blocking follow-up**, clearly marked as pre-existing and outside this PR's scope — own-code mode: under `## Suggestions`; other-PR mode: a `note (non-blocking):` or `issue (non-blocking):` comment.
- Never downgrade or drop a real bug just because it's outside the diff. Surfacing it costs one line; burying it costs an incident.
- The non-blocking lane is for real defects, not scope creep in disguise — still don't invent issues or pad with style nits.

### 7. Draft the artifacts

Draft the scorecard (`review.md`) and, in other-PR mode, the postable comment
(`comment.md`) in the exact shapes defined in `concepts/output-format.md`.

#### Line numbers (compute now, Stage 3 verifies)

Each `**L<n>**` marker must reference the file at PR HEAD (post-change), not diff
offsets or hunk-relative positions. Compute correctly: from each hunk header
`@@ -A,B +C,D @@`, the new file's section starts at line `C`. Count `+` (added)
and context (unchanged) lines from `C`; skip `-` (removed) lines. The result is
the line number `git show <head_sha>:<path>` shows. Stage 3 (gate) verifies every
cited line against PR HEAD, so get them right here.

Write the drafts to disk (other-PR mode), then stop. Stage 2 (clarify) refines
the prose next.
