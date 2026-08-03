---
name: peer-review
description: Use when performing an independent, isolated code review of an implementation against its plan/spec before committing — one isolated reviewer reads the diff from a file and returns a spec-compliance verdict plus quality findings. Runs between df:validate and df:commit.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, TodoWrite, Task, Bash(mktemp:*), Bash(echo:*), Bash(git add -N:*), Bash(git restore --staged:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git show:*)
---

<objective>
Run an independent, epistemically-isolated code review of the current implementation against its plan/spec.

Dispatch an isolated code-reviewer subagent that sees ONLY the work product (the diff, as a file path), the spec/plan, and acceptance criteria — never this session's conversation. One dispatch returns both a spec-compliance verdict and quality findings. Then dispatch one `finding-verifier` per blocking finding, each seeing that one claim, to refute what it can. Return a severity-ranked report and a verdict.

</objective>

<quick_start>
If a plan/spec path is provided, read it FULLY and begin.
If no plan path is provided, ask for: (1) the plan/spec file path, and (2) optionally a commit range to review. Then wait for input.

</quick_start>

<review_model>
This review is deliberately isolated. A reviewer that sees how the code was built role-plays as the developer and rubber-stamps; a reviewer that sees only the work product reviews the work product. You (the orchestrator) gather artifacts and construct the reviewer's context from those artifacts ONLY.

One finder, then one refuter per blocking finding. The reviewer reads the diff once — from a file — and returns both a spec-compliance verdict and quality findings. Every spec gap and every Critical or Important finding then goes to its own `finding-verifier`, which sees that one claim and tries to kill it. What the reviewer produces is a set of claims about the code; what survives refutation is what you fix.

Spec compliance governs the **fix order**, not the dispatch order. If the spec verdict is FAIL, fix the spec gaps first: a polished implementation of the wrong thing is still wrong. Quality findings from a failed pass are advisory until the spec verdict passes.

</review_model>

<workflow>

### Step 1: Assemble the work product (main thread)

1. Read the plan/spec FULLY (no limit/offset). Extract the desired end state and acceptance criteria.
2. Determine the review range:
   - Default: everything implemented since the branch diverged — `git merge-base HEAD main` as the base, compared against the working tree. Capture that base SHA and the current `HEAD`, and compare them. When they differ, the package covers the commits since the base plus the uncommitted work. When they are equal — which is what `merge-base` returns whenever you are on `main` itself — the package is the uncommitted work only, and every commit already on `main` is outside it. Carry that fact into Step 2 rather than widening the base.
   - Honor an explicit range if the user gave one. Capture both SHAs. An explicit `<base> <head>` covers committed work only.
3. Write the review package to a file. Never into your own context:
   - `mktemp -d` to get a scratch directory
   - `git add -N .` so untracked files appear in the diff — intent-to-add records the path and stages no content
   - Write the package with one simple command per line. For the default range, name **one** revision, not two: a one-revision diff compares that commit against the working tree, which is the range item 2 above describes. Two revisions would drop every uncommitted change, and whenever the base equals `HEAD` they would emit an empty package that reads as a legitimate empty change.

     ```bash
     echo "## Commits" > <dir>/review.diff
     git log --oneline <base>..HEAD >> <dir>/review.diff
     echo "" >> <dir>/review.diff
     echo "## Files changed" >> <dir>/review.diff
     git diff --stat=200 <base> >> <dir>/review.diff
     echo "" >> <dir>/review.diff
     echo "## Diff" >> <dir>/review.diff
     git diff -U10 <base> >> <dir>/review.diff
     ```

     For a user-supplied explicit range, name both revisions instead — `git log --oneline <base>..<head>`, `git diff --stat=200 <base> <head>`, `git diff -U10 <base> <head>` — and skip both the `git add -N` and the `git restore --staged` below. An explicit range asks for committed work only.

     Keep the lines separate: a `{ ...; }` group is an unsafe compound that always prompts, no matter what `allowed-tools` says, while each line above matches a prefix rule on its own. `--stat=200` because `--stat` off a tty wraps at 80 columns and elides long paths to `...`. The wide context is what lets the reviewer judge a hunk without opening the file it came from.

   - `git restore --staged .` once the package is written, undoing the `git add -N .` — on the default path only. Leave those entries behind and they outlive the review: a later `git commit -a` captures them, and `df:commit`'s pre-staged check does not catch them because intent-to-add reports as unstaged.

   Do not `cat`, read, or echo the package. The path is what you pass on. Everything you paste into a dispatch prompt stays resident in your context for the rest of the session and is re-read on every later turn.

   The file is ephemeral and is left for the OS to reap. Do not delete it — `rm` is deliberately not in this skill's `allowed-tools`, and a re-review needs the previous diff to still exist.

