---
type: decision
title: "Model tiering for dispatched work"
description: "Judging never drops below the strong tier, effort is pinned in frontmatter rather than chosen per dispatch, and no df dispatch names a model."
status: stable
supersedes: ""
superseded_by: ""
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
sources:
  - resource: "CLAUDE.md"
    id: "tiering-gotcha"
    fragment: "## Gotchas"
    sha256: "0e90536983a8"
  - resource: "plugins/df/agents/code-reviewer.md"
    id: "cr-frontmatter"
    fragment: "L1-L7"
    sha256: "05c75de3a966"
---

# Model tiering for dispatched work

## Context

A dispatched agent that names no model inherits the session's, which is the most expensive one, and
the omission is invisible in the transcript. The opposite failure is worse and harder to see: a weak
judge is lenient, and leniency in a judgement is a rare event with a large blast radius that a
pass/fail gate cannot show.

The asymmetry is sharpest for the agent that refutes findings. A missed defect can still be caught
downstream, but a wrongly refuted finding is gone and nothing else looks at it, which is why the
refuter is pinned to the strong tier rather than defaulted to it.[^tiering-gotcha]

## Decision

A step whose job is to judge — reviewing a diff, or calling a finding real or false — stays at the
strong tier and never moves down. `sonnet` is the floor for the reviewer, and `haiku` is never valid
for either judging agent.[^tiering-gotcha]

Effort is not a per-dispatch knob. `effort: high` stays in both agents' frontmatter because the
harness reads `effort:` only from there, and the second runtime's mirrors carry the same
value.[^tiering-gotcha][^cr-frontmatter]

## Consequences

Every tier choice lives in agent frontmatter. df names a model in no dispatch of its own, so a
caller that names nothing gets the strong default. A caller may name the middle tier for a narrow,
task-scoped review, and the scoping is what makes that safe; nothing measured supports it, so it
stays available and unused.[^tiering-gotcha]

On the second runtime the mirrors pin no model at all, so that half of the choice comes from the
user's own configuration rather than from the agent file.[^tiering-gotcha]

The local evidence for the floor is one run in which a cheap-tier reviewer flagged 0 of 10 planted
defects at correct severity. It is read with its caveat: planted defects are the exact condition
under which review F1 was measured to collapse 92% from synthetic samples to real pull requests. The
direction is corroborated independently — weak judges show measurably higher false-negative rates
under suggestive framing, and no surveyed framework routes code review to a cheap model without a
compensating structure.[^tiering-gotcha]

The fleet those tiers apply to is in
[Agent fleet and its tiers](../architecture/agent-fleet.md).

[^tiering-gotcha]: `CLAUDE.md`, Gotchas.

[^cr-frontmatter]: `plugins/df/agents/code-reviewer.md`, frontmatter.
