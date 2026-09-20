---
title: "Prompt A/B harness"
description: "How two variants of a shipped prompt are compared against the same fixed tasks."
status: stable
generated:
  by: "kb:weave"
  at: "2026-09-20T15:11:41-07:00"
---

# Prompt A/B harness

## What it does

The harness compares two or more variants of a prompt by running the same fixed tasks under each
and measuring what comes back. A variant is an **arm**, a fixed task is a **cell**, and one run of
one arm on one cell is a **repetition**.[^eval-intro]

It is a maintainer tool. A user installing a plugin receives that plugin's directory and nothing
else, so nothing here reaches an installation.[^eval-intro]

## How it works

One experiment lives in one directory holding `experiment.env`, an `arms/` directory, one prompt
file per cell, and a `metrics.py` defining `score(text) -> dict`. A fixture tree, a judge rubric, a
judge schema and a per-cell ground-truth key are optional. A second run of the same experiment
writes to a second results directory, so runs never overwrite each other.[^eval-dir]

`INJECT` in `experiment.env` names the substitution point, and each value maps to a flag the CLI
documents. Output styles, an appended system prompt, a replaced system prompt, an agent definition
and a plugin directory are the five. Only the output-style path has been run against a model; the
other four build the arguments they claim to against a test double, so the first real use of one is
a smoke test rather than a measurement.[^eval-inject]

`check.sh` is the whole path for a two-arm comparison. It takes the experiment directory, the metric
the comparison reads, the two arms and then the cells, and runs `drive.sh`, `score.py`, `cost.py` and
`paired.py` in that order at three repetitions and parallelism 6 by default.[^eval-running] It stops
at the first failure, so a sweep that lost a run cannot reach `paired.py` and print a difference that
looks measured.[^check-header]

The four also run individually, which is what a comparison of more than two arms needs, since
`paired.py` reads exactly two. `drive.sh` takes the experiment directory, a parallelism, a repetition
count and then the cells, and resumes by re-running the same command, because a combination that
already has a response is not queued again. `score.py` computes the mechanical metrics, `cost.py`
reports cost, wall clock, turns and tokens, `paired.py` makes the comparison, and `mask.py` and
`judge-agy.sh` run only when a metric needs judgement.[^eval-running]

Each script refuses something, and the refusals are what keep a failure from becoming a number.
`run.sh` writes no response for a run that did not succeed, leaving the raw JSON and the cost row
but no `.md`, which is the file a sweep queues on, so the run is retried instead of scored.
`drive.sh` counts the failures and exits nonzero rather than reporting a short sweep as done.
`score.py` computes nothing that needs a model, which is what makes every metric free to recompute
and impossible to bias. `mask.py` will not overwrite an existing `mapping.csv`, because judgements
are keyed by review id, it reports how many responses actually had a label masked rather than
claiming the judge was blind, and it keeps the previous review set until the replacement is written.
`judge-agy.sh` records `ERROR` for anything that is not a usable answer, never a zero, because a
zero would pull that arm's mean down and look like data.[^eval-refusals]

`paired.py` is the comparison. Each model-and-cell pair contributes one number, the median of arm
A's repetitions minus the median of arm B's. It reports the per-pair differences, an exact
two-sided sign test, and a bootstrap interval for the mean difference, and it drops tied pairs from
the sign test rather than splitting them.[^paired-header]

## Why it is this way

Pairing at the cell removes between-cell variance, which is the largest source of spread in a
prompt experiment, because a hard cell is hard for both arms.[^paired-header] The decision behind
that choice is recorded separately in
[The cell is the unit of analysis](../decisions/0003-the-cell-is-the-unit-of-analysis.md).

Cost is what makes the ordering matter. A sweep is arms times models times cells times repetitions,
and the third and fourth factors are the ones that look small, so `cost.py` on the previous results
directory is run and multiplied out before a large one is queued.[^eval-cost]

## What a judged metric does not establish

A metric that needs judgement goes to `judge-agy.sh`, which scores every masked response with the
Antigravity CLI and holds the reply to the experiment's `judge-schema.json`. It is read-only, and
at 5 to 66 seconds per response with one probe over two minutes it is sized for a gate rather than
for a sweep.[^judge-script]

A judged number is therefore a model's reading, while everything `score.py` computes is a property
of the text decided by a regex — free to recompute and impossible to bias.[^eval-refusals] The
harness holds a judge to a schema and records a failure as `ERROR`, but it contains no calibration
step, so nothing here establishes how far a judged number is from a human one.

## Judging a preference instead of a count

When the question is which of two responses reads better and no count captures it, `judge-pair.sh`
shows one judge the variant and the base response for the same model, cell and repetition, in both
orders, and `pairs.py` counts a repetition as a win only when both orders name the variant and a
loss only when both name the base. A disagreement between the orders is a split, reported and
dropped. The rubric and schema are two optional files in the experiment directory, the schema's only
field is the winning letter, and a row the CSV already holds is skipped, so an interrupted pass
resumes by re-running it. The Claude family has been smoke-tested; the Codex branch has never had a
reply come back.[^readme-pref] `pairs.py` runs the sign test over cells, each cell its wins minus its
losses across repetitions, and prints the repetition totals beside it as the number that is not
independent.[^pairs-doc] The decision behind the both-orders rule is
[A preference is judged pairwise in both orders](../decisions/0011-a-preference-is-judged-pairwise-in-both-orders.md).

[^eval-intro]: `scripts/eval/README.md`, opening.

[^eval-dir]: `scripts/eval/README.md`, "An experiment directory".

[^eval-inject]: `scripts/eval/README.md`, "How an arm reaches the model".

[^eval-running]: `scripts/eval/README.md`, "Running one".

[^eval-refusals]: `scripts/eval/README.md`, "What each script will not do".

[^eval-cost]: `scripts/eval/README.md`, "Cost before you start".

[^check-header]: `scripts/eval/check.sh`, header comment.

[^paired-header]: `scripts/eval/paired.py`, module docstring.

[^judge-script]: `scripts/eval/judge-agy.sh`, header comment.

[^readme-pref]: `scripts/eval/README.md`, "Judging a preference instead of a count".

[^pairs-doc]: `scripts/eval/pairs.py`, module docstring.
