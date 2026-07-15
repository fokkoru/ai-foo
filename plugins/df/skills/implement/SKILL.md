---
name: implement
description: Use when implementing a technical plan from the plans directory with verification — continuous by default, or phase-by-phase with human review and a commit per phase when the user asks for phased execution
disable-model-invocation: true
allowed-tools: Read, Write, Edit, LS, Grep, Glob, TodoWrite, Task, Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(make:*), Bash(npm run:*)
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

- Fix the reported problems
- Re-run verification
- Present updated results
- Wait again for confirmation

Repeat until the user is satisfied with the phase.

Once the user approves the phase, commit it:

1. Run `git status` and `git diff HEAD` to review changes
2. Identify the specific files that belong to this phase
3. Present the commit plan and wait for confirmation:

   ```
   Committing Phase [N]:
     type(scope): description
     Files: file1.ts, file2.ts

   Proceed?
   ```

4. Stage specific files for this phase: `git add <files>`
5. Commit with a conventional message: `git commit -m "type(scope): description"`
6. Verify with `git status`

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
If a plan file path is provided, skip the prompt — immediately read the plan fully and begin implementation.

If no plan path is provided, ask the user for the path to the plan file, then wait for input before proceeding.
</quick_start>

<workflow>

### Step 1: Getting Started

1. Read the plan completely and check for any existing checkmarks (`- [x]`)
2. Read the original ticket and all files mentioned in the plan
3. **Read files fully** — never use limit/offset parameters, complete context is needed
4. Take time to ultrathink about how the pieces fit together
5. Create a todo list to track progress
6. Start implementing once the requirements are confirmed understood

Before writing any code: if the plan's approach has a clearly better alternative — one that avoids significant risk or wasted work — say so briefly and wait for the user's call; never push back for minor stylistic preferences. Otherwise implement the plan as approved.

### Step 2: Implementation

Plans are carefully designed, but reality can be messy:

- Follow the plan's intent while adapting to what is found
- Implement each phase fully before moving to the next
- Verify work makes sense in the broader codebase context
- Update checkboxes in the plan as sections are completed

When things don't match the plan exactly, think about why and communicate clearly. The plan is a guide, but judgment matters too.

**Handling Mismatches:**

If a mismatch is encountered:

- STOP and work through why the plan can't be followed before proceeding
- Present the issue clearly:

  ```
  Issue in Phase [N]:
  Expected: [what the plan says]
  Found: [actual situation]
  Why this matters: [explanation]

  How should I proceed?
  ```

### Step 3: Verification

After implementing a phase:

1. Run the automated success criteria checks
   For each automated success criterion in the plan:
   - If the check **passes**: mark `[x]` in the plan file
   - If the check **fails**: keep `[ ]` and add a note: `<!-- FAILED: [brief explanation] -->`
   - If the check **requires manual testing**: leave `[ ]` unchanged
2. Fix any issues before proceeding
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

- First, make sure all relevant code has been read and understood
- Consider if the codebase has evolved since the plan was written
- Present the mismatch clearly and ask for guidance

Use sub-tasks sparingly — mainly for targeted debugging or exploring unfamiliar territory. When spawning agents:

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

The goal is implementing a solution, not just checking boxes. Keep the end goal in mind and maintain forward momentum.

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

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`

Write commit messages that explain WHY, not just WHAT. The type and scope convey what changed — the message body should convey why it matters.

</commit_format>

<context_budget>

More context isn't automatically better — accuracy and recall degrade as the token count grows ("context rot"). Aim for the smallest high-signal token set per phase: the relevant plan section, the directly-affected files, and the references actually needed. Don't carry forward full history, prior-phase output, or unused tool results.

Before starting a new phase, re-read the plan's checkbox state and run `git log --oneline`. The plan file and git history are the source of truth — not conversation memory or a compaction summary. If context is growing large, run `/compact` or start a fresh session with the plan as the entry point. Persistent phase constraints belong in the plan file (and CLAUDE.md), since compaction can drop them from history.

</context_budget>

<success_criteria>

- Each phase passes automated verification
- Manual verification completed by user at blocking checkpoints or deferred to end
- Plan checkboxes updated as work progresses
- Build/test commands execute successfully
- No unresolved mismatches between plan and implementation
  </success_criteria>

<guidelines>
- Follow the plan's intent, not just the letter — adapt to codebase reality
- One phase at a time — complete verification before moving forward
- Update the plan file as work progresses — it's the progress record for resuming later
- Continue automatically through phases with only automated verification — stop only for manual verification items that block the next phase
- Defer non-blocking manual checks to the end — present them grouped by phase
- Use sub-tasks sparingly — the main agent should do the implementation work
- When stuck, communicate clearly — present mismatches with context and ask for guidance
</guidelines>

<anti_patterns>

- Refactoring code beyond what the plan specifies
- Fixing unrelated issues discovered during implementation
- Optimizing prematurely instead of following the plan's approach
- Investigating test failures unrelated to the current phase
- Rewriting working code that the plan doesn't touch
- Adding features or improvements not in the plan scope
- Proceeding to the next phase without user confirmation (phased mode)
- Committing multiple phases in a single commit (phased mode)

Stay focused on implementing what was actually planned.
</anti_patterns>

<circuit_breakers>
Stop and ask the user for guidance if:

- A phase's changes conflict with current codebase state
- Build/verification fails after 3 fix attempts
- The plan references files or APIs that no longer exist
- Implementation reveals the plan's approach is fundamentally flawed
- Scope of changes exceeds what the phase describes
- If agent spawning fails with "agent not found" (Codex CLI), the required subagents may not be installed — see the plugin README for the manual `cp codex/agents/*.toml ~/.codex/agents/` step. On Claude Code, this should not happen; if it does, reinstall the plugin.

When triggered: present the issue clearly, explain what was attempted, and ask how to proceed.
</circuit_breakers>

<constraints>
- Read the plan and all mentioned files fully before starting implementation — partial understanding leads to incorrect changes
- Implement one phase at a time — complete verification before moving to the next
- Update checkboxes in the plan as work completes — this is the progress record for resuming later
- Don't check off manual verification items without user confirmation — only the user can verify manual criteria
- Continue to the next phase automatically when manual verification is empty or absent — stopping is the exception, not the rule
- When manual verification exists but doesn't block the next phase, defer it — present all deferred checks at the end grouped by phase

Apply in phased mode:

- Always stop after each phase — never auto-continue to the next phase
- Wait for explicit user confirmation before committing — present the plan first
- Don't commit without user approval — always present results and wait
- Don't stage all files — use specific file names for each phase's commit; never `git add .` or `git add -A`
- Don't add AI signatures — no Co-Authored-By or "Generated with" lines in commit messages
- Don't modify code during the commit step — only stage and commit existing changes
</constraints>
