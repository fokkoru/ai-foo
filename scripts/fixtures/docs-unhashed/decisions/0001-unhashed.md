---
type: decision
title: "Unhashed"
description: "A page whose sources entry declares no sha256."
status: stable
decision_id: "u1u1u1u1u1u1"
supersedes: ""
superseded_by: ""
sources:
  - resource: "scripts/fixtures/docs-decisions/decisions/0001-alpha.md"
    id: "fixture-page"
    fragment: "(whole)"
---

# Unhashed

## Context

The cited resource exists and the fragment resolves. Only the hash is absent.[^fixture-page]

## Decision

An entry with no recorded hash is reported rather than skipped.

[^fixture-page]: `scripts/fixtures/docs-decisions/decisions/0001-alpha.md`, whole file.
