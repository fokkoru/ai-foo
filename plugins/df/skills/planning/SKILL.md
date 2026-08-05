---
name: planning
description: Use when creating an implementation plan for the df workflow — runs between df:research and df:implement. Produces a phased plan with parallel research agents and phased success criteria.
disable-model-invocation: true
allowed-tools: Read, Write, Grep, Glob, TodoWrite, Task, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(gh repo view:*)
---

<objective>
Create a detailed implementation plan through interactive research and collaborative design.

Work through an iterative process — be skeptical, thorough, and collaborate with the user to produce high-quality technical specifications.

</objective>

<artifact_scope>
This is a document-only command.
Your only output artifact is a single document under thoughts/plans.
Don't create, write, or modify files anywhere else.
Before any Write call, verify the target path is inside thoughts/plans — if it is not, stop and ask the user.
If you identify a beneficial code change, document it in the plan document and suggest the user run /df:implement. Do not make code changes in this command.

</artifact_scope>

<quick_start>
If a file path or task description is provided, skip the prompt and begin at Step 1.

If no task description is provided, ask the user for:

1. The task/ticket description (or reference to a ticket file)
2. Any relevant context, constraints, or specific requirements
3. Links to related research or previous implementations

Then wait for input before proceeding.

</quick_start>

<plan_shaping>

Before diving into detailed steps, ultrathink about how to shape the planning approach:

### Define the Solution Envelope

Each of these becomes a named section of the plan. Shape it here, write it there.

- **What must be true when this is done** → `### End State`
- **How it is proven to work, end to end** → `### Acceptance Criteria`
- **Rules no phase may break** → `## Global Constraints`
- **What NOT to build** → `## What We're NOT Doing`

### Leave Room for Implementation

- Specify **outcomes**, not exact steps
- Define **interfaces**, not internals
- Set **quality standards**, not specific patterns
- Provide **guardrails**, not detailed instructions

### Right-Size the Phases

A phase is the smallest unit that carries its own verification and is worth an independent reviewer's gate.

- Fold setup, configuration, scaffolding, and documentation steps into the phase whose deliverable needs them.
- Split only where a reviewer could meaningfully reject one phase while approving its neighbour.
- Each phase ends with an independently verifiable deliverable.

This is a gate test, not a size limit. Phase count is an outcome of the test.

### Known Rabbit Holes

Document complexity traps upfront:

- Premature optimization areas
- Over-engineering temptations
- Scope creep risks
- Technical tangents to avoid

</plan_shaping>

<workflow>

### Step 1: Context Gathering & Initial Analysis

1. **Read the provided source documents completely**:
   - Research documents
   - Related implementation plans
   - Tickets or specifications supplied as files
   - Treat them as the requirements source for planning

2. **Check the task is plan-sized before planning it**:

   A plan earns its cost when the approach is uncertain, when the change spans several files, or when the code being changed is unfamiliar. If you could describe the finished diff in one sentence and you already know which lines it touches, none of those hold and the plan is overhead.

   Say so once, in one line, and let the user decide:

   ```
   This looks like a one-sentence diff: [the sentence]. A plan would cost more than the change it describes.
   Reply "plan anyway" and I'll write one — otherwise make the change directly, since df:implement needs a plan to execute.
   ```

   Take the answer at face value and do not re-argue it. If the user takes the offer, stop and write nothing — this skill's only output is a plan document, so the change itself stays with the user. If no answer comes — a headless run, or a runtime that denies user prompts — write the plan: an unwanted plan wastes tokens, a missing one loses the work.

3. **Settle `### End State` and `### Acceptance Criteria` before the research spawn**:

   Try to write `### End State` and `### Acceptance Criteria` (see `references/plan-template.md`) from the source material alone — the ticket, the research document, the task description. This is a test of the material, not of your confidence: either the source says what must be true when this is done and how that is proven, or it does not.

   If both are writable, continue to the next step and ask nothing.

   If either is not, ask now, before any research — this is the one class of question the codebase provably cannot answer, and its value is spent once execution is under way. Recommended answer first, always. Batch the gaps into **one** message when their answers are independent. Ask one at a time when one answer determines what the next question is — a batch whose second question is void once the first is answered wastes the user's read. The batched form:

   ```
   Before I load the codebase, [N] things the code can't tell me:

   1. [Gap] — Recommended: [answer], because [reason]. Alternatives: [answer], [answer].
   2. [Gap] — Recommended: [answer], because [reason]. Alternatives: [answer], [answer].
   ```

   Treat the reply as the answer to what you asked. A user answering a question is not correcting you and not rejecting the approach — change nothing you were not asked about. The settled lines are the plan's `### End State` and `### Acceptance Criteria` — carry them into Step 4 verbatim rather than logging the exchange.

   If no answer comes — a headless run, a runtime that denies user prompts, or the user says to proceed — write both sections from your best reading of the source, mark each such line `(unverified)`, and carry those marks into the plan. Never drop the sections and never present a guess as settled.

