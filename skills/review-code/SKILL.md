---
name: review-code
description: Comprehensive code review with language-specific expertise. Use PROACTIVELY after writing code, when reviewing PRs, or for security audits. Analyzes for correctness, security, maintainability, and test coverage.
---

# Review Code

Adversarial code review with language-specific expertise and multi-agent validation.

## Review Procedure (follow in order, every review)

Do not jump to output. Work these steps in sequence — steps 4-8 are the gate that produces trustworthy feedback, and they run in **both** modes:

1. **Gather** context (PR/issue/files); pick the mode (see Mode Detection).
2. **Dispatch** agents by size (see Agent Dispatch); run the adversarial checklist.
3. **Score** the 15 dimensions; draft raw feedback.
4. **Frame** every piece of feedback through the `frame` skill (BLUF — action first, evidence second).
5. **Humanize** the framed prose through the `humanize` skill (strip AI markers).
6. **Concise / evergreen / useful** — cut each comment to its shortest useful form; no temporal context; drop any comment that doesn't change the reader's next action.
7. **Truth-verifier loop** — spawn `truth-verifier` against the code; fix or drop every flagged item; re-run until it finds zero inaccuracies. Count the iterations.
8. **Emit** — the review output MUST include a `## Gate Evidence` block (see Output Format) proving steps 4-7 ran. A review without it is incomplete; do not present it.

Steps 4-6 are detailed in the Refinement Pass section; step 7 in the Truth Verification Loop section. If you reach step 8 without having done 4-7, stop and do them.

## Usage
```sh
/review-code [PR-URL|file|directory]   # Review PR, file, or directory
/review-code                           # Review current branch's PR or staged changes
```

## Context Gathering Scripts

```sh
~/.claude/skills/review-code/scripts/get-pr-context.sh [PR_NUMBER]    # Full PR context
~/.claude/skills/review-code/scripts/get-failing-checks.sh [PR_NUMBER] # CI failure logs
~/.claude/skills/review-code/scripts/gh-issue.sh [ISSUE_NUMBER]        # Issue context
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

## Mode Detection

Pick the mode before producing output — they're shaped for different audiences.

- **Other-PR mode**: someone else's PR. Detect when invoked with a PR URL or PR# whose `author.login` (from `gh pr view <pr> --json author`) differs from the local git user (`git config user.email` / `gh api user --jq .login`). Output is shaped for posting back to the author: scorecard + GitHub-postable comment block, both saved to disk. The comment block is framed, humanized, and truth-verified before it posts.
- **Own-code mode**: your own staged changes, a file, a directory, or your own PR. Output is the scorecard alone — no comment block, no disk save. The scorecard's feedback is still framed, humanized, and truth-verified before you see it.

Default when args are ambiguous: if `gh pr view` returns nothing for the current branch, treat as own-code review of staged/uncommitted changes.

When `gh` isn't available (offline, sandbox, no network), fall back to linguistic cues from the prompt itself: third-person framing ("their PR", "Alice's change", "my teammate submitted"), an explicit author name that isn't yours, or any phrasing where the user is clearly the reviewer rather than the author → other-PR mode. Pasted code with no PR context, "I wrote this", "before I open a PR", "my staged changes" → own-code mode.

## Output Format

### Gate Evidence (REQUIRED — both modes, emit first)

Every review MUST open with this block, before the scorecard. It is the proof that procedure steps 4-7 ran. If you cannot fill a row honestly, you have not done that step — go do it. A review missing this block, or with a row left as a placeholder, is incomplete; do not present it.

```markdown
## Gate Evidence

