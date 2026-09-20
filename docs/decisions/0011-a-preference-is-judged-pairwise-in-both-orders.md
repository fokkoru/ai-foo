---
title: "A preference is judged pairwise in both orders"
description: "When the question is which of two responses reads better, one judge sees both for the same cell and repetition, in each order, and a win counts only when the orders agree."
status: stable
decision_id: "db33a49da4c6"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:weave"
  at: "2026-09-20T15:11:41-07:00"
---

# A preference is judged pairwise in both orders

## Context

The harness's two judge runners score one response at a time against a rubric that counts
something, and `paired.py` reads the resulting number cell by cell.[^readme-pref] That instrument
answers how many of a thing a response contains. It does not answer which of two responses reads
better, because no count captures that, and a judge asked to rate one response alone has nothing to
compare it against.

## Decision

A preference between a variant arm and the base arm is judged pairwise. `judge-pair.sh` shows one
judge the two responses for the same model, cell and repetition, once in each order, and appends one
row per order to a CSV that `pairs.py` reads. A repetition is a win only when both orders name the
variant and a loss only when both name the base; a disagreement between the orders is a split,
reported and dropped rather than resolved, because position bias in a preference judge is large
enough that one order alone is not a reading.[^pairs-doc] A reply that is not one of the two letters
is recorded as `ERROR`, never as a loss, and a row already in the CSV is not judged again, so an
interrupted pass resumes by re-running it.[^judge-pair-header]

## Consequences

The cell stays the unit of analysis, as
[The cell is the unit of analysis](0003-the-cell-is-the-unit-of-analysis.md) requires: each cell
contributes its wins minus its losses across repetitions, and the sign test runs over those
differences. The repetition totals are printed beside it as the number that is not independent,
because two repetitions of one cell share that cell's difficulty.[^pairs-doc] A split costs two judge
calls and yields no observation, so a variant the judge cannot tell from the base spends the most and
shows the least.

The judge runs from an empty temporary directory, for the same reason the count-based runners do: a
checkout's own writing rules would otherwise reach the model deciding whose prose is
better.[^judge-pair-header] The Claude family has been run; the Codex branch has never had a reply
come back, so its first real use is a smoke test.[^readme-pref]

[^readme-pref]: `scripts/eval/README.md`, "Judging a preference instead of a count".

[^pairs-doc]: `scripts/eval/pairs.py`, module docstring.

[^judge-pair-header]: `scripts/eval/judge-pair.sh`, header comment.
