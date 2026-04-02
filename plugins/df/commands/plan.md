---
allowed-tools: Read, Write, Grep, Glob, TodoWrite, Task, Bash(printenv:*), Bash(echo:*), Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(gh repo view:*)
description: Create detailed implementation plans with thorough research and iteration
---

<objective>
Create a detailed implementation plan through interactive research and collaborative design.

Work through an iterative process — be skeptical, thorough, and collaborate with the user to produce high-quality technical specifications.
</objective>

<artifact_scope>
This is a document-only command.
Your ONLY output artifact is a single document under [plans_dir].
NEVER create, write, or modify files anywhere else.
Before any Write call, verify the target path is inside [plans_dir] — if it is not, stop and ask the user.
If you identify a beneficial code change, document it in the plan document and suggest the user run /df:implement. Do not make code changes in this command.
</artifact_scope>

<quick_start>
If a file path or task description is provided, skip the prompt — immediately read any provided files FULLY and begin the research process.

If no task description is provided, ask the user for:

1. The task/ticket description (or reference to a ticket file)
2. Any relevant context, constraints, or specific requirements
3. Links to related research or previous implementations

Then wait for input before proceeding.
</quick_start>

<configuration>
- `[research_dir]`: !`printenv DF_RESEARCH_DIR || echo thoughts/research`
- `[plans_dir]`: !`printenv DF_PLANS_DIR || echo thoughts/plans`
</configuration>

<plan_shaping>

Before diving into detailed steps, ultrathink about how to shape the planning approach:

### Define the Solution Envelope

- **Core requirement**: What must work for success
- **Boundaries**: Where to stop exploring/building
- **Explicitly excluded**: What NOT to build (prevents scope creep)
- **Quality bar**: Standards that must be met

### Leave Room for Implementation

- Specify **outcomes**, not exact steps
- Define **interfaces**, not internals
- Set **quality standards**, not specific patterns
- Provide **guardrails**, not detailed instructions

### Known Rabbit Holes

Document complexity traps upfront:

- Premature optimization areas
- Over-engineering temptations
- Scope creep risks
- Technical tangents to avoid

</plan_shaping>

<workflow>

### Step 1: Context Gathering & Initial Analysis

1. **Read all mentioned files immediately and FULLY**:
   - Research documents
   - Related implementation plans
   - Any JSON/data files mentioned
   - **IMPORTANT**: Use the Read tool WITHOUT limit/offset parameters to read entire files
   - **CRITICAL**: DO NOT spawn sub-tasks before reading these files in the main context
   - **NEVER** read files partially - if a file is mentioned, read it completely

2. **Spawn initial research tasks to gather context**:
   Before asking the user any questions, use specialized agents to research in parallel:
   - Use the **codebase-locator** agent to find all files related to the task
   - Use the **codebase-analyzer** agent to understand how the current implementation works
   - If relevant, use the **thoughts-locator** agent to find any existing thoughts documents about this feature

   These agents will:
   - Find relevant source files, configs, and tests
   - Trace data flow and key functions
   - Return detailed explanations with file:line references

3. **Read all files identified by research tasks**:
   - After research tasks complete, read ALL files they identified as relevant
   - Read them FULLY into the main context
   - This ensures complete understanding before proceeding

4. **Analyze and verify understanding**:
   - Cross-reference the task requirements with actual code
   - Identify any discrepancies or misunderstandings
   - Note assumptions that need verification
   - Determine true scope based on codebase reality

5. **Present informed understanding and focused questions**:

   ```
   Based on the task and my research of the codebase, I understand we need to [accurate summary].

   I've found that:
   - [Current implementation detail with file:line reference]
   - [Relevant pattern or constraint discovered]
   - [Potential complexity or edge case identified]

   Questions that my research couldn't answer:
   - [Specific technical question that requires human judgment]
   - [Business logic clarification]
   - [Design preference that affects implementation]
   ```

   Only ask questions that genuinely cannot be answered through code investigation.

### Step 2: Research & Discovery

After getting initial clarifications:

1. **If the user corrects any misunderstanding**:
   - DO NOT just accept the correction
   - Spawn new research tasks to verify the correct information
   - Read the specific files/directories they mention
   - Only proceed once the facts are verified

2. **Create a research todo list** using TodoWrite to track exploration tasks

3. **Spawn parallel sub-tasks for comprehensive research**:
   - Create multiple Task agents to research different aspects concurrently
   - Use the right agent for each type of research (see Agent Selection section)

4. **Wait for ALL sub-tasks to complete** before proceeding

5. **Present findings and design options**:

   ```
   Based on my research, here's what I found:

   **Current State:**
   - [Key discovery about existing code]
   - [Pattern or convention to follow]

   **Design Options:**
   1. [Option A] - [pros/cons]
   2. [Option B] - [pros/cons]

   **Open Questions:**
   - [Technical uncertainty]
   - [Design decision needed]

   Which approach aligns best with your vision?
   ```

### Step 3: Plan Structure Development

