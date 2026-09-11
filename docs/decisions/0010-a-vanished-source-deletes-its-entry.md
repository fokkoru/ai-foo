---
type: decision
title: "A vanished source deletes its entry"
description: "A sources[] entry whose resource no longer exists is removed together with the prose it supported, never flagged and kept."
status: stable
decision_id: "9b21a6273acb"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:weave"
  at: "2026-09-06T14:38:34-07:00"
sources:
  - resource: "plugins/kb/scripts/check-docs.sh"
    id: "source-missing-report"
    fragment: "L767-L784"
    sha256: "0544e2607722"
  - resource: "docs/WIKI.md"
    id: "vanished-source-rule"
    fragment: "## Provenance"
    sha256: "ba48d301c096"
---

# A vanished source deletes its entry

## Context

A `sources[]` entry used to carry `retired: true` for a resource that no longer exists, so the page
kept a record of where its claim came from without the checker reporting it as broken. The flag
silenced `source-missing` before the checker even read `resource`, so a page whose cited file was
deleted passed conformance the moment the entry was marked retired.

## Decision

`check_sources` reports `source-missing` for a missing or absent `resource` unconditionally — no
flag suppresses it.[^source-missing-report] The corresponding rule for a compiler: when a `resource`
no longer exists, delete the `sources[]` entry together with the prose it supported, and record the
deletion in `log.md`.[^vanished-source-rule]

## Consequences

A claim whose evidence is gone is not a claim the page can still make, so there is no state between
"cited" and "gone" for an entry to sit in. The page's own history is git's to keep — reverting the
commit that deleted the prose recovers it, the same as any other edit — so nothing is lost that the
frontmatter was keeping.[^vanished-source-rule]

[^source-missing-report]: `plugins/kb/scripts/check-docs.sh`, the source-missing report.

[^vanished-source-rule]: `docs/WIKI.md`, Provenance.
