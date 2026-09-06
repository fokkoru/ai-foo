---
type: product
title: "The df development workflow"
description: "The research-to-commit chain df provides, and the guarantee each step makes."
status: stable
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
sources:
  - resource: "plugins/df/README.md"
    id: "df-overview"
    fragment: "## Overview"
    sha256: "7aac1aa99ad3"
  - resource: "plugins/df/README.md"
    id: "df-skills"
    fragment: "## Skills"
    sha256: "57866131d440"
  - resource: "CLAUDE.md"
    id: "checks-blind"
    fragment: "## Verify Before Finishing"
    sha256: "f6107b0487d9"
---

# The df development workflow

## What it is

A structured chain for feature development, where each step is a skill invoked by name:

```
research → planning → [iterate] → implement → [validate] → [peer-review] → commit → [handoff]
```

Steps in brackets are optional.[^df-overview] Seven of the nine skills are manual-only and cannot be
triggered by the model; `commit` and `deslop` auto-trigger on intent.[^df-skills]

## When it applies

Research is read-only and produces a document that cites `file:line` rather than describing code in
prose. Planning produces a phased plan. Implement executes it one phase at a time, verifying and
reviewing each phase before the next. Validate reports without writing a file. Peer review is an
isolated pass over the branch. Commit sizes its message to the change.[^df-skills]

Each skill publishes a guarantee a user can check from the run in front of them, without opening a
skill file. That table is the second place a guarantee is written down, so removing one from a skill
has to contradict it.[^checks-blind] The rule behind that is
[A removal names its replacement](../decisions/0004-a-removal-names-its-replacement.md), and what
`implement` guarantees about review is in
[Independent review dispatch](../architecture/review-dispatch.md).

[^df-overview]: `plugins/df/README.md`, Overview.

[^df-skills]: `plugins/df/README.md`, Skills and "It's working if".

[^checks-blind]: `CLAUDE.md`, Verify Before Finishing.
