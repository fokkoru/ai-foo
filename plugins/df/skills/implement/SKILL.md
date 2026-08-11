---
name: implement
description: Use when implementing a technical plan from the plans directory with main-thread execution, bounded background work, joined verification, and optional phase-by-phase commits
disable-model-invocation: true
allowed-tools: Read, Write, Edit, LS, Grep, Glob, TodoWrite, Task, Bash(mkdir:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(git rev-parse:*)
---

<objective>
Execute an approved technical plan phase by phase with verification and human checkpoints.

Follow the plan's intent while adapting to codebase reality.

</objective>

<mode_selection>

This skill runs in one of two modes:

**Continuous (default)**: implement phases back to back, stopping only for manual verification items that block the next phase (see Step 3 in the workflow). Use this mode unless the user asks otherwise.

**Phased**: enabled ONLY when the user explicitly asks for it ("phased", "phase by phase", "commit per phase"). If the plan itself calls for a commit per phase but the user did not specify a mode, ask one question before starting — "The plan calls for per-phase commits — run in phased mode?" — never enable phased mode silently.

In phased mode, each phase is a discrete unit: implement → verify → commit → next. That commit is gated by the phase's own success criteria — the plan's `### Acceptance Criteria` run once, before the final phase's commit, so an intermediate commit can be red against a repo-wide check that the finished branch passes. Always stop after each phase and present a summary:

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

- Fix them in the main thread, then re-run the affected checks
- Present the updated results
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

1. Map the plan before reading it. Grep it for `^#{1,3} ` to get a section map, then read the preamble through `## Constraint Check`, `## Execution Schedule` when present, and every phase's `### Assumptions` block — that is everything the pre-flight scan and wave selection need. Read every file the frontmatter's `companions:` names that is not already in your context: `## Constraint Check` names those files instead of quoting them, so a constraint the plan complies with reaches you only through the file itself. Do not read the phase bodies yet: Step 2 reads them when their wave starts, and a phase section read now is re-sent on every turn until it is used. Check for any existing checkmarks (`- [x]`).
2. **Pre-flight conflict scan** — before writing any code, check every phase's `### Assumptions` against the current codebase at its `source:` citation, and the constraints written out under `## Constraint Check` against theirs. This is a targeted existence-and-signature check with Grep and Glob, not a read of every file the plan names: do the cited files, symbols, and APIs exist as the plan describes? Then check each `companions:` entry for drift with `git diff --no-relative --name-only <git_commit> -- ':(top)<companion>'`, where `<git_commit>` is the plan's frontmatter value — a companion is written relative to the repository root, so `:(top)` anchors the pathspec there and `--no-relative` stops a configured `diff.relative` from filtering the answer down to the current directory — a companion that changed since the plan was written is a conflict, because the plan recorded compliance against a version of that file which no longer exists, and nothing else will notice. Collect every conflict and raise them as **one** batched question:

   ```
   Pre-flight: [N] conflicts between the plan and the current codebase

   1. Phase [N] — Expected: [what the plan says]
                  Found:    [actual state]
                  Impact:   [what breaks if unaddressed]
   2. ...

   How should I proceed?
   ```

   Ask once, then implement. If the scan finds nothing, say so in one line and start. A targeted scan establishes that a name still exists — not that its behaviour is unchanged; re-validation when each phase starts is what catches that. Conflicts that only emerge during implementation are handled by `<deviation_handling>`.

3. Create the run directory. Run `git rev-parse --path-format=absolute --git-common-dir` and read its output: `<run-dir>` is that path plus `/df-runs/<plan-slug>`, where `<plan-slug>` is the plan's filename without `.md`. Create it with `mkdir -p "<run-dir>"`, and write `<run-dir>` out in full every time a path goes to a tool or a sub-agent — a relative path resolves against the reader's own directory, which a sub-agent does not share with you. It holds every artifact this run writes — briefs, reports, wave specs, and diffs — and the path is derived from the plan, so a later session given only the plan path finds the same directory. Git tracks nothing under the common directory, so nothing here reaches a diff or a scope check. Then record the run's base in the plan's frontmatter `run_base`: write the output of `git rev-parse HEAD` there, or leave a non-empty value untouched when resuming a run that already wrote one.

   Two plan shapes stop that write and ask the user instead. A plan carrying no frontmatter block has nowhere to hold `run_base`, and every other frontmatter write in this skill leaves such a plan alone rather than adding a block to it — ask the user to add one, since Step 4.5 builds the whole-run diff from that value and cannot run without it. A plan carrying phase checkmarks or a `<!-- FIX ROUND` marker whose `run_base` is empty or absent is a run that started under the old convention, which recorded the base as a bold line in the plan header — ask the user to move that SHA into `run_base` rather than writing the current `HEAD` over it, because the plan is resuming, so `HEAD` is not the run's base, and a silently wrong base makes Step 4.5's whole-run diff start in the middle of the run.

4. Read the original ticket if the plan cites one
5. Take time to ultrathink about how the pieces fit together
6. Create a todo list to track progress
7. Start implementing once the requirements are confirmed understood

Before writing any code: if the plan's approach has a clearly better alternative — one that avoids significant risk or wasted work — say so briefly and wait for the user's call; never push back for minor stylistic preferences. Otherwise implement the plan as approved.

### Step 2: Execute the next wave

**Select the execution shape.** In continuous mode, use `## Execution Schedule` only after checking that every phase appears once, each wave has one main phase and at most one background phase, same-wave files are disjoint, and no same-wave phase consumes the other's output. If the section is absent or invalid, say that parallel execution was downgraded and run every remaining phase as a single-phase main-thread wave. In phased mode, always use single-phase main-thread waves.

**Start the background lane only when it creates overlap.** Both lanes write one checkout. That is bounded on purpose — one worker and never a fan-out, disjoint files claimed in a reviewed plan, a worker forbidden to commit, and every broad check held until the join — and the abort in Step 3.5 is what stops a bad claim from repeating. At the first delegated wave, write the background phase plus `## Constraint Check` verbatim to `<run-dir>/phase-<N>-brief.md`, and under that same heading the plan's `companions:` list with one sentence telling the worker to read any entry it does not already hold — context does not travel with a path, so a section naming sources instead of quoting them reaches an isolated reader as a pointer only it can resolve; use `<run-dir>/phase-<N>-report.md` for its report. Give the brief a `## Concurrently edited` section naming the main phase's files, so the worker can tell which of its citations point at ground you are moving. Dispatch one `phase-implementer` asynchronously, passing paths rather than file contents. On Claude Code set `run_in_background: true` and `model: sonnet`; on another runtime use its non-blocking spawn and request Sonnet only when the interface supports it. If asynchronous dispatch is unavailable, do not spawn — move that phase to the next main-thread wave.

**Work the main lane immediately.** Validate the main phase's assumptions and consumed interfaces against live code, then implement it. Do not launch a worker and wait for it before making progress. Respect the phase's named files; classify any necessary change outside them with `<deviation_handling>`. While the phase is still in progress, run only the focused check that can falsify the change you just made — the phase's full automated criteria run once at the join.

**Join the wave.** Finish the main phase before starting another wave, then collect the background result. A failed dispatch before any worker edit becomes a later main-thread phase. A worker that edited files but returned no usable report becomes `DONE_WITH_CONCERNS`; inspect that changed surface after the join and finish it in the main thread.

| Worker status        | Action                                                                                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DONE`               | Continue to joined verification.                                                                                                                        |
| `DONE_WITH_CONCERNS` | Turn correctness or scope concerns into findings; record observations.                                                                                  |
| `NEEDS_CONTEXT`      | Supply the missing context and resume the worker; never resend unchanged input.                                                                         |
| `BLOCKED`            | Classify with `<deviation_handling>`. For Rules 1–3, supply context or finish after the join. For Rule 4, stop and ask the user using the format below. |

```
Issue in Phase [N]:
Expected: [what the plan says]
Found: [actual situation]
Why this matters: [explanation]

How should I proceed?
```

### Step 3: Verify the joined wave

After every lane has stopped writing, re-validate every assumption the worker reported as deferred, then run the wave's checks in two tiers.

First the union of its phases' `#### Automated Verification` criteria, so a criterion two phases share runs once and not twice. Then `### Wave Checks`, each narrowed to the units holding this wave's files plus every unit its phases declare under `Affects`. Narrow only on that declared basis: a phase whose `Affects` line is missing gives you none, so run the check unnarrowed and say so in one line.

A plan carrying no `### Wave Checks` section predates the tier: hoist every phase criterion that compiles or executes a whole unit, run those here, and name in one line which ones you moved.

Worker checks are useful evidence, but they do not replace joined verification because they may have run while the main lane was changing the shared worktree. The same goes for a deferred assumption: the worker read it against a file you were mid-edit, so only a re-read now settles it.

For each criterion:

- **Passes**: mark `[x]` in the plan file
- **Fails or does not run**: keep `[ ]`, add `<!-- FAILED: [brief explanation] -->`, and open a fix round
- **Requires manual testing**: leave `[ ]` unchanged

**Three fix rounds maximum per phase.** Write `<!-- FIX ROUND <R> -->` under the phase before each round, and read the phase to get `<R>`. A compacted session cannot tell round 1 from round 3, which is the point at which the cap is supposed to stop the loop and ask. Fix a main-phase failure in the main thread. Return a worker-phase failure to the same implementer for rounds 1 and 2 when it can be resumed; on round 3 use a fresh `phase-implementer` carrying the brief, report, and open findings. The main thread owns a finding that crosses both lanes. After each fix, re-run only the focused criteria covering the amended code; `### Wave Checks` run once more after the wave's last round, never inside one. At the cap, give every open criterion one disposition — Fixed, Parked with ruling, Deferred with reason, or BLOCKED — then ask the user.

### Step 3.5: Review the wave

Run one integrated `code-reviewer` pass over every wave, not one pass per phase. A wave whose phases all ran in the main thread is reviewed exactly like a delegated one: you hold the whole implementation conversation in context, and that is the non-independence this pass exists to remove.

Write `<run-dir>/wave-<N>-spec.md` with every phase section in the wave plus `## Constraint Check`, and under that heading the plan's `companions:` list with one sentence telling the reviewer to read any entry it does not already hold. Build `<run-dir>/wave-<N>-round-<R>.diff` from the union of the wave's named files. Reach the wave's new files with `git add -N -- ':(top)<the wave's new files>'`, and undo it afterwards with `git restore --staged -- ':(top)<the same paths>'`. The pathspec is those named files in both directions, never `.` — a bare pathspec reaches the whole index and unstages work the user staged before the run — and `:(top)` anchors it at the repository root, because a plan names its files from there and the session's directory need not be it. Run `git status --porcelain`; any changed file outside the union is a scope finding.

The plan file is neither a scope finding nor a collision — this run edits it. In a delegated wave, two observations are collisions rather than scope findings: a changed file outside the union that the main lane did not itself edit and the worker's report names, and a file the worker reports changing that the main phase also changed. When the worker returned no usable report, treat any changed file outside the union that the main lane did not itself edit as a collision — that is where corroboration is unavailable, so that is where the conservative reading belongs. On any of these, write `> **Deviation**: collision — <what was observed>; background lane disabled for this run` under the affected phase, and run every remaining wave as a single-phase main-thread wave. Do not re-enable the lane for this run; the claim that produced the collision is the one the schedule kept making.

Before sending any dispatch — reviewer or verifier — scan the prompt you wrote for "do not flag", "don't treat X as a defect", "at most Minor", "the plan chose", "suppress", and "no need to report". Rewrite the sentence any of them sits in: deleting the matched words leaves the bias and removes the evidence of it. A verifier dispatch pre-judges in its own form — asserting the finding is real, serious, or already agreed — so send the finding verbatim and stop there.

Dispatch `code-reviewer` with the wave overview, spec path, commit range, diff path, and `task-scoped`. Name no model — the agent's own default tier applies, because a wave can carry more than one phase and nothing has measured a cheaper tier at that width. Never send the worker report or this conversation.

Verify every spec gap and Critical or Important finding with one `finding-verifier` per finding, dispatched in parallel. Collect every verifier before acting on any verdict. Where a runtime's wait returns the first finisher, keep waiting and release each finished agent until all have reported — acting on a partial roster spends a fix round on a finding the rest would have refuted, and an unreleased agent holds the slot the next dispatch needs. `REFUTED` clears it; `CONFIRMED` and `CANNOT DETERMINE` keep it blocking. A `⚠️ CANNOT VERIFY` item is not a finding and does not go to a verifier — you hold the plan and the cross-wave context the reviewer lacks, so resolve each one yourself before closing the wave. One that names a path it could not read is a runtime problem, not a review result — fix the path and re-dispatch, because resolving it yourself closes a wave whose review never ran. Confirmed as a real gap, it enters the fix round as a spec failure. Act on the verifier's severity, record refutations and Minor findings under the affected phase, and route blocking fixes by file ownership using Step 3's fix rules. A cross-lane finding belongs to the main thread after the join. Re-review only the fix diff.

A finding that contradicts the plan is the user's call: present both texts and ask which governs.

Then close out every phase in the wave:

1. Update progress in both the plan file and todos
2. Check off completed items in the plan file itself using Edit
3. **Determine whether to continue or stop** (in phased mode, always stop — see `<mode_selection>`):

   Read every phase's success criteria in the wave:
   - If every `#### Manual Verification` is **empty, absent, or says "(none)"** → **continue to the next wave**
   - If any `#### Manual Verification` item **blocks the next wave** → **stop and present**:

     ```
     Phase [N] Complete - Manual Verification Required

     Automated verification passed:
     - [List automated checks that passed]

     Manual verification needed before continuing:
     - [List blocking manual items from the plan]

     Let me know when verified so I can proceed to the next wave.
     ```

   - If manual items do **not** block the next wave (e.g., visual checks, UX polish) → **defer them and continue**

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

4. **For plans without auto/manual split**: Treat all success criteria as automated. Continue without stopping.

Do not check off manual verification items until confirmed by the user.

### Step 4: Verify the finished plan

After the final wave, run the plan's `### Acceptance Criteria` once. They are the plan-level checks — the repo-wide commands and the end-to-end behaviour no single phase can prove — and this is the only place `df:implement` runs them. Mark each one with Step 3's three outcomes, and open a fix round on a failure under Step 3's cap. A criterion needing human judgment stays unchecked and joins the deferred manual list.

Start these commands in the background so Step 4.5's review can run while they work — a reviewer writes nothing, so the two cannot interfere, and a repo-wide command is usually the longest single wait in the run. If one is interrupted, read the output it already produced before restarting: a failure it already printed is one you can fix now, which makes the restart the last one rather than the second of three.

In phased mode, run this after the final phase's own checks and before its commit.

Once every criterion is checked or dispositioned, set the plan's frontmatter `status: implemented` and `last_updated` to today's date as `YYYY-MM-DD`. Skip silently when the plan has no frontmatter block — Step 1 stops such a plan before this point, so this fires only when the user chose to continue past that question.

Report the outcome in the final summary: which acceptance criteria passed, which failed, and which need the user. This report covers `### Acceptance Criteria` only — it does not stand in for a phase's pending manual verification.

### Step 4.5: Review the run

Run one `branch-scoped` `code-reviewer` pass over the whole run when it executed more than one wave. A single-wave run needs no second pass — Step 3.5 already reviewed exactly that diff. Nothing else reviews wave integration, because every wave diff is built from that wave's named files only.

Write `<run-dir>/run-spec.md` with the plan's `### End State`, `### Acceptance Criteria`, and `## Constraint Check`, and under that heading the plan's `companions:` list with one sentence telling the reviewer to read any entry it does not already hold. Build `<run-dir>/run-round-<R>.diff` exactly as Step 3.5 builds a wave diff, over the union of every wave's named files and the plan's frontmatter `run_base` SHA. Dispatch with the plan's overview, both paths, that base SHA, and `branch-scoped`. Verify, route, and dispose of findings under Step 3.5's rules, then re-run any acceptance criterion a fix touched.

In phased mode, run this after Step 4 and before the final phase's commit. A fix it produces that reaches an earlier phase's files is its own commit — phased mode exists so each phase can be rejected on its own, and folding a cross-phase fix into the last one takes that away.

`/df:peer-review` still covers the branch from its merge-base, including commits made before this run. This pass covers this run.

### When Things Don't Match Expectations

When something isn't working as expected:

- Inspect the relevant live code together with any implementer report and reviewer findings
- Consider if the codebase has evolved since the plan was written
- Classify it with `<deviation_handling>` — that table decides whether to fix it or stop and ask

Spawn a research sub-task only when the answer is not in the plan or in a file the plan names — targeted debugging, or unfamiliar territory the phase did not describe — and not for an answer a handful of tool calls would settle. `phase-implementer` is reserved for the scheduled background lane and `code-reviewer` for Step 3.5 — neither is a research sub-task. When spawning a research sub-task:

| Agent                     | Purpose                            | When to Use                                        |
| ------------------------- | ---------------------------------- | -------------------------------------------------- |
| `codebase-analyzer`       | Understand implementation details  | Debugging unexpected behavior or tracing data flow |
| `codebase-pattern-finder` | Find similar patterns and examples | Looking for usage examples of APIs being modified  |
| `codebase-locator`        | Find files by topic/feature        | Locating related files not mentioned in the plan   |

### Resuming Work

If the plan has existing checkmarks:

- Read the plan's run marks — frontmatter `run_base`, `<!-- FIX ROUND <R> -->` under each phase, and any collision deviation note — before selecting the next wave
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

Before starting a new wave, re-read the plan's checkbox state and run `git log --oneline`. The plan file and git history are the source of truth — not conversation memory or a compaction summary. If context is growing large, say so at the next wave boundary and offer the user a fresh session with the plan path as the entry point — a skill cannot run `/compact` itself. Persistent phase constraints belong in the plan file (and CLAUDE.md), since compaction can drop them from history.

</context_budget>

<success_criteria>

- Every wave's automated criteria are marked in the plan file — `[x]` when they passed, `[ ]` with a `<!-- FAILED: ... -->` note when they did not
- The plan's `### Acceptance Criteria` carries a disposition for every item
- Manual verification is either confirmed by the user or presented as deferred, grouped by phase
- No unresolved mismatch between plan and implementation

</success_criteria>

<anti_patterns>

| Excuse                                                          | Reality                                                                                                                                                                                     |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "The plan clearly forgot this — I'll just add it."              | If the plan is wrong, that is Rule 4 in `<deviation_handling>`: stop and ask. Adding it silently means nobody agreed to it.                                                                 |
| "I'll commit both phases together, they're related."            | Phased mode exists so each phase can be rejected on its own. One commit means one gate for two decisions.                                                                                   |
| "The user will obviously approve this phase."                   | Then the confirmation costs one message. Proceeding without it removes their only chance to stop the next phase.                                                                            |
| "I'll read the later phases' files now while I'm in here."      | They stay resident for every remaining turn, and the phase that needs them reads them anyway. You pay twice for one read.                                                                   |
| "The plan has no schedule, but these phases look independent."  | Parallel writes need an explicit reviewed claim. Run them in the main thread instead of inferring ownership during execution.                                                               |
| "I'll launch the worker now and wait."                          | A background lane exists only to overlap useful main-thread work. If there is no main phase to execute, do not dispatch it.                                                                 |
| "The files are disjoint, so both lanes can run the full suite." | Both lanes still share one worktree. Run wave, broad, and acceptance checks only after the join.                                                                                            |
| "One more full-suite run, just to be sure."                     | Sure of what? Nothing has changed since the last one. It returns the same verdict plus a second copy of its output, which stays resident for the rest of the run.                           |
| "This build only takes a minute — per phase is fine."           | A run has several waves and a wave can carry two phases, so per-phase means paying that minute on every one of them.                                                                        |
| "The fix touched that package, so re-run its checks now."       | Three rounds means three runs of one package check for one wave. Run the focused check covering the fix; the package check runs once, after the last round.                                 |
| "No `Affects` line, but nothing else can depend on this."       | Narrowing needs a declared claim, the same way parallel execution does. Run the check unnarrowed and say so — inferring the dependents here is the guess the declaration exists to replace. |
| "The schedule says parallel, so I don't need to validate it."   | Plans drift. A stale file or interface list turns safe overlap into a collision; downgrade the wave instead.                                                                                |
| "This finding is obviously real — verifying it is waste."       | Then the verifier costs one dispatch and confirms it. The findings that are obviously real are not the ones the gate exists for.                                                            |
| "It was refuted, so there's nothing to record."                 | A refuted finding that leaves no trace is indistinguishable from one you dropped. The refutation is the evidence that the gate did its job.                                                 |
| "One more round and it converges."                              | Past the cap, rounds do not converge — the failure is structural. Give every open finding a disposition and ask.                                                                            |

Stay focused on implementing what was actually planned.

</anti_patterns>

<constraints>
- Read the plan's preamble, Constraint Check, Execution Schedule when present, and every phase's `### Assumptions` before starting, and read every `companions:` entry not already in your context — read a phase body when its wave starts
- Keep one main-thread phase in every wave; dispatch at most one background implementer, and only from a valid explicit schedule
- If asynchronous dispatch is unavailable, or the schedule is absent or invalid, execute the affected phases in the main thread
- Stop dispatching the background lane for the rest of the run once a collision is recorded in the plan — a schedule that collided once is evidence, not a one-off
- Join every lane before wave or acceptance checks, integration fixes, review, progress updates, or the next wave
- Run `### Wave Checks` once per wave, and once more after the wave's last fix round — never inside one
- Narrow a wave check only to the units holding that wave's files plus the units its phases declare under `Affects` — a phase declaring none leaves the check unnarrowed
- Run the plan's `### Acceptance Criteria` once, after the final wave — not per phase and not per wave
- Dispatch one task-scoped `code-reviewer` for every wave — a wave that ran entirely in the main thread is reviewed exactly like a delegated one
- After the final wave of a run that executed more than one wave, dispatch one `branch-scoped` `code-reviewer` over the whole run diff — a wave review never sees how two waves fit together
- Verify every spec gap and every Critical or Important finding with `finding-verifier` before opening a fix round — the reviewer's severity is self-assigned and nothing else checks it
- Update checkboxes in the plan as work completes — this is the progress record for resuming later
- Don't check off manual verification items without user confirmation — only the user can verify manual criteria
- Continue to the next wave automatically when manual verification is empty or absent — stopping is the exception, not the rule
- When manual verification exists but doesn't block the next wave, defer it — present all deferred checks at the end grouped by phase

Apply in phased mode:

- Execute every phase in the main thread — do not dispatch `phase-implementer`
- Always stop after each phase — never auto-continue to the next phase
- Wait for explicit user confirmation before committing — present the commit plan and the phase results first, then wait
- Don't stage all files — use specific file names for each phase's commit; never `git add .` or `git add -A`
- Don't add AI signatures — no Co-Authored-By or "Generated with" lines in commit messages
- Don't modify code during the commit step — only stage and commit existing changes

</constraints>
