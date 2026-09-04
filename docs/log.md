# Log

## 2026-09-03

- **Creation**: seeded the bundle from `references/wiki-template.md`; `docs/` was empty, so every page below is a first page and no existing page was considered.
- **Creation**: [Prompt A/B harness](architecture/prompt-eval-harness.md) — the machinery under `scripts/eval/` had no page, and the harness README defers its reasoning to this bundle.
- **Creation**: [Independent review dispatch](architecture/review-dispatch.md) — how a run is reviewed is a mechanism, distinct from the tier the reviewer runs at.
- **Creation**: [Agent fleet and its tiers](architecture/agent-fleet.md) — the fleet is what the tiering decision is applied to, and the two would drift if written as one page.
- **Creation**: [Antigravity execution boundary](architecture/agy-execution-boundary.md) — a measured permission table belongs beside the mechanism, not inside the decision that chose one row of it.
- **Creation**: [Answer First output style](product/answer-first-style.md) — what the style does for a user, separate from the harness mechanics its README covers.
- **Creation**: [The df development workflow](product/df-workflow.md) — the chain and its per-step guarantees, and the home for the general research-plan-implement background.
- **Creation**: [One rule, one place](decisions/0001-one-rule-one-place.md) — a rule in effect, evidenced in `CLAUDE.md`.
- **Creation**: [Model tiering for dispatched work](decisions/0002-model-tiering-for-dispatched-work.md) — the reviewer floor and the effort-before-model ordering are one rule with one evidence base, so they are one page.
- **Creation**: [The cell is the unit of analysis](decisions/0003-the-cell-is-the-unit-of-analysis.md) — the reading rule the harness implements, kept apart from the harness page so a script change does not rewrite the reasoning.
- **Creation**: [A removal names its replacement](decisions/0004-a-removal-names-its-replacement.md) — a rule in effect, evidenced in `CONTRIBUTING.md`.
- **Creation**: [Antigravity runs under accept-edits](decisions/0006-agy-runs-under-accept-edits.md) — the permission choice is a rule in effect, evidenced in both skills' constraints.
- **Update**: dropped every `thoughts/` citation from the bundle. `thoughts/` is not tracked by git, so those twenty-two entries named files no clone has and `check-docs.sh check` failed for anyone but the author. Claims a tracked file also carries were re-anchored to it; claims nothing tracked carries were removed with the prose they supported.
- **Deprecation**: "No worktree isolation for the background lane" removed rather than kept as a stub. Its whole subject — that the background lane shared the main checkout — rested on a note outside the repository, leaving nothing the page could assert.
