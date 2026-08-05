# [Feature/Task Name] - Implementation Plan

**Date**: [date]
**Author**: [git user name]
**Git Commit**: [commit hash]
**Branch**: [branch name]

## Overview

[What is changing, why it matters, and the selected implementation strategy]

## Current State

- [Relevant behavior or constraint with `file:line` evidence]

## Desired End State

### End State

- [Checkable statement that is true once the plan is complete]

### Acceptance Criteria

- [ ] [Command, observable behavior, or file state that proves the finished feature works]

### Decisions Most Likely to Change

- Phase [N] — [Defaulted, unclear, user-facing, or stored-data decision; use `(none)` when none apply and cap the list at three]

## Global Constraints

- [Constraint copied verbatim from its source] — source: `path/to/source:line`, or `(none)`; every phase implicitly inherits this section

## What We're NOT Doing

- [Explicitly excluded outcome, or `(none)`]

## Rabbit Holes to Avoid

- [Task-specific complexity trap, or `(none)`]

## Implementation Approach

[High-level approach, boundaries, and reasoning. Include migration or performance decisions here only when they apply across phases.]

## Execution Schedule

| Wave | Main-thread phase | Background phase |
| ---- | ----------------- | ---------------- |
| 1    | Phase [N]         | Phase [N]        |

List every phase exactly once. Use `(none)` when a wave has no safe background phase.

## Phase [N]: [Descriptive Name]

### Overview

[The independently verifiable outcome of this phase]

### Interfaces

- **Consumes**: [Exact earlier-phase contract, or `(nothing)`]
- **Produces**: [Exact contract later phases require, or `(nothing)`]

Keep only consequential cross-phase contracts. Do not specify incidental internal signatures.

### Assumptions

- **Assumption**: [Material fact this phase relies on] — source: `path/to/file.ext:line`
  - **If wrong**: [Concrete consequence]
  - **Confidence**: Confident | Likely | Unclear

Write `(none)` only when every affected file was produced by an earlier phase and no material codebase assumption remains.

### Changes Required

#### [Component or file group]

- **Files**: `path/to/file.ext`
- **Outcome**: [Observable change and boundary]
- **Contract**: [Only a consequential interface, data shape, or pseudocode decision; otherwise omit]

### Success Criteria

#### Automated Verification

- [ ] [Runnable command or objectively inspectable result]

#### Manual Verification

- [ ] [Check requiring genuine human judgment, or `(none)`]

## References

- Related research: `thoughts/research/[relevant].md`
- Supporting implementation: `path/to/file.ext:line`
