---
name: implement
description: Use when implementing a technical plan from the plans directory one phase at a time in the main thread, with per-phase verification and independent review, and optional phase-by-phase commits
disable-model-invocation: true
allowed-tools: Read, Write, Edit, LS, Grep, Glob, TodoWrite, Task, Bash(grep:*), Bash(mkdir:*), Bash(git log:*), Bash(git stash create:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(git rev-parse:*)
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

1. Map the plan before reading it. Grep it for `^#{1,3} ` to get a section map, then read the preamble through `## Constraint Check` and every phase's `### Assumptions` block — that is everything the pre-flight scan needs. Read every file the frontmatter's `companions:` names that is not already in your context: `## Constraint Check` names those files instead of quoting them, so a constraint the plan complies with reaches you only through the file itself. Do not read the phase bodies yet: Step 2 reads a phase body when that phase starts, and a phase section read now is re-sent on every turn until it is used. Check for any existing checkmarks (`- [x]`).
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

3. Create the run directory. Run `git rev-parse --path-format=absolute --git-common-dir` and read its output: `<run-dir>` is that path plus `/df-runs/<plan-slug>`, where `<plan-slug>` is the plan's filename without `.md`. Create it with `mkdir -p "<run-dir>"`, and write `<run-dir>` out in full every time a path goes to a tool or a sub-agent — a relative path resolves against the reader's own directory, which a sub-agent does not share with you. It holds every artifact this run writes — phase specs, the run spec, each phase's recorded base, and diffs — and the path is derived from the plan, so a later session given only the plan path finds the same directory. Git tracks nothing under the common directory, so nothing here reaches a diff or a scope check. Then record the run's base in the plan's frontmatter `run_base`: write the output of `git rev-parse HEAD` there, or leave a non-empty value untouched when resuming a run that already wrote one.

   Two plan shapes stop that write and ask the user instead. A plan carrying no frontmatter block has nowhere to hold `run_base`, and every other frontmatter write in this skill leaves such a plan alone rather than adding a block to it — ask the user to add one, since Step 4.5 builds the whole-run diff from that value and cannot run without it. A plan carrying phase checkmarks or a `<!-- FIX ROUND` marker whose `run_base` is empty or absent is a run that started under the old convention, which recorded the base as a bold line in the plan header — ask the user to move that SHA into `run_base` rather than writing the current `HEAD` over it, because the plan is resuming, so `HEAD` is not the run's base, and a silently wrong base makes Step 4.5's whole-run diff start in the middle of the run.

4. Read the original ticket if the plan cites one
5. Take time to ultrathink about how the pieces fit together
6. Create a todo list to track progress
7. Start implementing once the requirements are confirmed understood

Before writing any code: if the plan's approach has a clearly better alternative — one that avoids significant risk or wasted work — say so briefly and wait for the user's call; never push back for minor stylistic preferences. Otherwise implement the plan as approved.

### Step 2: Execute the next phase

Read the phase body now — not earlier. Record the phase's base before editing anything: run `git stash create` and write its output to `<run-dir>/phase-<N>-base`, falling back to `git rev-parse HEAD` when it prints nothing, which means no tracked file has changed. Leave an existing file untouched when resuming the phase. `git stash create` snapshots every tracked file into a commit object without touching the worktree or the stash list, and that snapshot is what a phase diff needs: outside phased mode nothing is committed between phases, so `HEAD` is the same SHA for every phase and diffing against it hands Step 3.5 every earlier phase's edits under this phase's spec. It carries no untracked file, and adding one with `git add -N` first makes `git stash create` fail outright — measured on git 2.55, `error: Entry '<path>' not uptodate`. So one case stays uncovered: a file an earlier phase created and left untracked, which a later phase also names, reaches that later phase's diff as a wholly new file. Say so in the dispatch when it happens rather than letting the reviewer read it as this phase's work. Then validate its assumptions and consumed interfaces against live code, and implement it. Respect the phase's named files; classify any necessary change outside them with `<deviation_handling>`. While the phase is still in progress, run only the focused check that can falsify the change you just made — the phase's full automated criteria run once in Step 3.

A plan written against an older template carries two extra sections: a schedule that groups phases for parallel execution, and a check tier keyed to that grouping. Run every phase in order regardless, and say in one line that both are obsolete when you first read a plan carrying them. Ignore the schedule outright. The check tier's commands are not withdrawn — they are checks too coarse for one phase, so Step 4 runs them.

When `<deviation_handling>` Rule 4 stops the phase, ask the user:

```
Issue in Phase [N]:
Expected: [what the plan says]
Found: [actual situation]
Why this matters: [explanation]

How should I proceed?
```

### Step 3: Verify the phase

Run the phase's `#### Automated Verification` criteria, and record each one's verdict — Step 3.5 hands those verdicts to the reviewer rather than making it re-derive them.

For each criterion:

- **Passes**: mark `[x]` in the plan file
- **Fails or does not run**: keep `[ ]`, add `<!-- FAILED: [brief explanation] -->`, and open a fix round
- **Requires manual testing**: leave `[ ]` unchanged

**Three fix rounds maximum per phase.** Write `<!-- FIX ROUND <R> -->` under the phase before each round, and read the phase to get `<R>`. A compacted session cannot tell round 1 from round 3, which is the point at which the cap is supposed to stop the loop and ask. Fix the failure in the main thread. After each fix, re-run only the focused criteria covering the amended code. At the cap, give every open criterion one disposition — Fixed, Parked with ruling, Deferred with reason, or BLOCKED — then ask the user.

### Step 3.5: Review the phase

Run one `code-reviewer` pass over every phase. You hold the whole implementation conversation in context, and that is the non-independence this pass exists to remove.

Write `<run-dir>/phase-<N>-spec.md` with that phase's section plus `## Constraint Check`, and under that heading the plan's `companions:` list with one sentence telling the reviewer to read any entry it does not already hold. Give the spec a `## Checks already run` section: every command Step 3 ran against this phase with its verdict — passed, failed with its note, or deferred — and one sentence telling the reviewer to treat those verdicts as established, because a finding that only restates one of them is not a finding. Those verdicts come from Step 3; nothing re-runs them here.

Build `<run-dir>/phase-<N>-round-<R>.diff` from the phase's base. Read `<run-dir>/phase-<N>-base` with `Read` and write the SHA into the command literally — `git diff <that SHA> -- ':(top)<the phase's named files>'` — because a `$(cat …)` substitution needs its own permission rule and prompts every time. Two cases take a different base. A phase already committed is diffed over its own commit range, whether or not a base was recorded, since a base-to-worktree diff there spans every later phase's work as well. A phase resumed from a run that predates the base file is diffed from the plan's `run_base`. Never build it without a base: a review over an empty diff returns a verdict about nothing, and one built from the working tree alone judges earlier phases against this phase's spec. Reach the phase's new files with `git add -N -- ':(top)<the phase's new files>'`, and undo it afterwards with `git restore --staged -- ':(top)<the same paths>'`. The pathspec is those named files in both directions, never `.` — a bare pathspec reaches the whole index and unstages work the user staged before the run — and `:(top)` anchors it at the repository root, because a plan names its files from there and the session's directory need not be it. Run `git status --porcelain`; a changed file outside the phase's named files is a scope finding unless an already-completed phase named it. The plan file is not a scope finding — this run edits it.

Before sending any dispatch — reviewer or verifier — scan both the prompt you wrote and the spec file it points at for "do not flag", "don't treat X as a defect", "at most Minor", "the plan chose", "suppress", and "no need to report". Rewrite the sentence any of them sits in: deleting the matched words leaves the bias and removes the evidence of it. The spec's one sanctioned exception is the sentence `## Checks already run` requires — a verdict the reviewer is told to treat as established is evidence it already has, not a defect it is being steered away from. A verifier dispatch pre-judges in its own form — asserting the finding is real, serious, or already agreed — so send the finding verbatim and stop there.

Dispatch `code-reviewer` with the phase overview, spec path, the base the diff was built from, diff path, and `task-scoped`. Name no model — the agent's own default tier applies. Never send this conversation.

Verify every spec gap and Critical or Important finding with one `finding-verifier` per finding, dispatched in parallel. Collect every verifier before acting on any verdict. Where a runtime's wait returns the first finisher, keep waiting and release each finished agent until all have reported — acting on a partial roster spends a fix round on a finding the rest would have refuted, and an unreleased agent holds the slot the next dispatch needs. `REFUTED` clears it; `CONFIRMED` and `CANNOT DETERMINE` keep it blocking. A `⚠️ CANNOT VERIFY` item is not a finding and does not go to a verifier — you hold the plan and the cross-phase context the reviewer lacks, so resolve each one yourself before closing the phase. One that names a path it could not read is a runtime problem, not a review result — fix the path and re-dispatch, because resolving it yourself closes a phase whose review never ran. Confirmed as a real gap, it enters the fix round as a spec failure. Act on the verifier's severity, record refutations and Minor findings under the affected phase, and fix blocking findings under Step 3's fix rules. Re-review only the fix diff.

A finding that contradicts the plan is the user's call: present both texts and ask which governs.

Then close out the phase:

1. Update progress in both the plan file and todos
2. Check off completed items in the plan file itself using Edit
3. Append a `## Review closed` section to `<run-dir>/phase-<N>-spec.md`: one line per finding disposition, and the word `none` when there were none. The spec is written before the reviewer is dispatched, so the file's presence records only that the review started — this section is what records that it finished.
4. **Determine whether to continue or stop** (in phased mode, always stop — see `<mode_selection>`):

   Read the phase's success criteria:
   - If `#### Manual Verification` is **empty, absent, or says "(none)"** → **continue to the next phase**
   - If any `#### Manual Verification` item **blocks the next phase** → **stop and present**:

     ```
     Phase [N] Complete - Manual Verification Required

     Automated verification passed:
     - [List automated checks that passed]

     Manual verification needed before continuing:
     - [List blocking manual items from the plan]

     Let me know when verified so I can proceed to the next phase.
     ```

   - If manual items do **not** block the next phase (e.g., visual checks, UX polish) → **defer them and continue**

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

5. **For plans without auto/manual split**: Treat all success criteria as automated. Continue without stopping.

Do not check off manual verification items until confirmed by the user.

### Step 4: Verify the finished plan

After the final phase, run the plan's `### Acceptance Criteria` once, together with every command an older plan's obsolete check-tier section carries. They are the plan-level checks — the end-to-end behaviour no single phase can prove, and every check too coarse to run per phase, so this is the only place a package-level or repo-wide command runs in this skill. Mark each one with Step 3's three outcomes, and open a fix round on a failure under Step 3's cap. A criterion needing human judgment stays unchecked and joins the deferred manual list.

Start these commands in the background so Step 4.5's review can run while they work — a reviewer writes nothing, so the two cannot interfere, and a repo-wide command is usually the longest single wait in the run. If one is interrupted, read the output it already produced before restarting: a failure it already printed is one you can fix now, which makes the restart the last one rather than the second of three.

In phased mode, run this after the final phase's own checks and before its commit.

Once every criterion is checked or dispositioned, set the plan's frontmatter `status: implemented` and `last_updated` to today's date as `YYYY-MM-DD`. Skip silently when the plan has no frontmatter block — Step 1 stops such a plan before this point, so this fires only when the user chose to continue past that question.

Report the outcome in the final summary: which acceptance criteria passed, which failed, and which need the user. This report covers `### Acceptance Criteria` only — it does not stand in for a phase's pending manual verification.

### Step 4.5: Review the run

Run one `branch-scoped` `code-reviewer` pass over the whole run when it executed more than one phase. A single-phase run needs no second pass — Step 3.5 already reviewed exactly that diff.

Write `<run-dir>/run-spec.md` with the plan's `### End State`, `### Acceptance Criteria`, and `## Constraint Check`, and under that heading the plan's `companions:` list with one sentence telling the reviewer to read any entry it does not already hold. Give it a `## Checks already run` section on Step 3.5's terms — every acceptance criterion with its verdict, and one sentence telling the reviewer to treat those verdicts as established, because a finding that only restates one of them is not a finding. Record a criterion still running in the background as pending; a copied checkbox is not a verdict. Build `<run-dir>/run-round-<R>.diff` exactly as Step 3.5 builds a phase diff, over the union of every phase's named files and the plan's frontmatter `run_base` SHA. Dispatch with the plan's overview, the spec path, the output of `git log --oneline <run_base>..HEAD` and `git diff --stat <run_base>` — a commit list, usually empty outside phased mode because this run commits nothing there, and a file map, so the reviewer orients before it starts reading — then the diff path, that base SHA, and `branch-scoped`. Name no model, so the agent's default strong tier applies. This is the only pass that sees how the phases fit together, and its recall on a large diff is weaker than a phase review's on the same code — depth is the phase reviews' job, integration is this one's. Verify, route, and dispose of findings under Step 3.5's rules, then re-run any acceptance criterion a fix touched.

In phased mode, run this after Step 4 and before the final phase's commit. A fix it produces that reaches an earlier phase's files is its own commit — phased mode exists so each phase can be rejected on its own, and folding a cross-phase fix into the last one takes that away.

`/df:peer-review` still covers the branch from its merge-base, including commits made before this run. This pass covers this run.

### When Things Don't Match Expectations

When something isn't working as expected:

- Inspect the relevant live code together with any reviewer findings
- Consider if the codebase has evolved since the plan was written
- Classify it with `<deviation_handling>` — that table decides whether to fix it or stop and ask

Spawn a research sub-task only when the answer is not in the plan or in a file the plan names — targeted debugging, or unfamiliar territory the phase did not describe — and not for an answer a handful of tool calls would settle. `code-reviewer` is reserved for Steps 3.5 and 4.5 — it is not a research sub-task. When spawning a research sub-task:

| Agent                     | Purpose                            | When to Use                                        |
| ------------------------- | ---------------------------------- | -------------------------------------------------- |
| `codebase-analyzer`       | Understand implementation details  | Debugging unexpected behavior or tracing data flow |
| `codebase-pattern-finder` | Find similar patterns and examples | Looking for usage examples of APIs being modified  |
| `codebase-locator`        | Find files by topic/feature        | Locating related files not mentioned in the plan   |

### Resuming Work

If `grep -n '^- \[' <plan>` returns any `- [x]` line:

- Read the plan's run marks — frontmatter `run_base` and `<!-- FIX ROUND <R> -->` under each phase — before selecting the next phase
- List `<run-dir>`, derived as Step 1 derives it. For each phase the plan marks complete, a `phase-<N>-spec.md` that is missing, or present without a `## Review closed` section, is a phase whose review did not finish — give it its Step 3.5 pass before the run continues, because the spec is written before the reviewer is dispatched, so a spec written and a review closed are different events and only the second one counts
- The plan file records what was implemented and the run directory records what was reviewed; neither answers for the other
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

Every turn re-sends the whole conversation, so a turn that carries one `grep` or one `sed -n` pays a full context re-send for one line of output. Each round of inspection therefore carries every independent read the current question needs, in one message. What bounds that batch: the harness runs consecutive read-only calls concurrently and splits the run at the first call that writes, so an `Edit`, a `Write`, or a mutating shell command placed between two reads costs both of them their batch. Group the reads, then write.

Before starting a new phase, read the plan's checkbox state with `grep -n '^- \[' <plan>` — a plan runs 577–3,194 lines, and a full read of it stays resident for every later turn — and run `git log --oneline`. The plan file and git history are the source of truth — not conversation memory or a compaction summary. If context is growing large, say so at the next phase boundary and offer the user a fresh session with the plan path as the entry point — a skill cannot run `/compact` itself. Persistent phase constraints belong in the plan file (and CLAUDE.md), since compaction can drop them from history.

</context_budget>

<success_criteria>

- Every phase's automated criteria are marked in the plan file — `[x]` when they passed, `[ ]` with a `<!-- FAILED: ... -->` note when they did not
- The plan's `### Acceptance Criteria` carries a disposition for every item
- Manual verification is either confirmed by the user or presented as deferred, grouped by phase
- No unresolved mismatch between plan and implementation

</success_criteria>

<anti_patterns>

| Excuse                                                     | Reality                                                                                                                                                           |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "The plan clearly forgot this — I'll just add it."         | If the plan is wrong, that is Rule 4 in `<deviation_handling>`: stop and ask. Adding it silently means nobody agreed to it.                                       |
| "I'll commit both phases together, they're related."       | Phased mode exists so each phase can be rejected on its own. One commit means one gate for two decisions.                                                         |
| "The user will obviously approve this phase."              | Then the confirmation costs one message. Proceeding without it removes their only chance to stop the next phase.                                                  |
| "I'll read the later phases' files now while I'm in here." | They stay resident for every remaining turn, and the phase that needs them reads them anyway. You pay twice for one read.                                         |
| "One more full-suite run, just to be sure."                | Sure of what? Nothing has changed since the last one. It returns the same verdict plus a second copy of its output, which stays resident for the rest of the run. |
| "This build only takes a minute — per phase is fine."      | A run has several phases, so per-phase means paying that minute on every one of them. A check that coarse belongs in `### Acceptance Criteria`, which runs once.  |
| "The fix touched that package, so re-run its checks now."  | Three rounds means three runs of one package check for one phase. Run the focused check covering the fix; a package check runs once, in Step 4.                   |
| "This finding is obviously real — verifying it is waste."  | Then the verifier costs one dispatch and confirms it. The findings that are obviously real are not the ones the gate exists for.                                  |
| "It was refuted, so there's nothing to record."            | A refuted finding that leaves no trace is indistinguishable from one you dropped. The refutation is the evidence that the gate did its job.                       |
| "One more round and it converges."                         | Past the cap, rounds do not converge — the failure is structural. Give every open finding a disposition and ask.                                                  |

Stay focused on implementing what was actually planned.

</anti_patterns>

<constraints>
- Read the plan's preamble, Constraint Check, and every phase's `### Assumptions` before starting, and read every `companions:` entry not already in your context — read a phase body when that phase starts
- Run the plan's `### Acceptance Criteria` once, after the final phase — not once per phase
- Record a phase's base before editing anything, and build its review diff from that base — a diff with no base is the run so far, and the reviewer judges it against one phase's spec
- Dispatch one task-scoped `code-reviewer` for every phase — you hold the whole implementation conversation, and that is the non-independence the pass removes
- After the final phase of a run that executed more than one phase, dispatch one `branch-scoped` `code-reviewer` over the whole run diff — a phase review never sees how two phases fit together
- Verify every spec gap and every Critical or Important finding with `finding-verifier` before opening a fix round — the reviewer's severity is self-assigned and nothing else checks it
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
