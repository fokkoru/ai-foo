# Log

## 2026-09-06

- **Update**: [The two-line status line](architecture/statusline.md) — two rationales the code and its commit body do not carry. The unobserved-cache figure prints in grey rather than not printing at all, because a blank cost group reads the same as a broken widget; `renderCache` earned a citation of its own for the silence it keeps in that state. And the worktree mark kept no fallback for a Claude Code predating `workspace.git_worktree`, the script having one installation, with the accepted cost stated as behaviour: on an older client the mark stops appearing.

## 2026-09-05

- **Update**: [The two-line status line](architecture/statusline.md) — the worktree mark now reads `workspace.git_worktree` from the payload instead of walking the filesystem for a `.git` file, so the paragraph recording that walk as settled no longer describes the code. The cost group gained a measured last-request figure and a third `next` state for a provider that reports no cache tokens, and the 0.025× cache-read rate is now named as Claude Fable 5.1 and Claude Mythos 5.1 alone. All six citations into `statusline/statusline.mjs` were re-anchored, and `renderCost` earned one of its own.

## 2026-09-04

- **Creation**: [The two-line status line](architecture/statusline.md) — considered [Antigravity execution boundary](architecture/agy-execution-boundary.md), the only other page about wrapping a third-party CLI, which is about permission flags and not about rendering; no existing page covers the status line, and `CLAUDE.md` already names this path as where the installation instruction lives.
- **Update**: [Agent fleet and its tiers](architecture/agent-fleet.md), [Model tiering for dispatched work](decisions/0002-model-tiering-for-dispatched-work.md), [One rule, one place](decisions/0001-one-rule-one-place.md), [A removal names its replacement](decisions/0004-a-removal-names-its-replacement.md) and [The df development workflow](product/df-workflow.md) — the new `## statusline (statusline/)` section in `CLAUDE.md` shifted five line-range citations, two of which then covered blank lines. Re-cited as `## Gotchas` and `## Verify Before Finishing`, the form the schema prescribes for a resource with headings. No prose changed.
- **Update**: [Answer First output style](product/answer-first-style.md) — `plugins/style/README.md` now records two rules the style adds beyond its sources rather than one, the jargon test having joined the end state, and the marketplace entry ships 0.9.0 rather than 0.8.0.

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
- **Update**: [Prompt A/B harness](architecture/prompt-eval-harness.md) — `scripts/eval/check.sh` collapses the four-step comparison into one command that stops at the first failure, so the page described a sequence the README no longer tells you to type. Appended to this section rather than opening a second one for the same date.
- **Update**: [Agent fleet and its tiers](architecture/agent-fleet.md) — re-harvested the `## Subagents` hash. The fragment extractor ended a cited heading at the first `#` comment inside a fenced block, so the recorded hash covered 20 lines of a 31-line section. No prose changed.
- **Creation**: [The rung decides what a prompt edit runs](decisions/0007-the-rung-decides-what-a-prompt-edit-runs.md) — considered [The cell is the unit of analysis](decisions/0003-the-cell-is-the-unit-of-analysis.md), which rules how a comparison is read rather than whether one runs, and [Prompt A/B harness](architecture/prompt-eval-harness.md), which is the machinery and not the gate; neither is the home for a rule about which edits buy a paid run.
- **Update**: [A removal names its replacement](decisions/0004-a-removal-names-its-replacement.md) and [Independent review dispatch](architecture/review-dispatch.md) — both cited `CONTRIBUTING.md` as the single line `L139-L139`, which a later insertion moved without changing. Re-cited as `## Commit Conventions`, the form the schema prescribes for a resource that has headings.
- **Deprecation**: "No worktree isolation for the background lane" removed rather than kept as a stub. Its whole subject — that the background lane shared the main checkout — rested on a note outside the repository, leaving nothing the page could assert.
