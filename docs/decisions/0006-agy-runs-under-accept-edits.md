---
type: decision
title: "Antigravity runs under accept-edits"
description: "Delegated runs get file edits and no shell; consultations get no permission flag at all."
status: stable
decision_id: "f8348da78424"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
sources:
  - resource: "plugins/agy/skills/delegate/SKILL.md"
    id: "delegate-gates"
    fragment: "L80-L88"
    sha256: "bf5e92e60e4d"
  - resource: "plugins/agy/skills/delegate/SKILL.md"
    id: "delegate-frontmatter"
    fragment: "L1-L5"
    sha256: "899c4cbfc564"
  - resource: "plugins/agy/skills/delegate/SKILL.md"
    id: "delegate-why-subagent"
    fragment: "L10-L10"
    sha256: "8fd3523ac7cf"
  - resource: "plugins/agy/skills/consult/SKILL.md"
    id: "consult-gates"
    fragment: "L73-L77"
    sha256: "fd3b91dbc91e"
  - resource: "CLAUDE.md"
    id: "claude-md-agy"
    fragment: "### agy (plugins/agy/)"
    sha256: "9e738e6614d4"
---

# Antigravity runs under accept-edits

## Context

Handing work to a second command-line agent means choosing what it may do. The full-permission flag
auto-approves everything, shell included, and a task that needs shell inside the run is split rather
than granted the whole surface. A skill can promise restraint in prose, but only a boundary the CLI
enforces itself is worth having.[^delegate-gates]

## Decision

Delegated runs pass `--mode accept-edits` and nothing wider: file edits and new files go through,
every shell command is refused, and the refusal comes from the tool rather than from skill
prose.[^delegate-gates]

Consultations pass no permission flag at all, which is what makes them read-only, and carry no
blanket shell grant for the binary either — the run asks for permission once, every time, because a
prefix grant would pre-approve every other invocation.[^consult-gates]

Two flags never ship. Full-permission bypass is out because a task that needs shell inside the run
should be split rather than granted the whole surface. The sandbox flag is out because it adds
nothing where shell is already closed and was measured being bypassed where it is
not.[^delegate-gates]

No model is passed in either mode; the user's own configuration decides.[^delegate-gates]

## Consequences

Verification moves to the caller. Under `accept-edits` the delegated agent cannot run tests, linters
or version control, so the brief must say so or the run dies on the first command it tries. That is
not purely a loss: the party accountable for the result is the party that runs the
tests.[^delegate-why-subagent]

That relocated noise is why a delegation runs inside a subagent while a consultation does not. A
consultation's deliverable is the answer, which belongs in the main context; a delegation's is "the
edits landed and the tests pass", and the diff and test output around reaching that verdict do
not.[^delegate-why-subagent]

Both skills are model-invocable and gated on the user having asked by their own descriptions,
because no available mode permits invocation on request while forbidding it
unprompted.[^delegate-frontmatter][^claude-md-agy] Details of what each mode can reach are in
[Antigravity execution boundary](../architecture/agy-execution-boundary.md).

[^delegate-gates]: `plugins/agy/skills/delegate/SKILL.md`, `<constraints>`.

[^delegate-frontmatter]: `plugins/agy/skills/delegate/SKILL.md`, frontmatter.

[^delegate-why-subagent]: `plugins/agy/skills/delegate/SKILL.md`, `<objective>`.

[^claude-md-agy]: `CLAUDE.md`, the agy plugin section.

[^consult-gates]: `plugins/agy/skills/consult/SKILL.md`, `<constraints>`.
