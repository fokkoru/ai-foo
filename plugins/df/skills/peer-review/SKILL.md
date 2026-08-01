---
name: peer-review
description: Use when performing an independent, isolated code review of an implementation against its plan/spec before committing — one isolated reviewer reads the diff from a file and returns a spec-compliance verdict plus quality findings. Runs between df:validate and df:commit.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, TodoWrite, Task, Bash(mktemp:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git show:*)
---

<objective>
Run an independent, epistemically-isolated code review of the current implementation against its plan/spec.

Dispatch an isolated code-reviewer subagent that sees ONLY the work product (the diff, as a file path), the spec/plan, and acceptance criteria — never this session's conversation. One dispatch returns both a spec-compliance verdict and quality findings. Return a severity-ranked report and a verdict.

</objective>

<quick_start>
If a plan/spec path is provided, read it FULLY and begin.
If no plan path is provided, ask for: (1) the plan/spec file path, and (2) optionally a commit range to review. Then wait for input.

</quick_start>

<review_model>
This review is deliberately isolated. A reviewer that sees how the code was built role-plays as the developer and rubber-stamps; a reviewer that sees only the work product reviews the work product. You (the orchestrator) gather artifacts and construct the reviewer's context from those artifacts ONLY.

One dispatch, two verdicts. The reviewer reads the diff once — from a file — and returns both a spec-compliance verdict and quality findings.

Spec compliance governs the **fix order**, not the dispatch order. If the spec verdict is FAIL, fix the spec gaps first: a polished implementation of the wrong thing is still wrong. Quality findings from a failed pass are advisory until the spec verdict passes.

</review_model>

<workflow>

### Step 1: Assemble the work product (main thread)

1. Read the plan/spec FULLY (no limit/offset). Extract the desired end state and acceptance criteria.
2. Determine the review range:
   - Default: everything implemented since the branch diverged — `git merge-base HEAD main` as base, comparing base → working tree (committed + uncommitted). Capture base and head SHAs.
   - If only uncommitted work exists, use `git diff HEAD` (and `git status` for new files).
   - Honor an explicit range if the user gave one.
3. Write the diff to a file. Never into your own context:
   - `mktemp -d` to get a scratch directory
   - `git diff <base> <head> > <dir>/review.diff`

   Do not `cat`, read, or echo the diff. The path is what you pass on. Everything you paste into a dispatch prompt stays resident in your context for the rest of the session and is re-read on every later turn.

   The file is ephemeral and is left for the OS to reap. Do not delete it — `rm` is deliberately not in this skill's `allowed-tools`, and a re-review needs the previous diff to still exist.

4. Write a one-paragraph factual description of what was built, taken from the plan — not from this session's reasoning.

### Step 2: Dispatch the reviewer (isolated)

Spawn the `code-reviewer` subagent via Task. Construct its prompt from artifacts ONLY:

- The factual task description
- The plan/spec text and acceptance criteria
- The commit range (base/head SHA)
- The **path** to the diff file

Do NOT include this session's conversation, your own reasoning, or what the author intended. Do NOT include the diff text. Wait for the subagent to finish.

If the reviewer reports it cannot read the diff file, do NOT paste the diff as a workaround. Stop and tell the user the path was unreachable — that is a sandbox or runtime problem, not a review problem.

### Step 3: Act on the verdicts (bounded fix loop)

A round is one fix pass plus one re-review scoped to the changed surface. **Three rounds maximum.**

Within a round, fix in this order: spec-compliance gaps, then Critical, then Important. `⚠️ CANNOT VERIFY` items are yours to resolve — you hold the cross-phase context the reviewer lacks. Either supply the missing evidence in the next dispatch, or rule on it and write the ruling down.

Re-review by writing a fresh diff file and dispatching again with the changed surface named.

At the cap, every still-open finding gets exactly one written disposition:

| Disposition        | Meaning                                                      |
| ------------------ | ------------------------------------------------------------ |
| Fixed              | Addressed in the diff                                        |
| Parked with ruling | Not a defect — state the reason                              |
| Deferred           | A real defect, deliberately not fixed now — state the reason |
| BLOCKED            | Cannot proceed — escalate to the user                        |

