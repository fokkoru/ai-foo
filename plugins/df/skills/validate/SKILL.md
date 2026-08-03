---
name: validate
description: Use when validating an implementation against its plan, verifying success criteria, and identifying issues — saves a report under thoughts/validation with an explainer and a short comprehension check
disable-model-invocation: true
allowed-tools: Read, Write, Grep, Glob, TodoWrite, Task, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*)
---

<objective>
Validate the implementation against the approved plan.

Systematically verify that each phase was correctly implemented, run success criteria checks, and identify deviations or issues.

`df:validate` is the developer's self-check against the plan; for an independent, isolated review of the diff, run `df:peer-review` next.

</objective>

<artifact_scope>
Your only output artifact is a single report under thoughts/validation.
Don't create, write, or modify files anywhere else — validation reports on the implementation, it doesn't repair it.
Before any Write call, verify the target path is inside thoughts/validation — if it is not, stop and ask the user.
If validation finds a defect, record it in the report and suggest the user run /df:implement. Do not fix it here.

</artifact_scope>

<quick_start>
If a plan file path is provided, skip the prompt — immediately read the plan fully and begin the validation process.

If no plan path is provided, ask the user for the path to the plan file, then wait for input before proceeding.

</quick_start>

<verification_methodology>

Use goal-backward verification instead of task-checklist verification. Take time to ultrathink about what must be true for the plan's goal to be achieved:

1. **Truths**: What must be TRUE for the plan's goal to be achieved?
2. **Artifacts**: What must EXIST for those truths to hold?
3. **Wiring**: What must be CONNECTED for those artifacts to function?

Start from the plan's `### End State` list, not from the task list.

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

1. **Read the implementation plan** completely using the Read tool without limit/offset parameters
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

Size the fan-out to the diff: a single-phase plan, or a diff under about five files, verifies with 1 agent; a multi-phase plan, 2-3, each verifying an aspect the others do not.

Give an agent paths and the question, not file contents or your session history — everything you paste into a dispatch prompt stays resident in your context for the rest of the session and is re-read on every later turn.

Stop after 3 parallel agent attempts that return no meaningful findings — say so in the report and ask the user, rather than dispatching a fourth round.

Wait for all verification tasks to complete before proceeding.

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
   - Documentation updated if needed

6. **Goal-backward check**:
   - Re-read `## Desired End State`
   - Take `### End State` line by line: for each, trace backward — is the truth satisfied? Does the artifact exist, have substance, and connect to the system?
   - Take every `### Acceptance Criteria` item: run the ones provable by reading or grepping, and list the rest with the exact command and a not-run status. These are the plan-level checks that prove the feature works; a phase's own criteria passing is not a substitute
   - Report any Level 1/2/3 failures, and any `(unverified)` mark still standing in the plan

### Step 4: Write and Present the Report

Gather metadata before writing:

- Current date/time with timezone: `date +"%Y-%m-%d %H:%M:%S %Z"`
- Author name: `git config user.name`
- Current commit hash: `git rev-parse HEAD`
- Filename: `thoughts/validation/YYYY-MM-DD_HHMM_topic.md`

Write the report to that path, then present it. `df:implement` delegates every edit to a subagent, so this document is often the first place the human sees what changed and why — it outlives the session, and chat text does not.

Structure the report as:

```markdown
## Validation Report: [Plan Name]

**Date**: [date]
**Validator**: [git user name]
**Plan**: `thoughts/plans/[plan].md`
**Commit**: [commit hash]

### What Changed and Why

Written for someone who did not watch the edits happen. Per phase: what it changed in plain terms, and which `### End State` line it serves. Name files, not diffs — a reader who wants the diff has git.

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

### Comprehension Check

Three questions at most, drawn from the deviations and the highest-risk changes above.

1. [Question]
2. [Question]
3. [Question]
```

Ask the comprehension questions in one chat message after presenting the report. If an answer is wrong, give the `file:line` that settles it and move on. Nothing is gated on the result and there is no score to record — the check exists so the human notices what they did not follow, not to grade them.

</workflow>

<success_criteria>

- All plan phases checked against actual implementation
- Evidence gathered from git history and code analysis
- Automated criteria listed with pass/fail/not-run status
- Manual testing steps documented clearly
- Validation report written to `thoughts/validation/` and presented, with specific file:line references

</success_criteria>

<existing_context>
If you were part of the implementation session:

- Review the conversation history and todo list for what was completed
- Focus validation on work done in this session
- Be honest about any shortcuts or incomplete items

</existing_context>

<anti_patterns>

- Running extensive test suites without user permission
- Investigating code quality issues unrelated to the plan
- Suggesting improvements beyond what the plan specified
- Deep-diving into dependencies or transitive changes
- Revalidating phases the user has already confirmed

Stay focused on verifying what the plan actually specified.

</anti_patterns>

<constraints>
- Read the plan completely before starting any verification — partial understanding leads to incorrect assessments
- Gather git evidence before spawning verification agents — agents need to know what changed
- Wait for all verification agents to complete before writing the report — partial results lead to incomplete conclusions
- Don't claim automated checks passed without actually verifying them — accuracy is the whole point of validation
- Don't run build/test/lint commands without user permission — the user's CLAUDE.md explicitly requires this
- Your only output artifact is a report in thoughts/validation — don't modify the plan or the codebase. If validation finds a defect, record it and suggest /df:implement

</constraints>
