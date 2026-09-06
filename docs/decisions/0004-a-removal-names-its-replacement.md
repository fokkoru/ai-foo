---
type: decision
title: "A removal names its replacement"
description: "A commit that removes a capability names what replaces it in the body, or states that nothing does."
status: stable
decision_id: "8c4e2cdac8be"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:compile"
  at: "2026-09-03T23:13:58-07:00"
sources:
  - resource: "CONTRIBUTING.md"
    id: "removal-rule"
    fragment: "## Commit Conventions"
    sha256: "f86e9f3bad9d"
  - resource: "CLAUDE.md"
    id: "checks-blind"
    fragment: "## Verify Before Finishing"
    sha256: "f6107b0487d9"
---

# A removal names its replacement

## Context

Three regressions reached the main branch, all of one kind: a capability that existed, was removed
by a refactor whose commit subject described something else, and left no replacement. None was
mentioned in a commit body.[^removal-rule]

The repository's checks could not see any of them. They verify mirror parity, table identity and
description length — all shape. Every one of the three changed behaviour while leaving structure
intact, so every check passed.[^checks-blind]

## Decision

A commit that removes a capability names its replacement in the body, or states that there is none.
This covers a named step, a workflow trigger, an agent dispatch, a documented behaviour — anything a
user could have relied on. A removal is never typed `refactor`: if behaviour changed, the type is
`feat` or `fix`.[^removal-rule]

A second place carries each guarantee. Each skill's row in the plugin readme's "It's working if"
table states what a user sees when the skill is doing its job, checkable from the run in front of
them, so removing a guarantee from a skill has to fail that table too.[^checks-blind]

## Consequences

The subject line describes the change a commit is for; a removal riding along under it leaves no
record anywhere, which is how the three reached the main branch.[^removal-rule]

The second place is what turns a silent removal into a contradiction. A change that narrows a
guarantee now has to edit the table that publishes it, or leave the repository disagreeing with
itself.[^checks-blind]

Neither control is a behavioural test. Both are read by a person, and reading cannot certify the
absence of a fourth regression.

[^removal-rule]: `CONTRIBUTING.md`, commit-body rules.

[^checks-blind]: `CLAUDE.md`, Verify Before Finishing.
