# Output Format (shared contract)

The exact shape of the two artifacts every review produces. `find` drafts in
this format, `gate` writes the audit verdict into it, and `emit` finalizes and
persists it. Keep one definition here so the stages can't drift apart — a
downstream parser (e.g. the pr-agent dashboard) reads these files by structure,
so the headers, the `ACTION:` line, the `**L<n>**` markers, and the disclaimer
are load-bearing, not decorative.

Two files land in the artifacts directory:

- `review.md` — the scorecard (both modes), opened by the Gate Evidence block.
- `comment.md` — the GitHub-postable comment (other-PR mode only).

## Gate Evidence (REQUIRED — opens `review.md`, both modes)

Every review opens with this block, before the scorecard. The Refine line says
what `clarify` changed. The **Audit** line is the Self-Audit Gate agent's final
verdict table, pasted verbatim — that pasted table, not prose, is what certifies
the review. An Audit line written by hand instead of copied from an agent's
return means the gate did not run.

```markdown
## Gate Evidence

- **Refine (clarify)**: [what clarify changed — e.g. "led with the data-loss risk; cut 3 'Furthermore,'; dropped 1 comment that didn't change next action"]
- **Audit** (truth-verifier on the drafted review, N iteration(s) to CLEAN):
  [paste the agent's final per-comment verdict table here, verbatim, ending in VERDICT: CLEAN]
```

## Scorecard (`review.md`, both modes)

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

## GitHub-Postable Comment (`comment.md`, other-PR mode only)

A block shaped for pasting into a GitHub PR review. Each `**L<n>**` marker must
reference the file's line number at PR HEAD (post-change) — what GitHub uses to
anchor inline comments. This block is what the PR author sees — write it for them.

**Use Conventional Comments prefixes** on every comment (both the Overall
summary's individual concerns and each inline comment). The format is
`<label> [decoration]: <subject>` — based on
[conventionalcomments.org](https://conventionalcomments.org). Many engineering
teams require this explicitly (e.g., NetBoxLabs's PR Reviews onboarding doc).
Even when not required, prefixes make a review faster to triage.

Labels:
- **issue**: a specific problem — pair with a **suggestion** when you have one
- **question**: a potential concern where you're not sure if it's relevant; the right default when you're new to a codebase or unsure of intent
- **suggestion**: a proposed improvement
- **note**: making the author aware of something; implicitly non-blocking
- **praise**: scorecard-only — do NOT use as a label in posted comments. Praise doesn't change the author's next action, so it pads the review without adding signal.
- **nitpick**: preference-based; implicitly non-blocking

Decoration:
- **(non-blocking)**: doesn't gate merge — add generously for `issue`/`suggestion` when the concern shouldn't hold up the PR

When unsure whether something is an `issue` or a `question`, prefer `question`.
The PR author can correct your reading without anyone losing face, and you avoid
asserting incorrect claims.

**Don't duplicate inline comments in Overall.** Overall is for the
standalone-readable summary — concerns that can't be anchored to a specific line
(e.g. "did you verify end-to-end against a real instance?"), plus a one-line
gesture toward the inline comments ("left a few inline questions on X and Y").
If a concern has an inline anchor, it lives inline, not in both places.

**No praise in the posted comment** — not in `Overall`, not inline. Praise is
accurate but never actionable, so it fails the "will the author's next action
change?" test. Keep posted comments tight (2-3 actionable items beats one padded
with praise). The scorecard's `## Praise` section is your own record and stays.

**Always end Overall with a disclaimer.** The last line of the `## Overall`
section is, verbatim:

> _Reviewed by Claude on my behalf._

This is non-negotiable transparency for the PR author — the comment posts under
Sam's name, so it must disclose that Claude produced it. Never omit, reword, or
move it.

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

Omit `### \`path\`` subsections for files with no inline comments worth making.
If no file has inline comments, omit the entire `## File Comments` section and
let Overall carry the review.