4. **Spawn initial research tasks to gather context**:
   With the end state settled, use specialized agents to research in parallel:
   - Use the **codebase-locator** agent to find all files related to the task
   - Use the **codebase-analyzer** agent to understand how the current implementation works
   - If relevant, use the **thoughts-locator** agent to find any existing thoughts documents about this feature

   These agents will:
   - Find relevant source files, configs, and tests
   - Trace data flow and key functions
   - Return detailed explanations with file:line references

5. **Analyze and verify understanding**:
   - Cross-reference the task requirements with actual code
   - Identify any discrepancies or misunderstandings
   - Record each assumption the plan will rest on together with the `file:line` that supports it — these become the phases' `### Assumptions` blocks
   - Determine true scope based on codebase reality

6. **Present informed understanding and focused questions**:

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

   Facts are yours to find; decisions are the user's to make. Never ask what the codebase can tell you — look it up. Always put a decision to the user, however much context you have already loaded, when any of these holds:
   - being wrong is not cheaply reversible
   - a different answer changes what you would build, not just how you would word it
   - the user can answer from what they already know, without going off to research it themselves

### Step 2: Research & Discovery

After getting initial clarifications:

1. **If the user corrects any misunderstanding**:
   - Don't just accept the correction
   - Spawn new research tasks to verify the correct information
   - Read the specific files/directories they mention
   - Only proceed once the facts are verified

2. **Create a research todo list** using TodoWrite to track exploration tasks

3. **Spawn parallel sub-tasks for comprehensive research**:
   - Create multiple Task agents to research different aspects concurrently
   - Use the right agent for each type of research (see Agent Selection section)

4. **Wait for all sub-tasks to complete** before proceeding

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

   ## Execution Waves:
   1. Main: Phase [N] | Background: Phase [N] or (none)
   2. Main: Phase [N] | Background: Phase [N] or (none)

   Does this phasing and execution schedule make sense? Should I adjust the order or granularity?
   ```

2. **Get feedback on structure** before writing details

### Step 4: Detailed Plan Writing

After structure approval:

1. **Gather metadata before writing the document**:
   - Get current date/time with timezone: `date +"%Y-%m-%d %H:%M:%S %Z"`
   - Get author name: `git config user.name`
   - Get git commit hash: `git rev-parse HEAD`
   - Get current branch name: `git rev-parse --abbrev-ref HEAD`
   - Filename: `thoughts/plans/YYYY-MM-DD_HHMM_topic.md`

2. **Use the plan template**: read `references/plan-template.md` (in this skill's directory) fully and use it as the document skeleton.

3. **Self-review the finished plan before presenting it.** Read it once, checking exactly five things:
   - **Spec coverage** — every line of `### End State` maps to at least one phase, and every `### Acceptance Criteria` item is provable once the last phase is done. Name any that are not.
   - **Placeholders** — no `TBD`, `TODO`, `[bracketed instruction]`, `...`, "similar to above", or "etc." survives in `### End State`, `### Acceptance Criteria`, or any phase's `### Assumptions`, `### Changes Required`, or `### Success Criteria`. Every value is concrete. The one exception is an `### End State` or `### Acceptance Criteria` line the Step 1 input gate could not get answered: it ships carrying its `(unverified)` mark. Two field-specific forms count as placeholders: an `### Acceptance Criteria` list that restates phase steps rather than proving the finished feature works, and a phase whose `### Assumptions` reads `(none)` while its `### Changes Required` edits a file no earlier phase produced — editing a file this plan has not already characterized means holding assumptions about what is in it.
   - **Interface consistency** — every name and type in a phase's `Consumes` appears verbatim in some earlier phase's `Produces`.
   - **Execution schedule** — every phase appears exactly once; every wave has one main phase and at most one background phase; same-wave phases name disjoint files and do not consume each other's outputs; every consumed output is produced in an earlier wave.
   - **Confidence rollup** — `### Decisions Most Likely to Change` names at most three lines, each pointing at a phase that exists. Every assumption marked `Confidence: Unclear` appears there unless the section is already at three.

   Fix what the review finds, then present.

