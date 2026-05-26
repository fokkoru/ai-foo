---
name: peer-review
description: Use when performing an independent, isolated code review of an implementation against its plan/spec before committing — a two-stage (spec compliance, then code quality) review by a reviewer that never sees the development conversation. Runs between df:validate and df:commit.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, TodoWrite, Task, Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git show:*)
---

<objective>
Run an independent, epistemically-isolated code review of the current implementation against its plan/spec.

Dispatch an isolated code-reviewer subagent that sees ONLY the work product (the diff), the spec/plan, and acceptance criteria — never this session's conversation. Review in two stages: spec compliance (a gate), then code quality. Return a severity-ranked report and a verdict.
</objective>

<quick_start>
If a plan/spec path is provided, read it FULLY and begin.
If no plan path is provided, ask for: (1) the plan/spec file path, and (2) optionally a commit range to review. Then wait for input.
</quick_start>

<review_model>
This review is deliberately isolated. A reviewer that sees how the code was built role-plays as the developer and rubber-stamps; a reviewer that sees only the work product reviews the work product. You (the orchestrator) gather artifacts and construct the reviewer's context from those artifacts ONLY.

Two stages, strict order — spec compliance is a gate:
1. **Stage 1 — Spec compliance.** Does the diff implement exactly what the spec requires — no more, no less? If it fails, code quality is irrelevant (a polished implementation of the wrong thing is still wrong). Fix and re-run Stage 1 before proceeding.
2. **Stage 2 — Code quality.** Only after Stage 1 passes: correctness bugs, edge cases, error handling, security, maintainability. Logic over style; never duplicate what the linter/type-checker/CI enforces.
</review_model>

<workflow>

### Step 1: Assemble the work product (main thread)
1. Read the plan/spec FULLY (no limit/offset). Extract the desired end state and acceptance criteria.
2. Determine the review range:
   - Default: everything implemented since the branch diverged — `git merge-base HEAD main` as base, comparing base → working tree (committed + uncommitted). Capture base and head SHAs.
   - If only uncommitted work exists, use `git diff HEAD` (and `git status` for new files).
   - Honor an explicit range if the user gave one.
3. Produce the full diff text and a short description of what was built (one paragraph, factual, from the plan — not from this session's reasoning).

### Step 2: Stage 1 — spec compliance (isolated)
Spawn the `code-reviewer` subagent via Task. Construct its prompt from artifacts ONLY:
- Task description (factual, from the plan)
- The plan/spec text and acceptance criteria
- The commit range (base/head SHA) and the full diff
- The instruction: "Run STAGE 1 (spec compliance)."

Do NOT include this session's conversation, your own reasoning, or what the author intended. Wait for the subagent to finish.

### Step 3: Gate
- If Stage 1 verdict is **FAIL** (Critical/Important spec gaps): present the gaps, fix them (in the main thread or hand back to df:implement), then re-run Step 2 on the updated diff. Do not proceed to Stage 2 until Stage 1 is PASS.
- If **PASS**: continue.

### Step 4: Stage 2 — code quality (isolated)
Spawn `code-reviewer` again, same artifact-only context, with the instruction: "Run STAGE 2 (code quality)." Wait for completion.

### Step 5: Synthesize and present
Combine both stages into one report (template below). State the final verdict: **Approve**, **Approve with fixes**, or **Reject**. Then offer the fix loop: on Approve-with-fixes / Reject, fix and re-review only the changed surface (suppress new minor nits on re-review). The decision to commit stays with the user.

</workflow>

<report_format>
```
## Code Review Report: [Plan/Feature Name]

### Verdict: [Approve | Approve with fixes | Reject]
[1-2 sentence reasoning]

### Stage 1 — Spec Compliance: [PASS | FAIL]
[Spec gaps found, by severity, with file:line and fix — or "none"]

### Stage 2 — Code Quality
#### Critical
- `file:line` — [issue] → [fix]
#### Important
- `file:line` — [issue] → [fix]
#### Minor
- `file:line` — [nit]   (max 5; else "plus N similar minor items")

### Strengths
- [What the implementation gets right]

### Recommended next step
[Fix-and-re-review, or proceed to df:commit — user decides]
```
</report_format>

<guidelines>
- **Be isolated** — the reviewer subagent gets artifacts only; never forward session history.
- **Gate on Stage 1** — never start Stage 2 before spec compliance passes.
- **Be honest about severity** — Critical means blocks commit; don't inflate nits.
- **Logic over style** — skip anything the linter/type-checker/CI enforces.
- **Be read-only** — never modify code during review; fixes happen as an explicit, separate step.
- **Converge on re-review** — after the first pass, suppress new minor nits; report Important+ on the changed surface only.
</guidelines>

<anti_patterns>
- Forwarding the development conversation or your own intent to the reviewer (defeats isolation)
- Starting code-quality review before spec compliance is confirmed (wrong order)
- Nitpicking style, formatting, or anything CI already checks
- Reviewing generated, vendored, or lock files
- Re-reviewing a small fix and accreting new nits each pass
- Marking nits as Critical, or issuing no clear verdict
</anti_patterns>

<circuit_breakers>
Stop and ask the user if:
- The plan/spec cannot be found or has no acceptance criteria to review against
- The diff is empty (nothing to review) or spans unrelated work
- Stage 1 keeps failing after 3 fix attempts (the approach may be wrong — escalate)
- The reviewer returns contradictory findings across stages
- If agent spawning fails with "agent not found" (Codex CLI), the code-reviewer subagent may not be installed — see the plugin README for the `cp codex/agents/*.toml ~/.codex/agents/` step. On Claude Code this should not happen; if it does, reinstall the plugin.

When triggered: present the issue clearly and ask how to proceed.
</circuit_breakers>

<constraints>
- The reviewer subagent MUST receive only artifacts (spec + diff + criteria). NEVER pass this session's conversation or your reasoning — isolation is the whole point.
- Stage 1 is a gate — NEVER run Stage 2 before Stage 1 passes.
- Gather the diff and SHAs before spawning the reviewer — the reviewer needs the exact work product.
- NEVER modify code during review — review is read-only; fixes are a separate, explicit step.
- NEVER run build/test/lint commands without user permission — the user's CLAUDE.md requires this.
</constraints>
