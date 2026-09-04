---
type: decision
title: "The cell is the unit of analysis"
description: "A prompt experiment is read paired at the fixed task rather than pooled over responses, and every reading is reported per pair."
status: stable
supersedes: ""
superseded_by: ""
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
sources:
  - resource: "scripts/eval/paired.py"
    id: "paired-doc"
    fragment: "L1-L28"
    sha256: "9ea39616fa2d"
---

# The cell is the unit of analysis

## Context

Between-cell variance is the largest source of spread in a prompt experiment, because a hard cell is
hard under every arm. Pooling responses across cells leaves that variance inside the number, where
pairing at the cell removes it.[^paired-doc]

## Decision

Each model-and-cell pair contributes one number: the median of one arm's repetitions minus the
median of the other's. The verdict is read from those pairs and never from a pooled
mean.[^paired-doc]

Three readings are reported together, and no one of them decides alone: the per-pair differences, so
a single dominating cell is visible rather than hidden inside a mean; an exact two-sided sign test
over the pairs, which assumes only that a difference is as likely to fall either way under the null;
and a bootstrap 95% interval for the mean difference, resampled over pairs.[^paired-doc]

## Consequences

A binary metric gets a noise floor before it gets a verdict. The harness prints `1/sqrt(n·R)`, the
half-width the vendor's own eval health checklist gives as the floor for a pass-rate, and prints it
only where it applies, because it is a reference point for a proportion and says nothing about a
continuous metric.[^paired-doc]

Arm names are matched against the underscored form the results directory uses, so the name with a
space and the name with an underscore both work.[^paired-doc] The mechanics around this reading are
in [Prompt A/B harness](../architecture/prompt-eval-harness.md).

[^paired-doc]: `scripts/eval/paired.py`, module docstring.
