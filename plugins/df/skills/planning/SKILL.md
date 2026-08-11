---
name: planning
description: Use when creating a decision-complete implementation plan between df:research and df:implement, with main-thread analysis and adaptive delegation for independent gaps.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, TodoWrite, Task, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(gh repo view:*)
---

<objective>
Create a decision-complete implementation plan grounded in authoritative task artifacts and targeted live-code evidence.

Keep requirements, consequential decisions, the central technical analysis, and the final document in the main thread. Use background agents only for independent gaps whose parallel investigation improves the plan.

</objective>

<artifact_scope>
This is a document-only command.
Your output artifacts live under thoughts/plans: the new plan, and — only when it supersedes an earlier plan — an edit to that earlier plan's frontmatter.
Don't create, write, or modify files anywhere else.
Before any Write or Edit call, verify the target path is inside thoughts/plans — if it is not, stop and ask the user.
If you identify a beneficial code change, document it in the plan document and suggest the user run /df:implement. Do not make code changes in this command.

</artifact_scope>

<quick_start>
If a file path or task description is provided, begin at Step 1. An explicit invocation of this skill is already the user's decision to create a plan.

If no task description is provided, ask the user for the task or ticket, relevant constraints, and links to related research or previous plans. Then wait for input.

1. Read authoritative task artifacts fully
2. Settle the end state and acceptance criteria
3. Inspect the central implementation path in the main thread
4. Delegate only independent technical gaps, then continue main-thread analysis
5. Resolve consequential decisions and shape the phases
6. Write and fully self-review the plan document

</quick_start>

<workflow>

### Step 1: Read Task Context and Set the Goal

Read every explicitly referenced ticket, specification, research document, and previous implementation plan completely in the main context. Treat these artifacts as the requirements and decision record for planning.

For every other repository file — including source, tests, logs, JSON, and generated data — retrieve only the evidence needed for the planning question. A mentioned path does not by itself require a complete read.

Draft `### End State` and `### Acceptance Criteria` from the task artifacts before investigating the codebase. Ask the user only when all of these are true:

- the artifacts and repository cannot answer the question
- different answers materially change what will be built or how completion is observed
- choosing a default without the user would create a meaningful product, compatibility, or architecture risk

Put the recommended answer first and batch independent questions into one message. Do not ask for confirmation of facts that the repository can establish.

If the runtime cannot ask, the user declines to decide, or no answer arrives, choose the safest recommended default. Mark affected End State or Acceptance Criteria lines `(unverified)` and carry those exact marks into the plan.

### Step 2: Establish the Main Analysis Lane

Run a lightweight `Grep` and `Glob` scope pass only far enough to identify the central implementation path, affected boundaries, and independent unknowns. Findings from this pass are main-thread evidence; do not reserve codebase understanding for sub-agents.

Use an existing research document as a high-signal map rather than repeating its exploration. Cross-check claims that are high-impact, surprising, contradicted by the current code, or plausibly stale. Prefer targeted symbol, interface, and configuration checks over reading every referenced source file.

Investigate the central path in the main thread. Establish:

- the relevant current behavior and constraints
- the smallest implementation shape that reaches the End State
- affected files and observable interfaces
- material assumptions with `file:line` evidence
- verification that proves the finished behavior

### Step 3: Delegate Independent Gaps Adaptively

Choose the smallest research shape after the main-thread scope pass:

- **Narrow task or sufficient research artifact**: use no sub-agent.
- **Independent technical gaps remain**: dispatch up to two background agents with distinct, self-contained questions.
- **A new blocking gap appears later**: dispatch another agent only when it could not have been part of the earlier lanes and cannot be settled with a few targeted main-thread tool calls.

Create a TodoWrite research plan only when there is more than one lane to track. Give one owner to each lane and do not duplicate questions.

Dispatch independent background lanes together, then continue the central analysis immediately. Do not launch agents and leave the main thread idle. If asynchronous dispatch is unavailable, complete the main lane first and then investigate only the remaining gaps.

Resolve a lane when the plan needs its conclusion. If an agent fails or returns no useful evidence, narrow the question and investigate it in the main thread; do not repeat the same dispatch unchanged. Before writing the plan, resolve every delegated lane through findings, main-thread recovery, or an explicitly recorded uncertain assumption.

### Step 4: Resolve Facts and Consequential Decisions

Classify user feedback before reacting:

- Treat product intent, priorities, and preferences as authoritative user decisions.
- Verify claims about current code with a targeted main-thread check. Delegate only if the correction exposes a genuinely independent technical gap.

Present design options only when more than one viable choice remains and the choice materially changes the resulting system. Lead with a recommendation and explain the concrete tradeoff. Do not add generic checkpoints for confirming your understanding, proposed approach, or phase structure; proceed when no consequential user decision remains.