If on main/master branch or commit is pushed, generate GitHub permalinks for file references.

### Step 5: Sync and Review

1. **Present the draft plan location**:

   If any `### End State` or `### Acceptance Criteria` line still carries `(unverified)`, list those lines first and ask the user to confirm or correct them — `df:implement` does not read the mark, so this is the last point at which a guessed goal can be caught.

   ```
   I've created the initial implementation plan at:
   `thoughts/plans/YYYY-MM-DD_HHMM_topic.md`

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

- Unless the user accepted the skip offer, plan file created at `thoughts/plans/YYYY-MM-DD_HHMM_topic.md` with all sections populated
- Each phase has specific file:line references, concrete changes, and separated automated/manual success criteria
- `## Execution Schedule` assigns every phase to one valid main or background slot
- User confirms plan structure, phasing, and technical approach

</success_criteria>

<success_criteria_guidelines>

Success criteria exist at two levels and answer different questions:

- **Plan level** — `### Acceptance Criteria`, under `## Desired End State`. Does the finished feature work? An independent reviewer runs these without reading the phases.
- **Phase level** — `### Success Criteria`, inside each phase. Did this phase's work happen correctly?

A phase-level check that a file now contains a function is not evidence that the feature works. Never let the phase-level list stand in for the plan-level one.

Within a phase, always separate success criteria into two categories:

1. **Automated Verification** (can be run by execution agents):
   - Commands that can be run: `make test`, `npm run lint`, etc.
   - Specific files that should exist
   - Code compilation/type checking
   - Automated test suites

2. **Manual Verification** (requires human testing):
   - UI/UX functionality
   - Performance under real conditions
   - Edge cases that are hard to automate
   - User-facing behaviour only a person can judge

The presence or absence of manual verification items controls whether the implementer pauses after a phase. Only add manual checks where human judgment is genuinely needed.

</success_criteria_guidelines>

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

- Size delegated work after the current workflow's own inspection: use no sub-agent for a narrow question the main thread can answer, and add an agent only for a distinct, self-contained question.
- Prefer a named agent over `general-purpose` wherever one covers the job: the catch-all inherits every tool and carries the highest mean context per turn of any agent type, 90.3k, while a named agent's declared tool list bounds where it can wander. The catch-all's 23k first-turn system-prompt floor, against 9.3k for a locator, is the smaller half of the gap.
- Give an agent paths and the question, not file contents or your session history — everything you paste into a dispatch prompt stays resident in your context for the rest of the session and is re-read on every later turn
- After an agent returns no meaningful findings, narrow or reframe the question before another dispatch — never repeat the same search unchanged
- Use a locator only when relevant paths are unknown; when paths or symbols are known, dispatch an analyzer or pattern finder directly
- Run multiple agents in parallel only for independent areas
- Give every agent an objective, an independent boundary, a concise output shape, and required file:line evidence — provide what to establish, not how to search
- Do not write detailed prompts about HOW to search; the agents already know
- Keep prompts focused on read-only operations
- Verify high-impact, surprising, or contradictory results — if unexpected, cross-check against the actual codebase

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

<context_budget>

More context isn't automatically better — accuracy and recall degrade as the token count grows ("context rot"). Scope each phase so it can be implemented from the smallest high-signal token set: the relevant plan section, the directly-affected files, and the references actually needed. Each phase should be independently resumable from the plan section + affected files alone, without prior-phase output or full conversation history. If a phase is large or sprawling, split it into smaller phases or separate plans.

</context_budget>

<constraints>
- Your only output artifact is a plan document in thoughts/plans — don't write or modify files anywhere else. If you find a beneficial code change, document it and suggest /df:implement.
- Settle `### End State` and `### Acceptance Criteria` before spawning any research agent — a goal question asked after the context load is asked too late to be worth answering
- Wait for all sub-agents to complete before synthesizing — partial results lead to incomplete or contradictory conclusions
- Gather metadata before writing the document — git state should be captured at planning time, not after
- Don't write the plan with placeholder values or unresolved questions — plans are permanent artifacts that will be executed by other agents. The one exception is an `### End State` or `### Acceptance Criteria` line the input gate could not get answered: it ships marked `(unverified)`, never dropped and never presented as settled

</constraints>