Once aligned on approach:

1. **Create initial plan outline**:

   ```
   Here's my proposed plan structure:

   ## Overview
   [1-2 sentence summary]

   ## Implementation Phases:
   1. [Phase name] - [what it accomplishes]
   2. [Phase name] - [what it accomplishes]
   3. [Phase name] - [what it accomplishes]

   Does this phasing make sense? Should I adjust the order or granularity?
   ```

2. **Get feedback on structure** before writing details

### Step 4: Detailed Plan Writing

After structure approval:

1. **Gather metadata before writing the document**:
   - Get current date/time with timezone: `date +"%Y-%m-%d %H:%M:%S %Z"`
   - Get author name: `git config user.name`
   - Get git commit hash: `git rev-parse HEAD`
   - Get current branch name: `git rev-parse --abbrev-ref HEAD`
   - Filename: `[plans_dir]/YYYY-MM-DD_HHMM_topic.md`

2. **Use this template structure**:

````markdown
# [Feature/Task Name] - Implementation Plan

**Date**: [date]
**Author**: [git user name]
**Git Commit**: [commit hash]
**Branch**: [branch name]

## Overview

[Brief description of what we're implementing and why]

## Current State Analysis

[What exists now, what's missing, key constraints discovered]

## Desired End State

[A Specification of the desired end state after this plan is complete, and how to verify it]

### Key Discoveries:

- [Important finding with file:line reference]
- [Pattern to follow]
- [Constraint to work within]

## What We're NOT Doing

[Explicitly list out-of-scope items to prevent scope creep]

## Rabbit Holes to Avoid

[Document known complexity traps specific to this implementation:]

- [Premature optimization areas]
- [Over-engineering temptations]
- [Scope creep risks identified during research]
- [Technical tangents that could derail progress]

## Implementation Approach

[High-level strategy and reasoning]

---

## Phase 1: [Descriptive Name]

### Overview

[What this phase accomplishes]

### Changes Required:

#### 1. [Component/File Group]

**File**: `path/to/file.ext`
**Changes**: [Summary of changes]

```[language]
// Specific code to add/modify
```

### Success Criteria:

#### Automated Verification:

- [ ] [Command to run or file to check]
- [ ] [Another automated check]

#### Manual Verification:

- [ ] [UI or UX check requiring human judgment]
- [ ] [Performance or edge case verification]

---

## Phase 2: [Descriptive Name]

[Similar structure with both automated and manual success criteria...]

---

## Testing Strategy

### Unit Tests:

- [What to test]
- [Key edge cases]

### Integration Tests:

- [End-to-end scenarios]

### Manual Testing Steps:

1. [Specific step to verify feature]
2. [Another verification step]
3. [Edge case to test manually]

## Performance Considerations

[Any performance implications or optimizations needed]

## Migration Notes

[If applicable, how to handle existing data/systems]

## References

- Related research: `[research_dir]/[relevant].md`
- Similar implementation: `[file:line]`
````

If on main/master branch or commit is pushed, generate GitHub permalinks for file references.

### Step 5: Sync and Review

1. **Present the draft plan location**:

   ```
   I've created the initial implementation plan at:
   `[plans_dir]/YYYY-MM-DD_HHMM_topic.md`

   Please review it and let me know:
   - Are the phases properly scoped?
   - Are the success criteria specific enough?
   - Any technical details that need adjustment?
   - Missing edge cases or considerations?
   ```

2. **Iterate based on feedback** - be ready to:
   - Add missing phases
   - Adjust technical approach
   - Clarify success criteria (both automated and manual)
   - Add/remove scope items

3. **Continue refining** until the user is satisfied

</workflow>

<success_criteria>

- Plan file created at `[plans_dir]/YYYY-MM-DD_HHMM_topic.md` with all sections populated
- All research questions resolved (no "TBD" or open questions in final plan)
- Each phase has specific file:line references, concrete changes, and separated automated/manual success criteria
- User confirms plan structure, phasing, and technical approach
  </success_criteria>

<success_criteria_guidelines>

Always separate success criteria into two categories:

1. **Automated Verification** (can be run by execution agents):
   - Commands that can be run: `make test`, `npm run lint`, etc.
   - Specific files that should exist
   - Code compilation/type checking
   - Automated test suites

2. **Manual Verification** (requires human testing):
   - UI/UX functionality
   - Performance under real conditions
   - Edge cases that are hard to automate
   - User acceptance criteria

The presence or absence of manual verification items controls whether the implementer pauses after a phase. Only add manual checks where human judgment is genuinely needed.

</success_criteria_guidelines>

<common_patterns>

### For Database Changes

- Start with schema/migration
- Add store methods
- Update business logic
- Expose via API
- Update clients

### For New Features

- Research existing patterns first
- Start with data model
- Build backend logic
- Add API endpoints
- Implement UI last

### For Refactoring

- Document current behavior
- Plan incremental changes
- Include migration strategy

</common_patterns>

<guidelines>

1. **Be Skeptical**:
   - Question vague requirements
   - Identify potential issues early
   - Ask "why" and "what about"
   - Don't assume - verify with code

2. **Be Interactive**:
   - Don't write the full plan in one shot
   - Get buy-in at each major step
   - Allow course corrections
   - Work collaboratively

3. **Be Thorough**:
   - Read all context files COMPLETELY before planning
   - Research actual code patterns using parallel sub-tasks
   - Include specific file paths and line numbers
   - Write measurable success criteria with clear automated vs manual distinction

4. **Be Practical**:
   - Focus on incremental, testable changes
   - Consider migration and rollback
   - Think about edge cases
   - Include "what we're NOT doing"

5. **Track Progress**:
   - Use TodoWrite to track planning tasks
   - Update todos as research completes
   - Mark planning tasks complete when done

6. **No Open Questions in Final Plan**:
   - If open questions are encountered during planning, STOP
   - Research or ask for clarification immediately
   - Do NOT write the plan with unresolved questions
   - The implementation plan must be complete and actionable
   - Every decision must be made before finalizing the plan

</guidelines>

<agent_selection>

Select the right agent for each type of investigation:

**Codebase investigation:**

| Agent                     | Purpose                            | When to Use                               |
| ------------------------- | ---------------------------------- | ----------------------------------------- |
| `codebase-locator`        | Find files by topic/feature        | Starting point to discover what exists    |
| `codebase-analyzer`       | Understand implementation details  | Deep dive into specific components        |
| `codebase-pattern-finder` | Find similar patterns and examples | Looking for usage examples or conventions |

**Historical context:**

| Agent               | Purpose                                 | When to Use                       |
| ------------------- | --------------------------------------- | --------------------------------- |
| `thoughts-locator`  | Discover documents in thoughts/         | Find prior research or decisions  |
| `thoughts-analyzer` | Extract insights from thought documents | Deep dive into historical context |

**External research:**

| Agent                   | Purpose                                  | When to Use                          |
| ----------------------- | ---------------------------------------- | ------------------------------------ |
| `web-search-researcher` | Research APIs, libraries, best practices | Need information beyond the codebase |

**Guidelines:**

- Start with locator agents to find what exists, then use analyzer agents on the most promising findings
- Run multiple agents in parallel when searching for different things
- Each agent knows its job — provide what to find, not how to search
- Do not write detailed prompts about HOW to search; the agents already know
- Keep prompts focused on read-only operations
- Request specific file:line references in responses
- Verify sub-task results — if unexpected, spawn follow-up tasks and cross-check against the actual codebase

</agent_selection>

<anti_patterns>

- Tracing every single import/dependency chain
- Analyzing generated or vendored code (node_modules, build/, dist/, .git/)
- Researching test implementations unless specifically asked
- Exploring unrelated "interesting" findings during research
- Understanding entire subsystems when only a component is needed
- Over-specifying implementation details that should be left to the implementer

Stay focused on planning what was actually requested.
</anti_patterns>

<key_principles>

- Always use parallel Task agents to maximize efficiency and minimize context usage
- Always run fresh codebase research; never rely solely on existing research documents
- Focus on concrete file paths and line numbers for developer reference
- Plans should be self-contained with all necessary context
- Keep the main agent focused on synthesis, not deep file reading
- Encourage sub-agents to find examples and usage patterns, not just definitions
- Include temporal context (when the plan was created)
- Link to GitHub when possible for permanent references
  </key_principles>

<context_budget>

Plans should be scoped so each phase can be implemented within ~50% of the context window:

| Context Usage | Quality Level | Implication for Planning              |
| ------------- | ------------- | ------------------------------------- |
| 0-30%         | PEAK          | Thorough, comprehensive work possible |
| 30-50%        | GOOD          | Confident, solid work                 |
| 50-70%        | DEGRADING     | Cut non-essential exploration         |
| 70%+          | POOR          | Rushed, minimal quality               |

If a plan has many phases or complex phases, consider splitting into smaller plans. The implementer will lose quality past 50% context usage.

</context_budget>

<circuit_breakers>
Stop and reframe the planning process if:

- No meaningful findings after 3 parallel agent attempts
- Core directories/files mentioned don't exist
- Sub-agents return contradictory information
- More than 10 sub-agents needed (scope too broad)
- Planning expanding beyond the original task

When triggered: reframe more narrowly, ask the user for clarification, or document what couldn't be resolved and why.
</circuit_breakers>

<constraints>
- Your ONLY output artifact is a plan document in [plans_dir] — NEVER write or modify files anywhere else. If you find a beneficial code change, document it and suggest /df:implement.
- Read mentioned files first in the main context before spawning sub-tasks — sub-agents don't share the main context and will miss this information
- Wait for all sub-agents to complete before synthesizing — partial results lead to incomplete or contradictory conclusions
- Gather metadata before writing the document — git state should be captured at planning time, not after
- NEVER write the plan with placeholder values or unresolved questions — plans are permanent artifacts that will be executed by other agents
</constraints>
