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

### End State

What is true when this plan is done. One checkable statement per line — not a paragraph. `df:validate` and `df:peer-review` read this list item by item.

- [Checkable statement that is true once the plan is complete]
- [Another checkable statement]

### Acceptance Criteria

The end-to-end checks that prove the feature works — not that a step happened. Each names a command, an observable behaviour, or a file state an independent reviewer could run without reading the phases.

- [ ] [Command, observable behaviour, or file state that proves the whole feature works]
- [ ] [Another end-to-end check]

### Key Discoveries:

- [Important finding with file:line reference]
- [Pattern to follow]
- [Constraint to work within]

## Global Constraints

[Project-wide rules every phase must satisfy — version floors, API contracts, security requirements, compatibility guarantees. Write "(none)" if there are none.]

Copy each constraint **verbatim from its source** — the ticket, the spec, a config file, CLAUDE.md. Do not paraphrase it into a process instruction; a re-worded constraint stops being enforced.

- [Constraint, in the source's own words] — source: `path/to/source:line`
- [Constraint, in the source's own words] — source: `path/to/source:line`

Every phase's requirements implicitly include this section.

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

### Interfaces

- **Consumes**: [what this phase uses from earlier phases — exact names, signatures, and types, or "(nothing)"]
- **Produces**: [what later phases rely on — exact function, type, and file names with parameter and return types, or "(nothing)"]

A phase must be implementable from its own section plus the files it names. This block is how a resumed session learns what its neighbours did.

### Assumptions

What this phase takes to be true about the codebase. `df:implement` re-checks every one of these against the live code before it writes anything — an assumption with no `source:` is one it cannot check. Write "(none)" only when every file this phase edits was produced by an earlier phase of this plan; editing a file the plan has not already built means holding assumptions about what is in it.

- **Assumption**: [What this phase takes to be true] — source: `path/to/file.ext:line`
  - **If wrong**: [What breaks, concretely]
  - **Confidence**: Confident | Likely | Unclear

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

[Same structure: Overview, Interfaces, Assumptions, Changes Required, and Success Criteria with both automated and manual items]

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

- Related research: `thoughts/research/[relevant].md`
- Similar implementation: `[file:line]`