4. Write a one-paragraph factual description of what was built, taken from the plan — not from this session's reasoning.

### Step 2: Dispatch the reviewer (isolated)

Spawn the `code-reviewer` subagent via Task. Construct its prompt from artifacts ONLY:

- The factual task description
- The plan/spec text and acceptance criteria
- The review range — the base SHA, plus the head SHA for an explicit range, or "base SHA → working tree" for the default, which is what the package covers. When base and `HEAD` are equal, say that the package is the uncommitted work only and that everything already committed is outside it — the reviewer judges what it was given, so it has to know where the edge is
- The **path** to the diff file
- The review scope, named as `branch-scoped`

Do NOT include this session's conversation, your own reasoning, or what the author intended. Do NOT include the diff text. Wait for the subagent to finish.

If the reviewer reports it cannot read the diff file, do NOT paste the diff as a workaround. Stop and tell the user the path was unreachable — that is a sandbox or runtime problem, not a review problem.

### Step 3: Verify each blocking finding (isolated, parallel)

A finding is a claim about the code, not a fact about it. Test every claim that would cost a fix round before spending one on it.

Dispatch one `finding-verifier` per spec-compliance gap and per Critical or Important finding. Issue every Task call in a single message so they run in parallel. Each dispatch carries exactly three things:

- The **path** to the diff file from Step 1 — never its text
- The plan/spec text the finding is judged against
- Exactly one finding verbatim: its `file:line`, what it claims is wrong, and its claimed severity

Send nothing else — not the reviewer's other findings, not its verdicts, not this session's conversation. Minor findings are never verified: the dispatch costs more than the nit.

Act on what comes back:

| Verdict          | What you do                                                                         |
| ---------------- | ----------------------------------------------------------------------------------- |
| CONFIRMED        | It blocks. Carry it forward at the verifier's severity, not the reviewer's          |
| CANNOT DETERMINE | It blocks exactly as CONFIRMED does — untested is not cleared                       |
| REFUTED          | It clears. Record it under `Refuted` in the report with the evidence that killed it |

The verifier's severity ruling governs, downgrades included: a claimed Critical confirmed as Minor stops blocking and joins the Minor list. A ruling that only ever agrees is not an independent ruling.

Step 4 opens on confirmed findings only. A refuted finding is never fixed — and never quietly dropped either. Write it down with its refutation so the reader can see the claim was tested rather than forgotten.

Each review gets its own verification pass. A re-review in Step 4 that raises a finding again sends it to a fresh verifier against the new diff; within one round, no finding goes to more than one verifier.

### Step 4: Act on the verdicts (bounded fix loop)

A round is one fix pass plus one re-review scoped to the changed surface. **Three rounds maximum.**

Within a round, fix in this order: spec-compliance gaps, then Critical, then Important. `⚠️ CANNOT VERIFY` items are yours to resolve — you hold the cross-phase context the reviewer lacks. Either supply the missing evidence in the next dispatch, or rule on it and write the ruling down.

Re-review by writing a fresh package file — Step 1's commands again, over the fix range and into a new path such as `<dir>/review-round-<R>.diff` so the previous package survives — and dispatching again with the changed surface named.

At the cap, every still-open finding gets exactly one written disposition:

| Disposition        | Meaning                                                      |
| ------------------ | ------------------------------------------------------------ |
| Fixed              | Addressed in the diff                                        |
| Parked with ruling | Not a defect — state the reason                              |
| Deferred           | A real defect, deliberately not fixed now — state the reason |
| BLOCKED            | Cannot proceed — escalate to the user                        |

