---
name: research
description: Use when researching the codebase comprehensively using parallel sub-agents
disable-model-invocation: true
allowed-tools: Read, Write, TodoWrite, Task, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(gh repo view:*)
---

<objective>
Conduct comprehensive codebase research to answer a user's question by decomposing it into parallel sub-agent tasks and synthesizing findings into a structured research document.
</objective>

<artifact_scope>
This is a document-only command.
Your ONLY output artifact is a single document under thoughts/research.
NEVER create, write, or modify files anywhere else.
Before any Write call, verify the target path is inside thoughts/research — if it is not, stop and ask the user.
If you identify a beneficial code change, document it in the research document and suggest the user run /df:implement. Do not make code changes in this command.
</artifact_scope>

<quick_start>
If no research question is provided, ask the user what they want to research before proceeding.

1. Read any mentioned files fully in main context first
2. Decompose the research question into parallel sub-agent tasks
3. Select appropriate agents and spawn them in parallel
4. Wait for ALL sub-agents to complete
5. Synthesize findings and write research document
6. Present concise summary with key file references
   </quick_start>

<workflow>

### Read Before Decomposing

If the user mentions specific files (tickets, docs, JSON), read them fully in the main context before spawning any sub-tasks. Use the Read tool without limit/offset parameters to get entire file contents. Never delegate this initial reading to sub-agents.

### Decomposition Strategy

Take time to ultrathink about the underlying patterns, connections, and architectural implications the user might be seeking. Break the query into composable research areas:

- Identify specific components, patterns, or concepts to investigate
- Consider cross-component connections and architectural patterns
- Consider which directories, files, or architectural patterns are relevant
- Create a research plan using TodoWrite to track subtasks

### Synthesis

Wait for ALL sub-agent tasks to complete before synthesizing. Never proceed with partial results.

- Compile all sub-agent results (codebase and thoughts findings)
- Prioritize live codebase findings as primary source of truth
- Use thoughts/ findings as supplementary historical context
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

Structure the document with YAML frontmatter followed by content:

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

**Date**: [date]
**Author**: [git user name]
**Git Commit**: [commit hash]
**Branch**: [branch name]

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

## Code References

- `path/to/file.py:123` - Description of what's there
- `another/file.ts:45-67` - Description of the code block

## Architecture Insights

[Patterns, conventions, and design decisions discovered]

## Historical Context (from thoughts/)

[Relevant insights from thoughts/ directory with document references]

## Related Research

[Links to other research documents in the research directory]

## Open Questions

[Areas that need further investigation]
```

If on main/master branch or commit is pushed, generate GitHub permalinks for file references.

### Presenting Results

- Present a concise summary of findings to the user
- Include key file references for easy navigation
- Ask if they have follow-up questions or need clarification
- For follow-ups, append to the same research document and spawn new sub-agents as needed
  - Update fields: `last_updated`, `last_updated_by`
  - Add `last_updated_note: "Added follow-up research for [brief description]"`
  - Add new section: `## Follow-up Research [timestamp]`

</workflow>

<success_criteria>

- All sub-agent tasks completed (no partial results)
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

<key_principles>

- Always use parallel Task agents to maximize efficiency and minimize context usage
- Always run fresh codebase research; never rely solely on existing research documents
- Focus on concrete file paths and line numbers for developer reference
- Research documents should be self-contained with all necessary context
- Keep the main agent focused on synthesis, not deep file reading
- Encourage sub-agents to find examples and usage patterns, not just definitions
- Include temporal context (when the research was conducted)
- Link to GitHub when possible for permanent references
  </key_principles>

<circuit_breakers>
Stop and reframe the research if:

- No meaningful findings after 3 parallel agent attempts
- Core directories/files mentioned don't exist
- Sub-agents return contradictory information
- More than 10 sub-agents needed (scope too broad)
- Research expanding beyond original question
- If agent spawning fails with "agent not found" (Codex CLI), the required subagents may not be installed — see the plugin README for the manual `cp codex/agents/*.toml ~/.codex/agents/` step. On Claude Code, this should not happen; if it does, reinstall the plugin.

When triggered: reframe more narrowly, ask the user for clarification, or document what couldn't be researched and why.
</circuit_breakers>

<constraints>
- Your ONLY output artifact is a research document in thoughts/research — NEVER write or modify files anywhere else. If you find a beneficial code change, document it and suggest /df:implement.
- Read mentioned files first in main context before spawning sub-tasks — sub-agents don't share the main context and will miss this information
- Wait for all sub-agents to complete before synthesizing — partial results lead to incomplete or contradictory conclusions
- Gather metadata before writing the document — git state should be captured at research time, not after
- NEVER write the research document with placeholder values — research documents are permanent artifacts that others will reference
</constraints>
