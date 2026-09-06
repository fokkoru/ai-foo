---
type: decision
title: "Anchors"
description: "A page whose intra-page links exercise the slug rule."
status: stable
decision_id: "a2a2a2a2a2a2"
supersedes: ""
superseded_by: ""
---

# Anchors

- [Live](#the-rule)
- [Punctuation](#okf-v02-pinned)
- [Code span](#the-sources-block)
- [Duplicate](#the-rule-1)
- [Dead](#no-such-heading)

## Context

A fenced example is not a link:

```markdown
[Not a link](#never-checked)
```

## The rule

An anchor resolves against the target file's heading slugs.

## OKF v0.2, pinned

Punctuation is dropped, not hyphenated.

## The `sources[]` block

A code span keeps its text and loses only its backticks.

## The rule

The repeat of a slug takes the -1 suffix GitHub appends.
