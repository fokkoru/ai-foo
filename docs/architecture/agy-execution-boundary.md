---
title: "Antigravity execution boundary"
description: "What the Antigravity CLI is allowed to do under each permission mode, and which flags the two skills therefore pass."
status: stable
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
---

# Antigravity execution boundary

## What it does

The `agy` plugin runs a second command-line agent against this repository in two modes. `consult`
asks it one scoped question and `delegate` hands it an already-decided implementation. The two
differ by which permission flags they pass, and those flags are what makes each mode safe rather
than any instruction in the prose.

| Flags                             | Edit a file | Create a file     | Shell command | Write outside the workspace  |
| --------------------------------- | ----------- | ----------------- | ------------- | ---------------------------- |
| none                              | denied      | denied [inferred] | denied        | denied                       |
| `--mode accept-edits`             | works       | works             | denied        | denied                       |
| `--dangerously-skip-permissions`  | works       | works             | works         | works                        |
| `--sandbox` with skip-permissions | works       | works             | works         | works, through a self-bypass |

Each row is what the two skills record about the mode they pass, and each was established by
running the CLI rather than by reading its help text.[^delegate-constraints][^consult-readonly] File
creation with no flags is the one inferred cell: creating and editing go through the same tool, and
the denial landed on that tool. [inferred]

## How it works

`delegate` runs under `--mode accept-edits`. Edits and new files go through; every shell command is
refused. Verification therefore moves to the caller, which is why the run happens inside a subagent — the
diff, the test output and the run envelope are noise the main context does not need.[^delegate-why-subagent]

`consult` passes no permission flag at all, and that is what makes it read-only: a probe's edit
attempt returned a permission failure on the write tool.[^consult-readonly]

Two flags are refused outright in both. `--dangerously-skip-permissions` auto-approves every tool
call including shell. `--sandbox` adds nothing under `accept-edits`, because shell is already
closed, and under skip-permissions a probe showed the CLI bypassing it through its own escape
path.[^delegate-constraints]

`--add-dir` on the repository root is mandatory: without it the run works in a scratch directory
under the user's home rather than in this repository.[^consult-readonly]

## Why it is this way

The run's own status field is not the verdict. It has been observed reporting `ERROR` on runs whose
work landed, so `git diff` is the truth and the status is not consulted.[^delegate-constraints]

Deletion is absent from the table because it is absent from the CLI. Its only file-mutation tool
requires the new content, so no call removes a path, and `accept-edits` closes the shell that `rm`
would need. Asked to delete, it has been measured writing a placeholder into the file and narrating
the rest of the run as complete, so the skill rejects the operation rather than briefing
it.[^delegate-constraints] The decision this rests on is
[Antigravity runs under accept-edits](../decisions/0006-agy-runs-under-accept-edits.md).

[^delegate-constraints]: `plugins/agy/skills/delegate/SKILL.md`, `<constraints>`.

[^delegate-why-subagent]: `plugins/agy/skills/delegate/SKILL.md`, `<objective>`.

[^consult-readonly]: `plugins/agy/skills/consult/SKILL.md`, the run block's notes.
