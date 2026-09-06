---
type: decision
title: "The rung decides what a prompt edit runs"
description: "A prompt edit is gated by what it is expected to do, on a three-rung ladder from no paid run to a full sweep with judging."
status: stable
decision_id: "529d50bf4cdd"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:compile"
  at: "2026-09-03T23:13:51-07:00"
sources:
  - resource: "CONTRIBUTING.md"
    id: "rung-ladder"
    fragment: "## Changing a Shipped Prompt"
    sha256: "5a52035b1ccd"
---

# The rung decides what a prompt edit runs

## Context

A prompt this repository ships is prose whose effect is on how the model behaves rather than on what
a script computes. Frontmatter length, tag vocabulary, agent mirror drift and docs conformance each
already have a checker, and a behavioural experiment is the wrong instrument for a question with a
mechanical answer.[^rung-ladder]

## Decision

Every edit to a shipped prompt carries a rung, and the rung is chosen from what the edit is expected
to do rather than from what the diff looks like. R0 is an edit that claims no behavioural change, and
the mechanical checkers are its whole gate. R1 is an edit expected to change output where a
mechanical proxy for the change exists, and it runs `scripts/eval/check.sh` over two arms, one
primary metric and one cell set. R2 is an edit expected to change output where no mechanical proxy
exists, and it runs known negatives, then a floor check, then the sweep, then judging restricted to
the cells no key already answers.[^rung-ladder]

The author proposes the rung and whoever ships the change confirms it. At R1 and R2 the confirmed
rung, the baseline, the candidate, the primary metric and the cells are written down before the run,
while the numbers are still unknown.[^rung-ladder]

## Consequences

A metric read after the run is a new question rather than a second chance at the first
one.[^rung-ladder]

Price is a property of the cells, not of the rung. A rung is priced before it is queued, by running
`scripts/eval/cost.py` on the previous results directory and multiplying its median by arms, models,
cells and repetitions.[^rung-ladder]

All arms of one comparison run on a single Claude Code version and the writeup records it, since
scores from either side of a version change are not comparable.[^rung-ladder]

Rewording a rule can change its scope, its strength or its exceptions, so no reading of the text
alone assigns a rung. That is why the ladder turns on intent, and why the judgement stays with the
author and the shipper rather than with a script.[^rung-ladder]

How a comparison is then read is
[The cell is the unit of analysis](0003-the-cell-is-the-unit-of-analysis.md), and the machinery each
rung names is [Prompt A/B harness](../architecture/prompt-eval-harness.md).

[^rung-ladder]: `CONTRIBUTING.md`, "Changing a Shipped Prompt".
