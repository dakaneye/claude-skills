# Stage 4 — Emit

Assemble the final artifacts, check them against the format contract, and
persist them. By the time this stage runs, the content is done: Stage 1 drafted,
Stage 2 (clarify) refined, Stage 3 (gate) audited to CLEAN. This stage is the
last guard on **structure** — it does not re-review or re-word, it makes sure the
artifacts are well-formed and saved. A cheap model is fine here; the checks are
mechanical.

## Input

- The clarified, audited `comment.md` and the `review.md` with its CLEAN Gate
  Evidence block — the outputs of Stages 1-3.
- The artifacts directory.

## Output

- Final `review.md` and (other-PR mode) `comment.md`, persisted to the artifacts
  directory, then emitted inline in the response so they're reviewable before a
  human posts them.

## Procedure

### 1. Confirm the gate actually closed

`review.md` must contain a `## Gate Evidence` block whose Audit table ends in
`VERDICT: CLEAN`. If it doesn't, Stage 3 didn't finish — stop and return to it.
Do not emit an unaudited review.

### 2. Format-compliance check (against `concepts/output-format.md`)

Other-PR mode `comment.md`:
- [ ] First line is `ACTION: <approve|comment|request-changes>`, mapped from the scorecard recommendation.
- [ ] `## Overall` is standalone-readable and does not restate inline comments.
- [ ] Every concern in Overall and every inline comment carries a Conventional Comments label.
- [ ] Every posted label is one of `issue`, `issue (non-blocking)`, or `question`, or is a `suggestion` written inside an issue's comment. **No `nitpick`, `note`, or `praise`** anywhere in the posted comment, and no praise prose.
- [ ] `## Overall` carries at most 3 labeled items.
- [ ] `## File Comments` carries at most 6 inline comments in total.
- [ ] The last line of `## Overall` starts with `_Reviewed by Claude on my behalf` — never omitted, reworded, or moved. An orchestrated skim pass may suffix it (`… — quick pass._`); nothing else may.
- [ ] Each `### \`path\`` / `**L<n>**` is intact; structural elements untouched.

`review.md` (both modes):
- [ ] Opens with the Gate Evidence block, then the scorecard, scope, adversarial bottom line, and recommendation.

Fix structural defects in place — these are mechanical (a missing disclaimer, a
mislabeled comment), not judgment calls. If a fix would change a *claim* or its
*wording*, that's out of scope for emit: a content problem means Stage 2 or 3
didn't finish — return there rather than rewriting here.

### 3. Persist (other-PR mode only)

Save both artifacts in **the artifacts directory the run was given** — the same
absolute path Stage 1 wrote to. Do not relocate them under `~/.claude` if the run
supplied a different path. The two files are:

- `<artifacts-dir>/review.md` — full scorecard
- `<artifacts-dir>/comment.md` — postable comment

For a standalone interactive run with no directory supplied, that path is
`~/.claude/code-reviews/<owner>-<repo>/<YYYY-MM-DD>/<pr#>-<slug>/`.

Slug: derived from the PR title — lowercased, hyphenated, conventional-commit
prefix dropped (`feat(auth):` → `auth-`), truncated to ~40 chars. Match
`batch-review`'s layout exactly so both skills read the same archive.

Then emit both artifacts inline in the response (not just paths) so the comment
block is reviewable before the user pastes it into GitHub.

## Anti-Patterns to Avoid

- Don't hallucinate security issues that don't exist
- Internal tools have different standards than production services
- Don't suggest abstractions for one-time operations
- Don't approve PRs that bundle unrelated changes
- Don't include praise in posted comments — it doesn't change the author's next action and pads the review
- Don't cite line numbers without verifying against the file at PR HEAD — mis-anchored comments are noise
- `path.join` normalizes paths — don't flag unnecessarily
