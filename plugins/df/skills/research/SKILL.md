---
name: research
description: Use when researching a codebase with main-thread investigation, adaptive parallel sub-agents for independent areas, and a self-contained research document
disable-model-invocation: true
allowed-tools: Read, Write, Grep, Glob, TodoWrite, Task, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(gh repo view:*)
---

<objective>
Answer a user's codebase question with main-thread investigation, bounded parallel research where it adds independent coverage, and a structured research document.

</objective>

<artifact_scope>
This is a document-only command.
Your only output artifact is a single document under thoughts/research.
Don't create, write, or modify files anywhere else.
Before any Write call, verify the target path is inside thoughts/research — if it is not, stop and ask the user.
If you identify a beneficial code change, document it in the research document and suggest the user run /df:implement. Do not make code changes in this command.

</artifact_scope>

<quick_start>
If no research question is provided, ask the user what they want to research before proceeding.

1. Read authoritative task artifacts fully
2. Run a lightweight scope pass
3. Choose main-only or main-plus-background research lanes
4. Dispatch independent background lanes, then investigate the main lane immediately
5. Resolve every lane and verify important claims
6. Synthesize findings and write the research document
7. Present a concise summary with key file references

</quick_start>

<workflow>

### Read Task Context

Read any explicitly referenced ticket, specification, research document, or plan fully in the main context because it defines the task. For every other repository file — including source, tests, logs, JSON, and generated data — decide what evidence to retrieve from the research question. A mentioned path does not by itself require a complete read.

### Scope Pass

Survey the repository with `Grep` and `Glob` only far enough to identify the central investigation and any independent areas that could change the answer. Findings from this pass are valid main-thread evidence; carry them into the investigation instead of reserving findings for sub-agents.

Ask the user only when the pass exposes a decision that repository evidence cannot answer and different choices would materially change the research question or conclusion. Resolve uncertainty about paths, research order, or fan-out through investigation. Carry a decision the user declines to make into the document's `## Open Questions`.

### Choose Research Lanes

Choose the smallest shape that covers the question:

- **Narrow file, symbol, or behavior**: investigate in the main thread; dispatch no sub-agent.
- **One subsystem with independent aspects**: keep the central code path in the main thread and dispatch up to two background lanes.
- **Cross-cutting or whole-codebase question**: keep the central architectural question in the main thread and dispatch two to four background lanes with distinct boundaries.

Give every background lane a path boundary as well as a question boundary: name the files or directories it owns, and name them in no other lane's dispatch. Sub-agents share no cache, so two lanes sent over one path read it twice at full price.

Do not spawn an agent merely to reach a count. Create a TodoWrite research plan that names the main lane and every background lane, with one owner per area and no duplicated questions.

### Execute Research Lanes

Dispatch all background lanes in parallel before starting the main lane. Give each sub-agent the question, known paths, its independent boundary, and the expected concise output with file:line evidence. Pass paths rather than file contents or session history, and describe what to establish rather than how to search.

Investigate the main lane immediately after dispatch. Do not launch background work and wait while the main thread is idle. If the runtime cannot dispatch asynchronously, complete the main lane first, then run only the remaining independent lanes.

### Resolve and Synthesize

Before synthesis, resolve every dispatched lane. Join running agents. If a lane fails without useful findings, investigate that area in the main thread or record why it remains unresolved. Treat partial output as evidence only after checking the relevant claim against the live codebase.

Cross-check high-impact, surprising, or contradictory sub-agent claims against the actual code. Do not repeat an agent's entire investigation when a targeted check can establish the claim.

- Compile main-thread and sub-agent findings
- Prioritize live codebase findings as primary source of truth
- Read compiled `docs/` pages before raw thoughts/ notes; both are historical context, the live codebase is primary
- Connect findings across different components
- Include specific file paths and line numbers for reference
- Highlight patterns, connections, and architectural decisions
- Answer the user's specific questions with concrete evidence

### Research Document

Gather metadata before writing the document:

- Get current date/time with timezone: `date +"%Y-%m-%d %H:%M:%S %Z"`
- Get author name: `git config user.name`
- Get current commit hash: `git rev-parse HEAD`
- Get current branch name: `git rev-parse --abbrev-ref HEAD`
- Filename: `thoughts/research/YYYY-MM-DD_HHMM_topic.md`

Structure the document with YAML frontmatter followed by content. `## Research Question`, `## Summary`, `## Detailed Findings`, and `## Open Questions` are required in every document; every other section below is conditional — include it when the research produced content for it, and omit a section with nothing to say rather than filling it with a placeholder.

```markdown
---
date: "[date]"
researcher: "[git user name]"
git_commit: "[commit hash]"
branch: "[branch name]"
topic: "[topic]"
tags: [research, codebase]
status: complete
last_updated: "[date]"
last_updated_by: "[git user name]"
---

# Research: [User's Question/Topic]

## Research Question

[Original user query]

## Summary

[High-level findings answering the user's question]

## Detailed Findings

### [Component/Area 1]

- Finding with reference ([file.ext:line](permalink))
- Connection to other components
- Implementation details

### [Component/Area 2]

...

## Recommendation

[The course of action the findings support. Omit this section when the research is purely descriptive.]

## Code References

[The entry points a reader must open to act on this document — one line each, not a ledger of every path the findings cite.]

- `path/to/file.py:123` - Description of what's there
- `another/file.ts:45-67` - Description of the code block

## Architecture Insights

[Patterns, conventions, and design decisions discovered]

## Prior Work

[Every document this research already relies on — research, plans, handoffs — each with a line reference and one line naming what that document established. A document worth listing is worth annotating.]

- `thoughts/research/YYYY-MM-DD_HHMM_topic.md:42` - What that document established
- `thoughts/plans/YYYY-MM-DD_HHMM_topic.md:10` - What that document established

## Open Questions

[Areas that need further investigation]
```

If on main/master branch or commit is pushed, generate GitHub permalinks for file references.

### Presenting Results

- Present a concise summary of findings to the user
- Include key file references for easy navigation
- Ask if they have follow-up questions or need clarification
- For follow-ups, append to the same research document and choose the research shape again; handle a narrow follow-up in the main thread
  - Update fields: `last_updated`, `last_updated_by`
  - Add `last_updated_note: "Added follow-up research for [brief description]"`
  - Add new section: `## Follow-up Research [timestamp]`

</workflow>

<success_criteria>

- Every research lane resolved through completed findings, main-thread recovery, or an explicit limitation
- Research document created with metadata filled in (no placeholder values)
- Findings include specific file paths and line numbers
- User's question answered with concrete evidence from codebase
- Summary presented with key file references for navigation

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

| Agent               | Purpose                                 | When to Use                         |
| ------------------- | --------------------------------------- | ----------------------------------- |
| `thoughts-locator`  | Discover compiled pages, then raw notes | Find what the project already knows |
| `thoughts-analyzer` | Extract insights from thought documents | Deep dive into historical context   |

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

- Tracing every single import/dependency
- Analyzing generated or vendored code (node_modules, build/, dist/, .git/)
- Researching test implementations unless specifically asked
- Exploring unrelated "interesting" findings
- Understanding entire subsystems when only a component is needed
- Historical changes unless specifically about evolution/decisions

Stay focused on answering the user's actual question.

</anti_patterns>

<constraints>
- Research documents must be self-contained — a reader with no access to this session should be able to act on the document alone

</constraints>
