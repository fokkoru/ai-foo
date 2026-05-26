---
name: validate
description: Use when validating an implementation against its plan, verifying success criteria, and identifying issues
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, TodoWrite, Task, Bash(git log:*), Bash(git diff:*), Bash(git status:*)
---

<objective>
Validate the implementation against the approved plan.

Systematically verify that each phase was correctly implemented, run success criteria checks, and identify deviations or issues.
</objective>

<quick_start>
If a plan file path is provided, skip the prompt — immediately read the plan FULLY and begin the validation process.

If no plan path is provided, ask the user for the path to the plan file, then wait for input before proceeding.
</quick_start>

<verification_methodology>

Use goal-backward verification instead of task-checklist verification. Take time to ultrathink about what must be true for the plan's goal to be achieved:

1. **Truths**: What must be TRUE for the plan's goal to be achieved?
2. **Artifacts**: What must EXIST for those truths to hold?
3. **Wiring**: What must be CONNECTED for those artifacts to function?

Start from the desired end state (in the plan's overview/desired end state section), not from the task list.

### Three-Level Artifact Verification

For each artifact identified, verify at all three levels:

| Level           | Check               | Pass Criteria                                                            |
| --------------- | ------------------- | ------------------------------------------------------------------------ |
| 1 - Existence   | File/export exists  | File present, expected exports found                                     |
| 2 - Substantive | Not a stub          | >30 lines of real logic, no TODO placeholders, real implementations      |
| 3 - Wired       | Connected to system | Imported by parent, called in execution path, reachable from entry point |

### Stub Detection Patterns

Flag these as Level 2 failures:

- `return <div>Placeholder</div>` or similar placeholder JSX
- `onClick={() => {}}` or empty event handlers
- `// TODO` or `// FIXME` in implementation code
- Empty function bodies (`{}` with no logic)
- Hardcoded mock data where real data should flow
- Functions that only `console.log` or `throw new Error('not implemented')`

</verification_methodology>

<workflow>

### Step 1: Context Discovery

1. **Read the implementation plan** completely using the Read tool WITHOUT limit/offset parameters
2. **Gather implementation evidence** from git history:
   - Check recent commits for implementation work
   - Review diffs to understand what actually changed
3. **Identify what should have been done**:
   - List all files the plan says to modify
   - Note all success criteria (automated and manual)
   - Identify key functionality to verify

### Step 2: Parallel Verification

Spawn parallel sub-tasks to verify different aspects of the implementation:

| Agent                     | Purpose                       | When to Use                                           |
| ------------------------- | ----------------------------- | ----------------------------------------------------- |
| `codebase-analyzer`       | Verify implementation details | Comparing actual code against plan specifications     |
| `codebase-pattern-finder` | Check pattern compliance      | Verifying new code follows existing conventions       |
| `codebase-locator`        | Find related changes          | Discovering files modified beyond what the plan lists |

Example verification tasks:

- **Code changes**: Compare actual modifications to plan specifications, file by file
- **Test coverage**: Check if tests were added/modified as specified
- **Pattern compliance**: Verify new code follows existing codebase conventions

Wait for ALL verification tasks to complete before proceeding.

### Step 3: Systematic Phase Validation

For each phase in the plan:

1. **Check completion status**:
   - Look for checkmarks in the plan (`- [x]`)
   - Verify the actual code matches claimed completion

2. **Assess automated criteria**:
   - List each automated verification command from the plan
   - Note which ones can be run and their expected outcomes
   - Do NOT run build/test/lint commands without user permission

3. **Assess manual criteria**:
   - List what needs manual testing
   - Provide clear steps for user verification

4. **Handle partial implementations**:
   - For plans where some phases are complete and others are not, validate completed phases thoroughly
   - Mark incomplete phases with their current status — do not treat pending phases as failures

5. **Identify edge cases**:
   - Were error conditions handled?
   - Are there missing validations?
   - Could the implementation break existing functionality?

6. **Goal-backward check**:
   - Re-read the plan's overview and desired end state
   - For each stated goal, trace backward: is the truth satisfied? Does the artifact exist, have substance, and connect to the system?
   - Report any Level 1/2/3 failures found

### Step 4: Generate Validation Report

Present the validation report directly to the user. Do not save to a file unless explicitly requested.

Structure the report as:

```
## Validation Report: [Plan Name]

### Implementation Status
[Per-phase status: fully implemented, partially implemented, not started]

### Automated Verification
[List automated criteria with pass/fail/not-run status]

### Code Review Findings

#### Matches Plan:
- [What was implemented correctly with file:line references]

#### Deviations from Plan:
- [Differences between plan and actual implementation]

#### Potential Issues:
- [Problems discovered during validation]

#### Artifact Verification:
- [Level 1/2/3 results for key artifacts — existence, substance, wiring status]
- [Any stubs or unwired code detected]

### Manual Testing Required:
[Checklist of manual verification steps from the plan]

### Recommendations:
[Actionable items to address before considering implementation complete]
```

</workflow>

<success_criteria>

- All plan phases checked against actual implementation
- Evidence gathered from git history and code analysis
- Automated criteria listed with pass/fail/not-run status
- Manual testing steps documented clearly
- Validation report generated with specific file:line references
  </success_criteria>

<guidelines>
- **Be Thorough** — check every phase and every success criterion; don't skip verification steps
- **Be Evidence-Based** — cite specific file:line references and git diffs; compare plan text to actual code
- **Be Honest** — report issues constructively; don't gloss over incomplete work
- **Be Read-Only** — NEVER modify the plan, codebase, or any files during validation
- **Self-check vs. independent review** — `df:validate` is the developer's self-check against the plan; for an independent, isolated review of the diff, run `df:peer-review` next.

Use parallel Task agents for verification to minimize context usage. Separate automated from manual verification — only the user can confirm manual criteria.
</guidelines>

<existing_context>
If you were part of the implementation session:

- Review the conversation history and todo list for what was completed
- Focus validation on work done in this session
- Be honest about any shortcuts or incomplete items
  </existing_context>

<validation_checklist>
Always verify:

- [ ] All phases marked complete are actually done
- [ ] Code follows existing patterns
- [ ] No regressions introduced
- [ ] Error handling is robust
- [ ] Automated tests pass (if applicable and user permits running)
- [ ] Documentation updated if needed
- [ ] Manual test steps are clear
- [ ] Key artifacts pass 3-level verification (exist, substantive, wired)
- [ ] No stub implementations detected in delivered code
      </validation_checklist>

<anti_patterns>

- Running extensive test suites without user permission
- Investigating code quality issues unrelated to the plan
- Suggesting improvements beyond what the plan specified
- Deep-diving into dependencies or transitive changes
- Revalidating phases the user has already confirmed

Stay focused on verifying what the plan actually specified.
</anti_patterns>

<circuit_breakers>
Stop and ask the user for guidance if:

- The plan file cannot be found or is incomplete
- Git history shows no implementation commits related to the plan
- More than half the plan phases appear unimplemented
- Verification reveals the implementation contradicts the plan's approach
- Sub-agents return contradictory findings about the implementation
- If agent spawning fails with "agent not found" (Codex CLI), the required subagents may not be installed — see the plugin README for the manual `cp codex/agents/*.toml ~/.codex/agents/` step. On Claude Code, this should not happen; if it does, reinstall the plugin.

When triggered: present the issue clearly, explain what was found, and ask how to proceed.
</circuit_breakers>

<constraints>
- Read the plan completely before starting any verification — partial understanding leads to incorrect assessments
- Gather git evidence before spawning verification agents — agents need to know what changed
- Wait for all verification agents to complete before writing the report — partial results lead to incomplete conclusions
- NEVER claim automated checks passed without actually verifying them — accuracy is the whole point of validation
- NEVER run build/test/lint commands without user permission — the user's CLAUDE.md explicitly requires this
</constraints>