Record each defaulted but consequential decision under `### Decisions Most Likely to Change`. A decision-complete plan may acknowledge uncertainty, but it must still select one implementable path.

### Step 5: Shape the Plan

Define the solution envelope before the phases:

- **What must be true when this is done** → `### End State`
- **How it is proven end to end** → `### Acceptance Criteria`
- **Checks too coarse for one phase** → `### Wave Checks`
- **Rules no phase may break** → `## Global Constraints`
- **What not to build** → `## What We're NOT Doing`
- **Complexity traps to avoid** → `## Rabbit Holes to Avoid`

Specify outcomes, affected boundaries, and consequential interfaces. Include exact signatures, types, pseudocode, or code fragments only when they lock a non-obvious decision that the implementer must not reinterpret. Do not prescribe incidental internals that the implementer can derive safely from the named files and contracts.

Make each phase the smallest independently verifiable deliverable worth a review gate. Fold setup, scaffolding, configuration, tests, and documentation into the phase whose outcome needs them. Split only when a reviewer could reject one phase while approving another.

For each phase:

- name affected files or file groups and the intended outcome
- name `Consumes` and `Produces` only when another phase depends on that contract
- name under `Affects` every unit outside the phase's files that its changes can break — the wave check covers only the units this line and the wave's files name, so one left out goes unchecked until the final repo-wide run
- record material assumptions with a `source: file:line`, consequence if wrong, and confidence
- separate automated verification from manual judgment; write `(none)` when no manual check is needed
- keep every phase check runnable in seconds — one whose smallest runnable unit is a whole package, module, or directory goes to `### Wave Checks`, where it runs once per wave instead of once per phase

Build `## Execution Schedule` with every phase exactly once, one main phase and at most one background phase per wave, disjoint same-wave files, and every consumer scheduled after its producers. Use `(none)` when no safe background phase exists.

Keep the plan independently resumable from the relevant phase, Global Constraints, and affected files. If a phase needs broad prior conversation context or unrelated source files, narrow or split it.

### Step 6: Write and Self-Review the Plan

Gather metadata immediately before writing:

- Current date/time with timezone: `date +"%Y-%m-%d %H:%M:%S %Z"`
- Author name: `git config user.name`
- Git commit hash: `git rev-parse HEAD`
- Current branch: `git rev-parse --abbrev-ref HEAD`
- Filename: `thoughts/plans/YYYY-MM-DD_HHMM_topic.md`

Read `references/plan-template.md` fully and use it as the document skeleton. Duplicate its phase section for every phase and omit optional interface details that do not apply. Fill the frontmatter block with `status: draft`, `last_updated` set to today's date as `YYYY-MM-DD`, and `supersedes`/`superseded_by` empty unless this plan replaces a named earlier one — in which case write both sides, here and in the plan being replaced. Set the replaced plan's frontmatter `status: superseded` with `last_updated` refreshed to the same `YYYY-MM-DD`; when that plan carries no frontmatter block, add none — the supersession stays recorded in the new plan's `supersedes`.

Read the finished plan completely and fix every issue found in this review:

1. **Spec coverage** — every End State line maps to a phase, and every Acceptance Criteria item proves finished behavior rather than completion of a step.
2. **Decision completeness** — no `TBD`, `TODO`, bracketed instruction, ellipsis, “similar to above,” or unresolved choice survives. Preserve only the Step 1 `(unverified)` marks.
3. **Evidence quality** — every material assumption cites current `file:line` evidence, and high-impact or stale research claims were checked against live code.
4. **Phase consistency** — every consumed contract is produced earlier, each phase contains enough context to implement, and the execution schedule is valid.
5. **Verification quality** — automated checks are runnable or objectively inspectable, manual checks require genuine human judgment, every check sits at the finest tier that can run it, and together they prove the End State.

If on main/master or the commit is pushed, generate GitHub permalinks for source references.

Present the plan path and a concise summary. If any `(unverified)` lines remain, list them first and ask the user to confirm or correct them. Otherwise invite focused corrections without requiring another approval checkpoint.

</workflow>

<success_criteria>

- A reader can implement the selected path from the plan without making an unstated product or architecture decision
- `df:implement` can execute every phase from the document and verify the final End State without recovering this conversation

</success_criteria>

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

- Tracing every import or dependency chain
- Analyzing generated or vendored code
- Researching test internals unless they affect the required behavior or verification strategy

</anti_patterns>

<constraints>

- Write only the plan document under thoughts/plans; document beneficial code changes instead of making them
- Settle End State and Acceptance Criteria before delegating technical research
- Gather git metadata immediately before writing the document
- Produce one concrete, implementable path with no placeholders or unresolved choices; only Step 1 End State or Acceptance Criteria lines may carry `(unverified)`

</constraints>
