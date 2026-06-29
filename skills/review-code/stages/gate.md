# Stage 3 — Self-Audit Gate

Certify the drafted review by auditing it with a **separate agent**, looping
until that agent returns `VERDICT: CLEAN`. This is the step that keeps getting
faked, so it is built to be un-fakeable: you (or an earlier stage) drafted the
review, so you cannot also be the one who certifies it. The certification comes
from a fresh agent that takes the drafted review as its input. Its returned
verdict — not your assertion — is the gate.

Run this on a capable model. With a cheaper model drafting Stages 1-2, the gate
is the net that catches what they missed; a gate no stronger than the drafting
mostly rubber-stamps.

## Input

- The drafted, clarified `comment.md` (other-PR mode) or scorecard prose +
  issues (own-code mode) — the output of Stage 2.
- The changed code at PR HEAD (working tree / diff).
- The artifacts directory.

## Output

- A corrected `comment.md` / scorecard with every flagged item fixed or dropped.
- The `## Gate Evidence` block written into `review.md` (per
  `concepts/output-format.md`), with the agent's final verdict table pasted
  verbatim, ending in `VERDICT: CLEAN`.

Nothing proceeds to Stage 4 (emit) until the verdict is CLEAN.

## Procedure

### 1. Verify line anchors (other-PR mode)

Before the audit, confirm every `**L<n>**` marker resolves. For each cited line,
fetch the file at PR HEAD (`git show <head_sha>:<path>` or
`gh api repos/{owner}/{repo}/contents/{path}?ref={head_sha}`) and confirm the
excerpt matches the line number exactly. If they don't match, fix the line number
or drop the comment — don't keep a comment GitHub can't anchor. Mis-anchored
comments are a chronic failure mode: the comment lands on the wrong line or gets
the whole review rejected with HTTP 422.

### 2. Dispatch the verifier

**This is NOT the `truth-verifier` dispatched in Stage 1.** That one reviewed the
*code*. This one reviews *the drafted review*: its input is the comment block, not
the diff. Dispatch a fresh `truth-verifier`, every review, regardless of LOC.

Dispatch `truth-verifier` with this handoff:

- **Input**: the full drafted review (the comment block in other-PR mode; the scorecard prose + issues in own-code mode) AND the changed code (PR HEAD / working tree).
- **Audit every comment on five axes and return a per-comment verdict:**
  1. **Accurate** — does the claim hold at the cited line? Flag misreads, non-bugs asserted as bugs, excerpts that don't match their line number, assumptions stated as fact.
  2. **Framed (BLUF)** — does it lead with the action or risk, not throat-clearing?
  3. **No AI markers** — rigid transitions, hedging, em-dash pile-ups, AI-overused vocab?
  4. **Evergreen** — any temporal language ("recently", "the new code", "now")?
  5. **Useful** — does it change the reader's next action, or should it be dropped?
- **Return format**: one row per comment — `claim | accurate | framed | markers | evergreen | useful | fix needed` — ending in `VERDICT: CLEAN` or `VERDICT: <N> items need fixing`.

### 3. Loop until CLEAN

Fix or drop every flagged item, then re-dispatch the verifier on the corrected
review. Repeat until the agent returns `VERDICT: CLEAN`. Nothing is emitted before
that.

Stages 2 (clarify) and 3 (gate) overlap on axes 2-4 (framing, markers,
evergreen) — clarify already cleaned the prose, so most flags here should be on
axis 1 (accuracy) and axis 5 (usefulness), the two clarify can't fully judge
against the code. A pile of framing/marker flags here means clarify didn't run or
didn't take; fix the prose and note it.

### 4. Write the Gate Evidence block

Paste the agent's final verdict table verbatim into the `## Gate Evidence` block
in `review.md` (format in `concepts/output-format.md`). If you are typing that
table yourself instead of copying an agent's return, you did not run this step —
and asserting you did is the Principle 0 violation this skill most wants to
prevent. A framed, humanized comment that is also wrong is worse than no
comment: it costs the reader time and your credibility.
