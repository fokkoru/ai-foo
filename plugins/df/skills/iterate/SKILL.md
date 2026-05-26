---
name: iterate
description: Use when iterating on an existing implementation plan with feedback and updates
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, TodoWrite, Task, Bash(git log:*), Bash(git diff:*), Bash(git status:*)
---

<objective>
Update an existing implementation plan based on feedback.

Be skeptical, thorough, and ensure changes are grounded in actual codebase reality.
</objective>

<artifact_scope>
This is a document-only command.
You ONLY edit or write files under thoughts/plans.
NEVER create, write, or modify files anywhere else.
Before any Write or Edit call, verify the target path is inside thoughts/plans — if it is not, stop and ask the user.
If you identify a beneficial code change, document it in the plan and suggest the user run /df:implement. Do not make code changes in this command.
</artifact_scope>

<quick_start>
If both a plan file path and feedback are provided, skip the prompts — immediately read the plan FULLY and begin the update process.

If a plan file path is provided but no feedback, read the plan FULLY and ask the user what changes they want to make, then wait for input before proceeding.

If no plan file path is provided, ask the user which plan to update, then wait for input before proceeding.
</quick_start>

<workflow>

### Step 1: Read and Understand Current Plan

1. **Read the existing plan file COMPLETELY**:
   - Use the Read tool WITHOUT limit/offset parameters
   - Understand the current structure, phases, and scope
   - Note the success criteria and implementation approach

2. **Understand the requested changes**:
   - Parse what the user wants to add/modify/remove
   - Identify if changes require codebase research
   - Determine scope of the update

### Step 2: Research If Needed

**Only spawn research tasks if the changes require new technical understanding.**

If the user's feedback requires understanding new code patterns or validating assumptions:

1. **Create a research todo list** using TodoWrite

2. **Spawn parallel sub-tasks for research**:

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
   - Only spawn if truly needed — don't research for simple changes
   - Start with locator agents to find what exists, then use analyzer agents on the most promising findings
   - Run multiple agents in parallel when searching for different things
   - Each agent knows its job — provide what to find, not how to search
   - Do not write detailed prompts about HOW to search; the agents already know
   - Keep prompts focused on read-only operations
   - Request specific file:line references in responses

3. **Read any new files identified by research**:
   - Read them FULLY into the main context
   - Cross-reference with the plan requirements

4. **Wait for ALL sub-tasks to complete** before proceeding

### Step 3: Present Understanding and Approach

**If the user's feedback contradicts your understanding of the codebase:**

- DO NOT just accept the correction
- Spawn research tasks to verify the feedback against actual code
- Only proceed once the facts are confirmed through code investigation

Before making changes, confirm understanding:

```
Based on your feedback, I understand you want to:
- [Change 1 with specific detail]
- [Change 2 with specific detail]

My research found:
- [Relevant code pattern or constraint]
- [Important discovery that affects the change]

I plan to update the plan by:
1. [Specific modification to make]
2. [Another modification]

Does this align with your intent?
```

Get user confirmation before proceeding.

### Step 4: Update the Plan

1. **Make focused, precise edits** to the existing plan:
   - Use the Edit tool for surgical changes
   - Maintain the existing structure unless explicitly changing it
   - Keep all file:line references accurate
   - Update success criteria if needed

2. **Ensure consistency**:
   - If adding a new phase, ensure it follows the existing pattern
   - If modifying scope, update "What We're NOT Doing" section
   - If changing approach, update "Implementation Approach" section
   - Maintain the distinction between automated vs manual success criteria

3. **Preserve quality standards**:
   - Include specific file paths and line numbers for new content
   - Write measurable success criteria
   - Keep language clear and actionable

### Step 5: Review

1. **Present the changes made**:

   ```
   I've updated the plan at `[path]`

   Changes made:
   - [Specific change 1]
   - [Specific change 2]

   The updated plan now:
   - [Key improvement]
   - [Another improvement]

   Would you like any further adjustments?
   ```

2. **Be ready to iterate further** based on feedback

</workflow>

<success_criteria>

- All requested changes applied accurately to the plan
- Updated sections are consistent with unchanged sections
- File:line references are accurate for new content
- Success criteria updated if scope changed
- No placeholder values or unresolved questions in the plan
- User confirms the changes match their intent
  </success_criteria>

<guidelines>
- **Be Surgical** — precise edits over wholesale rewrites; preserve good content that doesn't need changing; only research what's necessary for the specific changes
- **Be Skeptical** — question vague feedback; verify technical feasibility with code research; point out conflicts with existing plan phases
- **Be Interactive** — confirm understanding before editing; show planned changes before making them; allow course corrections
- **No Open Questions** — if changes raise questions, ASK or research immediately; never update the plan with unresolved questions

When updating success criteria, always maintain the automated vs manual verification distinction.
</guidelines>

<anti_patterns>

- Rewriting the entire plan when only a section needs updating
- Researching code patterns for simple text/scope adjustments
- Tracing every single import/dependency chain
- Analyzing generated or vendored code (node_modules, build/, dist/, .git/)
- Expanding scope beyond what was requested
- Adding new phases or features the user didn't ask for

Stay focused on making the specific changes requested.
</anti_patterns>

<key_principles>

- Read the complete plan before making any changes — context matters
- Confirm understanding before editing — prevent misinterpretation
- Use parallel Task agents for research when needed, not for simple edits
- Surgical edits over wholesale rewrites — preserve existing quality
- Every change must be complete and actionable — no placeholders
- Keep the main agent focused on synthesis and editing, not deep file reading
  </key_principles>

<circuit_breakers>
Stop and ask the user for guidance if:

- Requested changes conflict with other plan phases
- Research reveals the plan's assumptions are fundamentally wrong
- Changes would require rewriting more than half the plan
- Sub-agents return contradictory information about the codebase
- More than 10 sub-agents needed for research (scope too broad)
- If agent spawning fails with "agent not found" (Codex CLI), the required subagents may not be installed — see the plugin README for the manual `cp codex/agents/*.toml ~/.codex/agents/` step. On Claude Code, this should not happen; if it does, reinstall the plugin.

When triggered: present the issue clearly, explain what was found, and ask how to proceed.
</circuit_breakers>

<constraints>
- You ONLY edit or write files in thoughts/plans — NEVER modify files anywhere else. If you find a beneficial code change, document it and suggest /df:implement.
- Read the existing plan fully before making any changes — partial understanding leads to inconsistent edits
- Read mentioned files first in main context before spawning sub-tasks — sub-agents don't share the main context and will miss this information
- Wait for all sub-agents to complete before synthesizing — partial results lead to incomplete conclusions
- Confirm understanding with the user before editing — prevent wasted effort on misinterpreted feedback
- NEVER update the plan with placeholder values or unresolved questions — plans are permanent artifacts that will be executed by other agents
</constraints>
