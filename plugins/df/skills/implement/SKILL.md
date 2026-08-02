---
name: implement
description: Use when implementing a technical plan from the plans directory with verification — continuous by default, or phase-by-phase with human review and a commit per phase when the user asks for phased execution
disable-model-invocation: true
allowed-tools: Read, Write, Edit, LS, Grep, Glob, TodoWrite, Task, Bash(mktemp:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(git rev-parse:*)
---

<objective>
Execute an approved technical plan phase by phase with verification and human checkpoints.

Follow the plan's intent while adapting to codebase reality.

</objective>

<mode_selection>

This skill runs in one of two modes:

**Continuous (default)**: implement phases back to back, stopping only for manual verification items that block the next phase (see Step 3 in the workflow). Use this mode unless the user asks otherwise.

**Phased**: enabled ONLY when the user explicitly asks for it ("phased", "phase by phase", "commit per phase"). If the plan itself calls for a commit per phase but the user did not specify a mode, ask one question before starting — "The plan calls for per-phase commits — run in phased mode?" — never enable phased mode silently.

In phased mode, each phase is a discrete unit: implement → verify → review → commit → next. Always stop after each phase and present a summary:

```
## Phase [N] Complete

**What was done:**
- [List of completed tasks]

**Not done:**
- [Skipped edge cases, deferred work — or "(none)"]

**Automated verification:**
- [x] [Checks that passed]
- [ ] [Checks that failed, if any]

**Manual verification needed:**
- [List manual checks from the plan, or "(none)"]

**Files changed:**
- [List of modified/created files]

Ready to commit Phase [N] and proceed to Phase [N+1], or let me know if anything needs adjusting.
```

Wait for the user to:

- Confirm manual checks passed (if any)
- Report issues that need fixing
- Give permission to commit and continue

If the user reports issues:

- Route them to the implementer as a fix round (Step 3, item 2) — you fix nothing yourself
- Present the updated results from what it returns
- Wait again for confirmation

Repeat until the user is satisfied with the phase.

Once the user approves the phase, commit it:

1. Run `git status` and `git diff HEAD` to review changes
2. Identify the specific files that belong to this phase
3. Write the message per `<commit_format>` — a subject line unless the phase's rationale is
   invisible in its diff
4. Present the commit plan and wait for confirmation:

   ```
   Committing Phase [N]:
     type(scope): description
     body: one paragraph on why ... (omit when subject-only)
     Files: file1.ts, file2.ts

   Proceed?
   ```

5. Stage specific files for this phase: `git add <files>`
6. Commit. Subject only:

   ```bash
   git commit -m "type(scope): description"
   ```

   With a body, a second `-m` becomes the body paragraph — git keeps the line breaks you type:

   ```bash
   git commit -m "type(scope): description" -m "One paragraph on why, wrapped
   at 72 columns."
   ```

7. Verify with `git status`

Do not stage files unrelated to the current phase. If unrelated changes exist, note them and leave them unstaged.

After committing: if more phases remain, continue with the next phase. When all phases are done, present the final summary:

```
## Implementation Complete

All [N] phases implemented and committed:

1. [commit hash] type(scope): Phase 1 description
2. [commit hash] type(scope): Phase 2 description
...

Not done across all phases:
- [Consciously skipped plan items, uncovered edge cases, unverified paths — or "(none)"]

Any remaining manual checks across all phases:
- Phase [X]: [deferred check]

Next: run /df:validate or create a PR.
```

</mode_selection>

<quick_start>
If a plan file path is provided, skip the prompt — go straight to Step 1 and map the plan.

If no plan path is provided, ask the user for the path to the plan file, then wait for input before proceeding.

</quick_start>

<workflow>

### Step 1: Getting Started

1. Map the plan before reading it. Grep it for `^#{1,3} ` to get a section map, then read the preamble through `## Global Constraints` plus every phase's `### Assumptions` block — that is everything the pre-flight scan below needs. Do not read the phase bodies yet: Step 2 reads each phase when it writes that phase's brief, and a phase section read now is re-sent on every turn until it is used. Check for any existing checkmarks (`- [x]`).
2. **Pre-flight conflict scan** — before writing any code, check every phase's `### Assumptions` against the current codebase at its `source:` citation, and the plan's Global Constraints against theirs. This is a targeted existence-and-signature check with Grep and Glob, not a read of every file the plan names: do the cited files, symbols, and APIs exist as the plan describes? Collect every conflict and raise them as **one** batched question:

   ```
   Pre-flight: [N] conflicts between the plan and the current codebase

   1. Phase [N] — Expected: [what the plan says]
                  Found:    [actual state]
                  Impact:   [what breaks if unaddressed]
   2. ...

   How should I proceed?
   ```

   Ask once, then implement. If the scan finds nothing, say so in one line and start. A targeted scan establishes that a name still exists — not that its behaviour is unchanged; the implementer's re-validation at the start of each phase is what catches that. Conflicts that only emerge during implementation are handled by `<deviation_handling>`.

3. Read the original ticket if the plan cites one
4. Take time to ultrathink about how the pieces fit together
5. Create a todo list to track progress
6. Start implementing once the requirements are confirmed understood

Before writing any code: if the plan's approach has a clearly better alternative — one that avoids significant risk or wasted work — say so briefly and wait for the user's call; never push back for minor stylistic preferences. Otherwise implement the plan as approved.

### Step 2: Delegate the phase

Write no source code yourself. Every phase is implemented by a dispatched `phase-implementer`; the controller's job is the brief, the dispatch, and the branch on what comes back.

**Run directory, once.** At the first phase, create one scratch directory with `mktemp -d` and keep its path for the whole run. Every brief, report, and diff lives there — `phase-<N>-brief.md`, `phase-<N>-report.md`, `phase-<N>-round-<R>.diff`. Do not delete it: a later fix round reads the report file, and `rm` is deliberately absent from `allowed-tools`.

**Build the brief.** Write the phase's own section verbatim, then the plan's `## Global Constraints` section verbatim, to `<run-dir>/phase-<N>-brief.md`. Nothing else — not the whole plan, not earlier phases.

**Dispatch.** Spawn `phase-implementer` via `Task`. The prompt carries exactly five things: one line on where this phase sits in the plan; the brief path, introduced as the requirements, with exact values to use verbatim; the `### Produces` blocks of earlier phases in this run that this phase `Consumes`; your resolution of any ambiguity you already noticed; and the report path. Never specify `model` — the implementer inherits this session's. Never dispatch two implementers at once.

**Do not paste.** The brief's contents, the report's contents, and prior phases' summaries never appear in a dispatch prompt — everything travels as a path.

**Branch on the returned status:**

| Status               | What you do                                                                                                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DONE`               | Go to Step 3.                                                                                                                                                                                        |
| `DONE_WITH_CONCERNS` | Read the concerns in the returned message. If they bear on correctness or scope, treat them as findings and open a fix round. If they are observations, note them in the plan file and go to Step 3. |
| `NEEDS_CONTEXT`      | Supply what was missing and re-dispatch. Do not re-dispatch unchanged.                                                                                                                               |
| `BLOCKED`            | Classify the blocker with `<deviation_handling>`. Rule 4 — stop and ask the user, using the format below. Rules 1–3 — supply the missing context or narrow the phase, then re-dispatch.              |

When a blocker classifies as Rule 4, stop and present:

```
Issue in Phase [N]:
Expected: [what the plan says]
Found: [actual situation]
Why this matters: [explanation]

How should I proceed?
```

Never re-dispatch the same agent on the same input. If the implementer said it is stuck, something has to change before the next dispatch.

### Step 3: Verification

After implementing a phase:

1. Record the phase's verification from what the implementer returned. It ran every automated criterion and its report names each command and its output. Do not re-run them — a re-run costs its entire output in the context you are keeping clean and proves what the report already proves. Independent verification is the reviewer's pass on the diff, in Step 3.5.

   For each automated success criterion in the plan:
   - Reported **passing**: mark `[x]` in the plan file
   - Reported **failing**, or not mentioned at all: keep `[ ]` and add a note: `<!-- FAILED: [brief explanation] -->`
   - **Requires manual testing**: leave `[ ]` unchanged

   A criterion the returned summary does not mention is not passing. Treat it as not-run and open a fix round.

2. Route any failure back to the implementer. **Three fix rounds maximum per phase.** A round is one fix dispatch plus the implementer's own re-run of the phase's automated criteria. Send it the failing criteria as it reported them; it appends a fix report to the same report file, carrying the re-run results in the same per-criterion form. Never fix a failure yourself — a controller fix pollutes the context you are keeping clean and skips the phase's verification path. At the cap, stop and give every still-failing criterion exactly one written disposition — Fixed, Parked with ruling, Deferred with reason, or BLOCKED — then ask the user. A criterion you stop working on and do not list is a discarded criterion.

   **Rounds 1 and 2 — resume the same implementer.** Its context is intact: it knows the phase, the code, and its own choices. Send it the open findings verbatim.

   **Round 3 — dispatch a fresh `phase-implementer`** carrying the brief path, the report path, the open findings, and this framing: "A prior implementer attempted this phase twice; you own it now. Read the report file for what was tried." A loop that survives two resumes usually means the implementer cannot see its own problem, and it is looking straight at the attempt that anchors it.

### Step 3.5: Review the phase

Every phase's diff gets one independent `code-reviewer` pass before the phase is marked complete.

**Build the diff as a file.** `git add -N` the phase's new files so they appear in the diff, then `git diff HEAD -- <the files the phase names> > <run-dir>/phase-<N>-round-<R>.diff`. Do not `cat`, read, or echo it — the path is what you pass on.

**Check for unexpected files.** Run `git status --porcelain`: any changed file the phase did not name is a finding in its own right, carried into the dispatch as part of the changed surface.

**Dispatch `code-reviewer`** via `Task`, with exactly four things: a one-paragraph factual description of what the phase was meant to build, taken from the phase's `### Overview` and not from this session's reasoning; the phase section plus its `### Success Criteria`; the commit range; and the diff file path. Never the report file, never the implementer's concerns, never this conversation.

**Never pre-judge.** Do not tell the reviewer what to ignore. If the dispatch you wrote contains "do not flag", "at most Minor", or "the plan chose", rewrite it.

**Act on the verdicts.** Spec `FAIL` or any Critical or Important finding opens a fix round. Minor findings are recorded in the plan file under the phase and do not open a round. `⚠️ CANNOT VERIFY` is yours to resolve — you hold the cross-phase context the reviewer lacks; supply the evidence in the next dispatch, or rule on it and write the ruling into the plan file.

**A finding that contradicts the plan's own text is the user's call.** Present the finding beside the plan text and ask which governs. Do not dismiss the finding because the plan mandates it, and do not dispatch a fix that contradicts the plan without asking.

**Re-review is scoped.** Each round writes a fresh diff over the fix range and names the changed surface. New Critical or Important breakage in the fix diff joins the open findings; observations outside the surface go to the plan file, never into the round count.

Then close out the phase:

3. Update progress in both the plan file and todos
4. Check off completed items in the plan file itself using Edit
5. **Determine whether to continue or stop** (in phased mode, always stop — see `<mode_selection>`):

   Read the phase's success criteria in the plan:
   - If `#### Manual Verification` is **empty, absent, or says "(none)"** → **continue to next phase**
   - If `#### Manual Verification` has items that **block the next phase** → **stop and present**:

     ```
     Phase [N] Complete - Manual Verification Required

     Automated verification passed:
     - [List automated checks that passed]

     Manual verification needed before continuing:
     - [List blocking manual items from the plan]

     Let me know when verified so I can proceed to Phase [N+1].
     ```

   - If `#### Manual Verification` has items that **do NOT block the next phase** (e.g., visual checks, UX polish) → **defer them, continue to next phase**

   At the end of the final phase (or when a blocking manual check is reached), present all deferred manual checks grouped by phase:

   ```
   All automated phases complete. Pending manual verification:

   Phase [X]:
   - [ ] [Deferred manual check]

   Phase [Y]:
   - [ ] [Deferred manual check]

   Not done:
   - [Skipped edge cases, deferred work, unverified paths — or "(none)"]
   ```

6. **For plans without auto/manual split** (older format): Treat all success criteria as automated. Continue without stopping.

Do not check off manual verification items until confirmed by the user.

### When Things Don't Match Expectations

When something isn't working as expected:

- First, check what the implementer's report and the reviewer's findings already say — reading the phase's code yourself is the read you delegated to avoid
- Consider if the codebase has evolved since the plan was written
- Classify it with `<deviation_handling>` — that table decides whether to fix it or stop and ask

Spawn a research sub-task only when the answer is not in the plan or in a file the plan names — targeted debugging, or unfamiliar territory the phase did not describe — and not for an answer a handful of tool calls would settle. `phase-implementer` and `code-reviewer` are exempt from that judgment call: dispatching them is how every phase gets written (Step 2) and reviewed (Step 3.5). When spawning a research sub-task:

| Agent                     | Purpose                            | When to Use                                        |
| ------------------------- | ---------------------------------- | -------------------------------------------------- |
| `codebase-analyzer`       | Understand implementation details  | Debugging unexpected behavior or tracing data flow |
| `codebase-pattern-finder` | Find similar patterns and examples | Looking for usage examples of APIs being modified  |
| `codebase-locator`        | Find files by topic/feature        | Locating related files not mentioned in the plan   |

### Resuming Work

If the plan has existing checkmarks:

- Trust that completed work is done
- Check git log to see which phases were already committed
- Pick up from the first unchecked item
- Verify previous work only if something seems off

</workflow>

<deviation_handling>

When unexpected issues arise during implementation, follow these rules in order:

| Rule | Trigger                                                                        | Action                                               |
| ---- | ------------------------------------------------------------------------------ | ---------------------------------------------------- |
| 1    | Bug found (security, correctness)                                              | Fix immediately, note in plan next to affected phase |
| 2    | Missing critical functionality for phase to work                               | Add it, note in plan next to affected phase          |
| 3    | Blocking issue (build fails, tests break)                                      | Fix it, note in plan next to affected phase          |
| 4    | Architectural change needed (different approach, new dependency, design shift) | **STOP and ask user**                                |

**Priority**: Rule 4 always wins. If a fix might constitute an architectural change, apply Rule 4.

**Tracking**: When auto-fixing (Rules 1-3), add a note in the plan file under the affected phase:

```
> **Deviation**: [Brief description of what was found and fixed]
```

</deviation_handling>

<checkpoint_protocol>

When stopping for manual verification, automate the verification environment first:

- Start dev servers and verify they respond before asking the user to check UI
- Run curl/fetch to confirm endpoints are alive before asking the user to test
- Compile and build before presenting results
- Seed test data if needed for manual testing

**Anti-pattern**: "Please start the dev server and check localhost:3000"
**Correct**: "Dev server running at localhost:3000 (verified responding). Please check that the login form renders correctly."

Never present a manual checkpoint with a broken or unverified environment. The user should only do what requires human judgment.

</checkpoint_protocol>

<commit_format>

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `revert`

A phase commit is a subject line. It earns a body only when the phase's rationale is invisible in
its diff — then read `../commit/references/message-craft.md`, a path relative to the base
directory the harness announces for this skill, before drafting it, supplying the two inputs
`message-craft.md` asks its caller for: the tier, which is Moderate — one paragraph — and the
voice sample, from `git log -5 --pretty=format:'%h %s%n%b'`. A phase commit cannot be split, so if
the body outgrows one paragraph, stop and tell the user.

</commit_format>

<context_budget>

More context isn't automatically better — accuracy and recall degrade as the token count grows ("context rot"). Aim for the smallest high-signal token set per phase: the relevant plan section, the directly-affected files, and the references actually needed. Don't carry forward full history, prior-phase output, or unused tool results.

Before starting a new phase, re-read the plan's checkbox state and run `git log --oneline`. The plan file and git history are the source of truth — not conversation memory or a compaction summary. If context is growing large, say so at the next phase boundary and offer the user a fresh session with the plan path as the entry point — a skill cannot run `/compact` itself. Persistent phase constraints belong in the plan file (and CLAUDE.md), since compaction can drop them from history.

</context_budget>

<success_criteria>

- Each phase passes automated verification
- Manual verification completed by user at blocking checkpoints or deferred to end
- Plan checkboxes updated as work progresses
- Build/test commands execute successfully
- No unresolved mismatches between plan and implementation

</success_criteria>

<anti_patterns>

| Excuse                                                     | Reality                                                                                                                                                                         |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "The plan clearly forgot this — I'll just add it."         | If the plan is wrong, that is Rule 4 in `<deviation_handling>`: stop and ask. Adding it silently means nobody agreed to it.                                                     |
| "I'll commit both phases together, they're related."       | Phased mode exists so each phase can be rejected on its own. One commit means one gate for two decisions.                                                                       |
| "The user will obviously approve this phase."              | Then the confirmation costs one message. Proceeding without it removes their only chance to stop the next phase.                                                                |
| "I'll read the later phases' files now while I'm in here." | They stay resident for every remaining turn, and the phase that needs them reads them anyway. You pay twice for one read.                                                       |
| "I'll re-run the criteria myself, to be sure."             | The implementer ran them and its report names each command and result. Your re-run adds its whole output to the context you delegated to keep clean, and proves the same thing. |
| "It's a one-line fix, dispatching is overhead."            | A controller fix lands in the context you are keeping clean and never passes the phase's verification path. Dispatch it.                                                        |
| "I'll read the phase's files so I can check the work."     | Then you hold the phase's whole read set and the delegation bought nothing. The report says what changed; the diff proves it.                                                   |
| "The phase was small, skip the review."                    | Then nothing independent saw the diff, and checking it yourself is the read you delegated to avoid. Every phase gets one pass.                                                  |
| "One more round and it converges."                         | Past the cap, rounds do not converge — the failure is structural. Give every open finding a disposition and ask.                                                                |

Stay focused on implementing what was actually planned.

</anti_patterns>

<constraints>
- Read the plan's preamble, its Global Constraints, and every phase's `### Assumptions` before starting — read a phase's body only when writing its brief
- Write no source file yourself: every change to a file a phase names is made by a dispatched `phase-implementer`, including every fix round
- Don't re-run an automated criterion the implementer reported passing — its report is the evidence, and your re-run lands in the context the delegation exists to protect
- Dispatch `code-reviewer` on every phase's diff before marking that phase complete — the review is what lets you not read the diff yourself
- Implement one phase at a time — complete verification before moving to the next
- Update checkboxes in the plan as work completes — this is the progress record for resuming later
- Don't check off manual verification items without user confirmation — only the user can verify manual criteria
- Continue to the next phase automatically when manual verification is empty or absent — stopping is the exception, not the rule
- When manual verification exists but doesn't block the next phase, defer it — present all deferred checks at the end grouped by phase

Apply in phased mode:

- Always stop after each phase — never auto-continue to the next phase
- Wait for explicit user confirmation before committing — present the commit plan and the phase results first, then wait
- Don't stage all files — use specific file names for each phase's commit; never `git add .` or `git add -A`
- Don't add AI signatures — no Co-Authored-By or "Generated with" lines in commit messages
- Don't modify code during the commit step — only stage and commit existing changes

</constraints>
