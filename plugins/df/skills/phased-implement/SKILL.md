---
name: phased-implement
description: Use when implementing a structured plan phase by phase with human review and a commit per phase
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, TodoWrite, Task, Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(make:*), Bash(npm run:*)
---

<objective>
Execute an approved technical plan one phase at a time, stopping after each phase for human review and committing approved work before proceeding.

Each phase is a discrete unit: implement → verify → review → commit → next.
</objective>

<quick_start>
If a plan file path is provided, skip the prompt — immediately read the plan FULLY and begin with the first unchecked phase.

If no plan path is provided, ask the user for the path to the plan file, then wait for input before proceeding.
</quick_start>

<workflow>

### Step 1: Getting Started

1. Read the plan completely and check for any existing checkmarks (`- [x]`)
2. Read the original ticket/research documents and all files mentioned in the plan
3. **Read files fully** — never use limit/offset parameters, complete context is needed
4. Take time to ultrathink about how the pieces fit together
5. Identify the first unchecked phase (or Phase 1 if starting fresh)
6. Create a todo list to track progress

### Step 2: Implement Current Phase

Implement only the current phase. Do not start the next phase.

- Follow the plan's intent while adapting to what is found
- Verify work makes sense in the broader codebase context
- Update checkboxes in the plan as sections are completed

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

### Step 3: Verify Current Phase

After implementing the phase:

1. Run the automated success criteria checks
   For each automated success criterion in the plan:
   - If the check **passes**: mark `[x]` in the plan file
   - If the check **fails**: keep `[ ]` and add a note: `<!-- FAILED: [brief explanation] -->`
2. Fix any issues found during automated verification
3. Update progress in both the plan file and todos

### Step 4: Present Results and Wait

Always stop after each phase and present a summary:

```
## Phase [N] Complete

**What was done:**
- [List of completed tasks]

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

### Step 5: Iterate if Needed

If the user reports issues:

- Fix the reported problems
- Re-run verification
- Present updated results
- Wait again for confirmation

Repeat until the user is satisfied with the phase.

### Step 6: Commit the Phase

Once the user approves the phase:

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

### Step 7: Next Phase or Finish

After committing:

- If more phases remain → go to Step 2 with the next phase
- If all phases are done → present final summary:

```
## Implementation Complete

All [N] phases implemented and committed:

1. [commit hash] type(scope): Phase 1 description
2. [commit hash] type(scope): Phase 2 description
...

Any remaining manual checks across all phases:
- Phase [X]: [deferred check]

Next: run /df:validate or create a PR.
```

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

When presenting phase results, automate the verification environment first:

- Start dev servers and verify they respond before asking the user to check UI
- Run curl/fetch to confirm endpoints are alive before asking the user to test
- Compile and build before presenting results
- Seed test data if needed for manual testing

**Anti-pattern**: "Please start the dev server and check localhost:3000"
**Correct**: "Dev server running at localhost:3000 (verified responding). Please check that the login form renders correctly."

Never present results with a broken or unverified environment. The user should only do what requires human judgment.

</checkpoint_protocol>

<commit_format>

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`

Write commit messages that explain WHY, not just WHAT. The type and scope convey what changed — the message body should convey why it matters.

</commit_format>

<resuming_work>

If the plan has existing checkmarks:

- Trust that completed work is done
- Check git log to see which phases were already committed
- Pick up from the first unchecked phase
- Verify previous work only if something seems off

</resuming_work>

<context_budget>

More context isn't automatically better — accuracy and recall degrade as the token count grows ("context rot"). Aim for the smallest high-signal token set per phase: the relevant plan section, the directly-affected files, and the references actually needed. Don't carry forward full history, prior-phase output, or unused tool results.

Before starting a new phase, re-read the plan's checkbox state and run `git log --oneline`. The plan file and git history are the source of truth — not conversation memory or a compaction summary. If context is growing large, run `/compact` or start a fresh session with the plan as the entry point. Persistent phase constraints belong in the plan file (and CLAUDE.md), since compaction can drop them from history.

</context_budget>

<success_criteria>

- Each phase passes automated verification before presenting to user
- User confirms each phase before it is committed
- Each phase gets its own atomic commit with a conventional message
- Plan checkboxes updated as work progresses
- No unresolved mismatches between plan and implementation
  </success_criteria>

<guidelines>
- Follow the plan's intent, not just the letter — adapt to codebase reality
- One phase at a time — implement, verify, review, commit, then move on
- Always stop between phases — the user reviews every phase before proceeding
- Update the plan file as work progresses — it's the progress record for resuming later
- Use sub-tasks sparingly — the main agent should do the implementation work. When needed:
  - `codebase-analyzer` — debugging unexpected behavior or tracing data flow
  - `codebase-pattern-finder` — finding usage examples of APIs being modified
  - `codebase-locator` — locating related files not mentioned in the plan
- When stuck, communicate clearly — present mismatches with context and ask for guidance
- NEVER stage all files — use specific file names, never `git add .` or `git add -A`
- NEVER add AI signatures — no Co-Authored-By, no "Generated with" lines
</guidelines>

<anti_patterns>

- Refactoring code beyond what the plan specifies
- Fixing unrelated issues discovered during implementation
- Optimizing prematurely instead of following the plan's approach
- Investigating test failures unrelated to the current phase
- Rewriting working code that the plan doesn't touch
- Adding features or improvements not in the plan scope
- Proceeding to the next phase without user confirmation
- Committing multiple phases in a single commit

Stay focused on implementing what was actually planned, one phase at a time.
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
- Implement one phase at a time — complete verification before presenting results
- ALWAYS stop after each phase — never auto-continue to the next phase
- Wait for explicit user confirmation before committing — present the plan first
- NEVER check off manual verification items without user confirmation — only the user can verify manual criteria
- NEVER commit without user approval — always present results and wait
- NEVER stage all files — use specific file names for each phase's commit
- NEVER add AI signatures — no Co-Authored-By lines in commit messages
- NEVER modify code during the commit step — only stage and commit existing changes
</constraints>