- **Frame** (`frame` skill): [what changed — e.g. "led with the data-loss risk; cut 3 praise openers"]
- **Humanize** (`humanize` skill): [what changed — e.g. "removed 2 'Furthermore,'; broke up 4 uniform sentences"]
- **Concise/evergreen/useful**: [what changed — e.g. "dropped 1 comment that didn't change next action; removed 'the new code'"]
- **Truth-verifier**: PASS after N iteration(s) — [what it flagged and how it resolved, or "clean on first pass"]
```

The Refinement Pass and Truth Verification Loop sections below define each step. Fill each row from what you actually did — invented evidence is a Principle 0 violation and worse than admitting the step was skipped.

### Scorecard (both modes)

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

### GitHub-Postable Comment (other-PR mode only)

After the scorecard, emit a second block shaped for pasting into a GitHub PR review. Each `**L<n>**` marker must reference the file's line number at PR HEAD (post-change) — what GitHub uses to anchor inline comments. This block is what the PR author sees — write it for them.

**Use Conventional Comments prefixes** on every comment (both the Overall summary's individual concerns and each inline comment). The format is `<label> [decoration]: <subject>` — based on [conventionalcomments.org](https://conventionalcomments.org). Many engineering teams require this explicitly (e.g., NetBoxLabs's PR Reviews onboarding doc). Even when not required, prefixes make a review faster to triage.

Labels:
- **issue**: a specific problem — pair with a **suggestion** when you have one
- **question**: a potential concern where you're not sure if it's relevant; the right default when you're new to a codebase or unsure of intent
- **suggestion**: a proposed improvement
- **note**: making the author aware of something; implicitly non-blocking
- **praise**: scorecard-only — do NOT use as a label in posted comments. Praise doesn't change the author's next action, so it pads the review without adding signal.
- **nitpick**: preference-based; implicitly non-blocking

Decoration:
- **(non-blocking)**: doesn't gate merge — add generously for `issue`/`suggestion` when the concern shouldn't hold up the PR

When unsure whether something is an `issue` or a `question`, prefer `question`. The PR author can correct your reading without anyone losing face, and you avoid asserting incorrect claims.

**Don't duplicate inline comments in Overall.** Overall is for the standalone-readable summary — concerns that can't be anchored to a specific line (e.g. "did you verify end-to-end against a real instance?"), plus a one-line gesture toward the inline comments ("left a few inline questions on X and Y"). If a concern has an inline anchor, it lives inline, not in both places. The reader will see the inline comments threaded into the file diff; restating them in Overall is noise.

**No praise in the posted comment** — not in `Overall`, not inline. Praise is accurate but never actionable, so it fails the "will the author's next action change?" test. Keep posted comments tight (2-3 actionable items beats one padded with praise). The scorecard's `## Praise` section is your own record and stays.

**Always end Overall with a disclaimer.** The last line of the `## Overall` section is, verbatim:

> _Reviewed by Claude on my behalf._

This is non-negotiable transparency for the PR author — the comment posts under Sam's name, so it must disclose that Claude produced it. Never omit, reword, or move it.

```markdown
ACTION: <approve|comment|request-changes>

## Overall

[Standalone summary. Lead with what's blocking, what's good, or the single most important thing the author needs to know if they read nothing else. Include concerns that can't be anchored to a specific line; gesture at inline comments without restating them.]

[For each concern raised here, prefix with a Conventional Comments label, e.g.:
**question:** did you verify X end-to-end against Y?
**issue (non-blocking):** Z violates the documented rule about W.]

_Reviewed by Claude on my behalf._

## File Comments

### `path/to/file.ext`

**L<line>** or **L<start>-<end>**
\`\`\`<lang>
[1-10 line excerpt — the chunk being commented on]
\`\`\`
**<label> [decoration]:** [Comment: what's wrong, why it matters, suggested fix. Be specific about line numbers and behavior, not vague concerns.]

**L<line>**
\`\`\`<lang>
[next chunk]
\`\`\`
**<label>:** [next comment]

### `path/to/another-file.ext`

**L<line>**
[...]
```

ACTION mapping from the scorecard recommendation:
- Approve → `approve`
- Approve with suggestions → `comment`
- Request changes / Request split → `request-changes`

Omit `### \`path\`` subsections for files with no inline comments worth making. If no file has inline comments, omit the entire `## File Comments` section and let Overall carry the review.

### Line Number Verification (other-PR mode only)

`**L<n>**` markers anchor inline comments to specific lines in GitHub. They MUST reference the file at PR HEAD (post-change), not diff offsets or hunk-relative positions. Mis-anchored comments are a chronic failure mode here — the comment lands on the wrong line, on an unrelated context line, or gets rejected by GitHub entirely.

Compute correctly: from each hunk header `@@ -A,B +C,D @@`, the new file's section starts at line `C`. Count `+` (added) and context (unchanged) lines from `C`; skip `-` (removed) lines. The result is the line number `git show <head_sha>:<path>` shows.

