---
date: "[date]"
author: "[git user name]"
git_commit: "[commit hash]"
branch: "[branch name]"
status: draft
companions: []
run_base: ""
supersedes: ""
superseded_by: ""
last_updated: "[date]"
---

`companions:` lists every file named under `## Constraint Check`'s **Sources checked**, each one a path relative to the repository root that any reader can open — a path outside it is not a companion. `run_base:` stays empty until `df:implement` writes the run's base SHA into it.

# [Feature/Task Name] - Implementation Plan

## Overview

[What is changing, why it matters, the selected implementation strategy, and the cross-phase decisions no single phase owns — including migration and performance decisions that apply across phases]

## Current State

- [Relevant behavior or constraint with `file:line` evidence]

Hold the facts more than one phase depends on. A fact exactly one phase depends on lives in that phase's `### Assumptions` instead.

## Desired End State

### End State

- [Checkable statement that is true once the plan is complete]

### Acceptance Criteria

- [ ] [Command, observable behavior, or file state that proves the finished feature works]

List every repo-wide command the plan requires here, once. `df:implement` runs this section one time, after the final wave.

### Wave Checks

- [ ] [Check whose smallest runnable unit is a whole package, module, or directory — name the unit it takes], or `(none)`

`df:implement` runs this section once per wave, narrowed to the units holding that wave's files plus the units its phases name under `Affects`. A phase that leaves `Affects` unwritten supplies no narrowing basis, so the check runs unnarrowed.

### Decisions Most Likely to Change

- Phase [N] — [Defaulted, unclear, user-facing, or stored-data decision; use `(none)` when none apply and cap the list at three]

## Constraint Check

- **Sources checked**: `path/to/source`, … — every file listed here is named under `companions:`
- **Written in full**: [Constraint whose source is not a companion] — source: `path/to/source:line`, or `None`
- **Violations**: `None`, or one row per violation

| Violation | Why it is needed | Simpler alternative rejected because |
| --------- | ---------------- | ------------------------------------ |

Every phase implicitly inherits this section.

The section is required and is never omitted or left empty: without it, a reader cannot tell "checked and compliant" from "not checked" from "source unavailable". For a constraint the plan complies with, name the source and stop there — the reader holds that file or opens it. Write a constraint in full when its source is not a companion: a session decision, a specification the reader does not hold, a user's global instructions, or any path outside the repository root, since a path that does not resolve for the next reader carries nothing.

## What We're NOT Doing

- [Explicitly excluded outcome, or `(none)`]

Read by the human approving the plan and by `df:iterate`. One line per entry — a declined outcome, named, with no supporting paragraph.

## Rabbit Holes to Avoid

- [Task-specific complexity trap, or `(none)`]

Read by the human approving the plan and by `df:iterate`. One line per entry — a trap, named, with no supporting paragraph.

## Execution Schedule

| Wave | Main-thread phase | Background phase |
| ---- | ----------------- | ---------------- |
| 1    | Phase [N]         | Phase [M]        |

List every phase exactly once. Use `(none)` when a wave has no safe background phase.

## Phase [N]: [Descriptive Name]

### Overview

[The independently verifiable outcome of this phase]

### Interfaces

- **Consumes**: [Exact earlier-phase contract, or `(nothing)`]
- **Produces**: [Exact contract later phases require, or `(nothing)`]
- **Affects**: [Units outside this phase's files that its changes can break, or `(nothing)`]

Keep only consequential cross-phase contracts. Do not specify incidental internal signatures.

`Affects` is not a contract — it is the narrowing basis for `### Wave Checks`. `(nothing)` claims that nothing outside this phase's own files depends on what it changes.

### Assumptions

- **Assumption**: [Material fact this phase relies on] — source: `path/to/file.ext:line`
  - **If wrong**: [Concrete consequence]
  - **Confidence**: Confident | Likely | Unclear

Write `(none)` only when every affected file was produced by an earlier phase and no material codebase assumption remains. A fact exactly one phase depends on lives here, not in `## Current State`.

### Changes Required

#### [Component or file group]

- **Files**: `path/to/file.ext`
- **Outcome**: [Observable change and boundary — the field that carries them when no `**Contract**` is present]
- **Contract**: [Only a consequential interface, data shape, or pseudocode decision; otherwise omit]

A block carrying a `**Contract**` carries no `**Outcome**` — the contract is the authority, and the outcome restates it.

### Success Criteria

#### Automated Verification

- [ ] [Runnable command or objectively inspectable result, scoped to this phase's files]

Route each check by the smallest unit it can run against. One that takes this phase's files as its argument belongs here, and so does one that reads wider but returns in seconds — a search, a file-shape assertion — because repeating it costs nothing. One that must compile or execute a whole package, module, or directory belongs in `### Wave Checks`, however narrow the behavior it is asserting. One that reads the whole repository belongs in `### Acceptance Criteria`.

#### Manual Verification

- [ ] [Check requiring genuine human judgment, or `(none)`]

## References

- Related research: `thoughts/research/[relevant].md`
- Supporting implementation: `path/to/file.ext:line`
