---
type: decision
title: "Retired"
description: "A page whose cited resource is gone and whose entry is marked retired."
status: stable
decision_id: "r1r1r1r1r1r1"
supersedes: ""
superseded_by: ""
sources:
  - resource: "scripts/fixtures/does-not-exist.md"
    id: "gone"
    fragment: "(whole)"
    sha256: "000000000000"
    retired: true
---

# Retired

## Context

The cited file does not exist. Before this change the `retired` flag silenced the report.[^gone]

## Decision

A vanished source reports whatever the entry is marked.

[^gone]: `scripts/fixtures/does-not-exist.md`, whole file.