Verify before emitting: for every cited line, fetch the file at PR HEAD (`git show <head_sha>:<path>` or `gh api repos/{owner}/{repo}/contents/{path}?ref={head_sha}`) and confirm the excerpt matches the line number exactly. If they don't match, fix the line number or drop the comment — don't post a comment GitHub can't anchor.

### Refinement Pass (REQUIRED — both modes)

You MUST refine every piece of feedback before it's emitted — this is not optional in either mode. What you refine depends on mode:
- **Other-PR mode**: the GitHub-postable comment block — the full `## Overall` section and the narrative text after each code excerpt under `## File Comments`.
- **Own-code mode**: the scorecard's prose — the `Evidence` column entries and the `## Critical Issues (Blockers)`, `## Major Issues`, and `## Suggestions` sections.

Run each piece through three passes, in order:

1. **Frame** — run it through the `frame` skill (SCQA/BLUF). Lead with what the reader must act on, then the evidence. A review comment is upward-style communication to a busy reader: the fix or the risk goes first, the supporting detail second. Cut throat-clearing.
2. **Humanize** — run the framed prose through the `humanize` skill to strip AI markers: rigid transitions ("Furthermore,", "Moreover,"), em-dash overuse, hedging ("might", "could", "possibly"), uniform sentence length. These make feedback feel generic and harder to act on.
3. **Edit for concision** — cut every comment to the shortest form that stays concise, evergreen, and useful. Evergreen means no temporal context ("recently changed", "the new code") — the comment must read correctly months later. Useful means it changes the reader's next action; if it doesn't, drop it.

In other-PR mode, leave structural elements verbatim: the `ACTION:` line, `### \`path\`` headers, `**L<n>**` markers, code excerpts, and the `_Reviewed by Claude on my behalf._` disclaimer at the end of Overall.

Why this matters: in other-PR mode the comment lands in another engineer's PR with your name on it; in own-code mode tight, evergreen feedback is what you act on. Framing, humanizing, and tightening are what separate feedback that gets acted on from feedback that gets skimmed.

### Truth Verification Loop (REQUIRED — both modes)

After refining, you MUST verify the feedback is factually accurate before it's emitted — in both modes, every time. Spawn the `truth-verifier` agent against the changed code with the refined feedback:

- **Problem**: Check every claim against the code — at PR HEAD in other-PR mode, against the reviewed files/working tree in own-code mode. Flag any feedback that misreads the code, asserts a bug that isn't real, cites a line that doesn't match its excerpt, or states an unverified assumption as fact.
- **Done when**: Each claim is either confirmed against the code or flagged with the specific inaccuracy and evidence.

Iterate: fix or drop every flagged item, then re-run `truth-verifier` on the corrected feedback. Repeat until it finds no inaccuracies. Nothing is emitted before it survives a clean truth-verifier pass — in other-PR mode that gates persistence and posting; in own-code mode it gates presenting the scorecard.

This is Principle 0 applied to the output, not just the input. A framed, humanized comment that is also wrong is worse than no comment — it costs the reader time and your credibility. Refinement makes the feedback land; verification makes sure what lands is true.

### Persistence (other-PR mode only)

After refining and verifying, save both artifacts so the review survives the session and can be referenced later:

- `~/.claude/code-reviews/<owner>-<repo>/<YYYY-MM-DD>/<pr#>-<slug>/review.md` — full scorecard
- `~/.claude/code-reviews/<owner>-<repo>/<YYYY-MM-DD>/<pr#>-<slug>/comment.md` — humanized GitHub-postable comment

Slug: derived from the PR title — lowercased, hyphenated, conventional-commit prefix dropped (`feat(auth):` → `auth-`), truncated to ~40 chars. Match `batch-review`'s layout exactly so both skills read the same archive and a single PR can be opened by either workflow without surprise.

Then emit both artifacts inline in the response (not just paths) so the comment block is reviewable before the user pastes it into GitHub.

## Anti-Patterns to Avoid in Reviews

- Don't hallucinate security issues that don't exist
- Internal tools have different standards than production services
- Don't suggest abstractions for one-time operations
- Don't approve PRs that bundle unrelated changes
- Don't include praise in posted comments — it doesn't change the author's next action and pads the review
- Don't cite line numbers without verifying against the file at PR HEAD — mis-anchored comments are noise
- `path.join` normalizes paths — don't flag unnecessarily

See also: `~/.claude/skills/review-code/patterns/detection-signals.md`, `~/.claude/skills/review-code/concepts/code-review.md`
