---
type: decision
title: "One rule, one place"
description: "A behavioural rule lives at its point of use plus the hard gate, and a restatement is classified before it is removed."
status: stable
supersedes: ""
superseded_by: ""
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
sources:
  - resource: "CLAUDE.md"
    id: "orop-rule"
    fragment: "## Gotchas"
    sha256: "0e90536983a8"
---

# One rule, one place

## Context

A skill file accumulates catch-all sections — Guidelines, Key Principles, an agent's closing
Important Guidelines — that restate rules already stated where they fire. Restating does not
reinforce the rule: it creates copies, and copies drift apart.[^orop-rule]

## Decision

A behavioural rule belongs at its point of use — the workflow step or section where it fires — plus
the hard-gate section when it is a gate. Before removing a restatement, classify it: a **duplicate**
survives at an equal-or-stronger slot and is deleted; an **orphan** has no other copy and is moved
verbatim, never deleted; a **conflict** is two copies that disagree, and it is resolved rather than
cut.[^orop-rule]

Classify against the post-edit file. Two blocks being deleted together cannot cover for each
other.[^orop-rule]

Slot strength, strongest first: the hard-gate section and the workflow step that fires the rule,
then the anti-patterns section, then success criteria and the quick start, then any catch-all
guidelines section.[^orop-rule]

## Consequences

The classification is what costs. Every removal has to name the slot the rule survives at, or state
the move, so the work is line by line rather than a diff.[^orop-rule]

Two wordings of one rule both look correct on the page, which is the case a judgement cannot settle.
How this repository measures one prompt against another is in
[The cell is the unit of analysis](0003-the-cell-is-the-unit-of-analysis.md).

[^orop-rule]: `CLAUDE.md`, Gotchas.