A silent discard is forbidden. A finding you stop working on and do not list is a discarded finding.

### Step 5: Synthesize and present

Combine the reviewer's verdicts and your fix rounds into one report (template below). State the final verdict: **Approve**, **Approve with fixes**, or **Reject**. The decision to commit stays with the user.

</workflow>

<no_pre_judging>
Never tell the reviewer what to ignore, and never tell a verifier what to conclude. Before sending any dispatch — reviewer or verifier — scan the prompt you wrote for these literal strings:

- "do not flag"
- "don't treat X as a defect"
- "at most Minor"
- "the plan chose"
- "suppress"
- "no need to report"

If any appears, **rewrite the sentence it sits in** so the framing is gone. Deleting only the matched words leaves the bias intact and removes the evidence of it — "this was deliberate, so at most Minor" becomes "this was deliberate, so", which reads the same to a reviewer.

The string scan is a backstop, not the mechanism. The mechanism is Step 2's closed list of artifacts. The gap it does not close is the task description you write in Step 1: "the missing validation was an intentional simplification" matches none of the strings above and pre-judges anyway. Write that paragraph as what the code does, never as why a gap is acceptable.

A verifier dispatch pre-judges in its own form: asserting that the finding is real, that it is serious, or that it is already agreed or already discussed. None of those match the strings above, and each defeats the pass — a verifier told the answer grades the reviewer's prose instead of the code, which is the one thing Step 3 exists to prevent. Send the finding verbatim, and stop there.

Scoping is not suppression. To narrow a re-review, name the surface that changed — never name findings the reviewer should not report. Anything the reviewer notices outside that surface comes back under `Out-of-Scope Observations`, where you classify it. Those do not block.

| Excuse                                                        | Reality                                                                                                                                                                           |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "The diff is small — pasting it is simpler than a temp file." | Everything pasted into a dispatch prompt stays resident in your context for the rest of the session and is re-read on every later turn. Size is why it feels safe, not why it is. |
| "The reviewer will waste a turn asking what this was for."    | That is the task description in Step 1, written from the plan. Explaining your reasoning is the thing isolation exists to prevent.                                                |
| "This finding really was deliberate — I'll say so up front."  | Then say it after the verdict, not before. A reviewer told the answer grades your explanation, not the code.                                                                      |
| "Re-review only needs to look at what I changed."             | Correct — name the changed surface. Naming findings it should skip is a different act, and it destroys information you never see.                                                 |
| "I'll tell the verifier this one is definitely real."         | Then it grades your certainty, not the code. If it is definitely real, the verification costs one dispatch and says so.                                                           |

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

### Refuted
- `file:line` — [finding as reported] → [the evidence the verifier gave for refuting it]
  ("none" when nothing was refuted — this section is never omitted)

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
- Dropping a refuted finding from the report instead of recording it with its refutation
- Marking nits as Critical, or issuing no clear verdict

</anti_patterns>

<constraints>
- The reviewer subagent MUST receive only artifacts (spec + diff + criteria). NEVER pass this session's conversation or your reasoning — isolation is the whole point.
- Every spec-compliance gap and every Critical or Important finding goes to a `finding-verifier` before the fix loop opens — `CANNOT DETERMINE` blocks exactly as `CONFIRMED` does, and only `REFUTED` clears a finding.
- Spec-compliance findings are fixed before quality findings — a polished implementation of the wrong thing is still wrong.
- NEVER paste the diff into a dispatch prompt — pass the file path.
- Write the diff to a file and capture the SHAs before spawning the reviewer — the reviewer needs the exact work product.
- NEVER modify code during review — review is read-only; fixes are a separate, explicit step. The one exception is the index, not any file: Step 1 runs `git add -N .` so untracked files reach the package, and `git restore --staged .` in that same step puts the index back.
- NEVER run build/test/lint commands without user permission — the user's CLAUDE.md requires this.
- Critical means the finding blocks the commit — reserve it for that, and don't inflate nits to reach it

</constraints>