A silent discard is forbidden. A finding you stop working on and do not list is a discarded finding.

### Step 4: Synthesize and present

Combine the reviewer's verdicts and your fix rounds into one report (template below). State the final verdict: **Approve**, **Approve with fixes**, or **Reject**. The decision to commit stays with the user.

</workflow>

<no_pre_judging>
Never tell the reviewer what to ignore. Before sending any dispatch, scan the prompt you wrote for these literal strings:

- "do not flag"
- "don't treat X as a defect"
- "at most Minor"
- "the plan chose"
- "suppress"
- "no need to report"

If any appears, **rewrite the sentence it sits in** so the framing is gone. Deleting only the matched words leaves the bias intact and removes the evidence of it — "this was deliberate, so at most Minor" becomes "this was deliberate, so", which reads the same to a reviewer.

The string scan is a backstop, not the mechanism. The mechanism is Step 2's closed list of artifacts. The gap it does not close is the task description you write in Step 1: "the missing validation was an intentional simplification" matches none of the strings above and pre-judges anyway. Write that paragraph as what the code does, never as why a gap is acceptable.

Scoping is not suppression. To narrow a re-review, name the surface that changed — never name findings the reviewer should not report. Anything the reviewer notices outside that surface comes back under `Out-of-Scope Observations`, where you classify it. Those do not block.

| Excuse                                                        | Reality                                                                                                                                                                           |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "The diff is small — pasting it is simpler than a temp file." | Everything pasted into a dispatch prompt stays resident in your context for the rest of the session and is re-read on every later turn. Size is why it feels safe, not why it is. |
| "The reviewer will waste a turn asking what this was for."    | That is the task description in Step 1, written from the plan. Explaining your reasoning is the thing isolation exists to prevent.                                                |
| "This finding really was deliberate — I'll say so up front."  | Then say it after the verdict, not before. A reviewer told the answer grades your explanation, not the code.                                                                      |
| "Re-review only needs to look at what I changed."             | Correct — name the changed surface. Naming findings it should skip is a different act, and it destroys information you never see.                                                 |

</no_pre_judging>

<report_format>

```
## Code Review Report: [Plan/Feature Name]

### Verdict: [Approve | Approve with fixes | Reject]
[1-2 sentence reasoning]

### Spec Compliance: [PASS | FAIL | ⚠️ CANNOT VERIFY]
[Spec gaps by severity with file:line and fix — or "none".
 For ⚠️, what the reviewer needed and how you resolved it.]

### Quality
#### Critical
- `file:line` — [issue] → [fix]
#### Important
- `file:line` — [issue] → [fix]
#### Minor
- `file:line` — [nit]   (max 5; else "plus N similar minor items")

### Out-of-Scope Observations
- `file:line` — [noticed outside the reviewed surface]   (non-blocking)

### Dispositions
[Only when the round cap was reached. Every open finding, one line each:
 Fixed | Parked with ruling | Deferred | BLOCKED, with the reason.]

### Strengths
- [What the implementation gets right]

### Recommended next step
[Fix-and-re-review, or proceed to df:commit — user decides]
```

</report_format>

<anti_patterns>

- Forwarding the development conversation or your own intent to the reviewer (defeats isolation)
- Pasting the diff into a dispatch prompt instead of passing its file path
- Nitpicking style, formatting, or anything CI already checks
- Reviewing generated, vendored, or lock files
- Letting a finding disappear without a written disposition
- Marking nits as Critical, or issuing no clear verdict

</anti_patterns>

<constraints>
- The reviewer subagent MUST receive only artifacts (spec + diff + criteria). NEVER pass this session's conversation or your reasoning — isolation is the whole point.
- Spec-compliance findings are fixed before quality findings — a polished implementation of the wrong thing is still wrong.
- NEVER paste the diff into a dispatch prompt — pass the file path.
- Write the diff to a file and capture the SHAs before spawning the reviewer — the reviewer needs the exact work product.
- NEVER modify code during review — review is read-only; fixes are a separate, explicit step.
- NEVER run build/test/lint commands without user permission — the user's CLAUDE.md requires this.
- Critical means the finding blocks the commit — reserve it for that, and don't inflate nits to reach it

</constraints>
