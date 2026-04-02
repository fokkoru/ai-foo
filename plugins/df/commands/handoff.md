---
allowed-tools: Read, Write, Grep, Glob, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*)
description: Create handoff document for transferring work to another session
---

<objective>
Create a concise handoff document that captures current work state for seamless session transfer.

Compact and summarize context without losing key details.
</objective>

<artifact_scope>
This is a document-only command.
Your ONLY output artifact is a single document under [handoffs_dir].
NEVER create, write, or modify files anywhere else.
Before any Write call, verify the target path is inside [handoffs_dir] — if it is not, stop and ask the user.
</artifact_scope>

<quick_start>

1. Run `git status` and `git diff --stat HEAD` to understand current work state
2. Gather metadata (date, author, commit, branch)
3. Analyze the current session's work: what was done, what's pending, what was learned
4. Write the handoff document
5. Present the resume instruction to the user
   </quick_start>

<configuration>
- `[handoffs_dir]`: !`printenv DF_HANDOFFS_DIR || echo thoughts/handoffs`
</configuration>

<workflow>

### Step 1: Gather Context

1. **Collect metadata**:
   - Current date/time: `date +"%Y-%m-%d %H:%M:%S %Z"`
   - Author: `git config user.name`
   - Git commit: `git rev-parse HEAD`
   - Branch: `git rev-parse --abbrev-ref HEAD`

2. **Assess current work state**:
   - Run `git status` to see uncommitted changes
   - Run `git diff --stat HEAD` to see change scope
   - Run `git log --oneline -10` to see recent commits on this branch
   - Review any plan files or research docs that were being worked from

3. **Determine filename**:
   - Format: `[handoffs_dir]/YYYY-MM-DD_HHMM_description.md`
   - Description: kebab-case summary of the work (e.g., `auth-refactor`, `api-endpoint-migration`)

### Step 2: Write Handoff Document

Use this template:

```markdown
---
date: "[date/time with timezone]"
author: "[git user name]"
git_commit: "[commit hash]"
branch: "[branch name]"
topic: "[brief description of work]"
tags: [handoff, relevant-tags]
status: complete
---

# Handoff: [Concise Description]

## Tasks

[Description of tasks worked on with status of each:]

- **Completed**: [what was finished]
- **In Progress**: [what's partially done, with specifics on where it stopped]
- **Planned**: [what was discussed but not started]

[If working from a plan, reference it and note the current phase.]

## Critical References

[2-3 most important files that must be read to continue this work:]

- `path/to/plan.md` — implementation plan being followed
- `path/to/key-file.ext:line` — critical code context

## Recent Changes

[Changes made to the codebase in this session:]

- `path/to/file.ext:line-range` — [what was changed and why]

## Learnings

[Important discoveries that the next session must know:]

- [Pattern, root cause, or insight with file:line references]
- [Gotcha or non-obvious behavior encountered]

## Artifacts

[Files produced or updated during this session:]

- `path/to/artifact.md` — [what it contains]

## Next Steps

[Ordered list of what to do next:]

1. [Most important next action]
2. [Following action]
3. [Further actions]

## Notes

[Other context that doesn't fit above — references, related files, useful commands]
```

### Step 3: Present Resume Instruction

After writing the handoff, respond with:

```
Handoff created at `[path]`.

To resume in a new session, provide this file:
> Read `[path]` and continue the work described in it.
```

</workflow>

<success_criteria>

- Handoff document created at `[handoffs_dir]/YYYY-MM-DD_HHMM_description.md`
- All sections populated with specific, actionable content
- File:line references included for recent changes and critical references
- Next steps are ordered and concrete
- Git metadata captured accurately in frontmatter
  </success_criteria>

<guidelines>
- **More information, not less** — the template is a minimum; include additional context when relevant
- **Be thorough and precise** — include both high-level objectives and implementation details
- **Avoid excessive code snippets** — prefer `file:line` references over inline code blocks; only include code when it describes a specific error or pattern that can't be referenced by location
- **Focus on what a new session needs** — assume no prior context; everything needed to resume should be in the document
</guidelines>

<anti_patterns>

- Including large code blocks or full diffs (use file:line references instead)
- Summarizing at too high a level (losing actionable details)
- Omitting learnings (the most valuable part for the next session)
- Writing next steps without enough context to execute them
- Including information that's already in referenced plan/research documents

Stay focused on creating a useful transfer document, not a comprehensive report.
</anti_patterns>

<circuit_breakers>
Stop and ask the user for guidance if:

- No meaningful work has been done in this session (nothing to hand off)
- Unable to determine what was being worked on (no plan, no recent changes, no context)
- The handoffs directory doesn't exist and can't be created

When triggered: explain what's missing and ask the user what they want captured.
</circuit_breakers>

<constraints>
- Your ONLY output artifact is a handoff document in [handoffs_dir] — NEVER write or modify files anywhere else.
- NEVER fabricate work that wasn't done — only document actual session activity
- NEVER include sensitive data (credentials, tokens, keys) in handoff documents
- NEVER skip the Learnings section — this is the highest-value content for session transfer
- Gather git metadata at handoff time, not earlier — it must reflect the actual state when the handoff is created
</constraints>
