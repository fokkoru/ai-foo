---
type: architecture
title: "The knowledge compiler"
description: "How kb turns an untracked corpus of notes into the committed pages under docs/, and what keeps the two layers from writing over each other."
status: stable
generated:
  by: "kb:weave"
  at: "2026-09-06T00:14:51-07:00"
sources:
  - resource: "plugins/kb/README.md"
    id: "kb-two-layers"
    fragment: "L3-L7"
    sha256: "d9261cdbb73e"
  - resource: "plugins/kb/README.md"
    id: "kb-skill-table"
    fragment: "## The skills"
    sha256: "8b4431c3834e"
  - resource: "plugins/kb/scripts/check-docs.sh"
    id: "checker-modes"
    fragment: "L2-L26"
    sha256: "96a4ec037994"
  - resource: "plugins/kb/scripts/check-docs.sh"
    id: "checker-manifest"
    fragment: "L28-L34"
    sha256: "d95cc3e40e01"
  - resource: "plugins/kb/scripts/check-docs.sh"
    id: "checker-claim"
    fragment: "L1308-L1321"
    sha256: "24c5e1bb89e4"
  - resource: "plugins/kb/scripts/check-docs.sh"
    id: "checker-receipt"
    fragment: "L975-L995"
    sha256: "7bc17f218020"
  - resource: "plugins/kb/skills/capture/SKILL.md"
    id: "capture-claim-step"
    fragment: "### Step 3: Try the claim, and publish if it is free"
    sha256: "95e8abce3472"
  - resource: "plugins/kb/skills/capture/SKILL.md"
    id: "capture-staging"
    fragment: "### Step 2: Write the record to the staging directory"
    sha256: "fcf30c0174f1"
---

# The knowledge compiler

## What it does

`kb` has two layers. The raw corpus under `thoughts/` is input and is never written to; the compiled
layer under `docs/` is output, committed, and conformant to Open Knowledge Format v0.2, so its schema
is adopted rather than invented.[^kb-two-layers]

Two skills move material between them. `kb:capture` records a decision a session reached into
`thoughts/captures/` and fires on its own; `kb:weave` compiles the raw corpus into `docs/` and never
fires on its own.[^kb-skill-table]

Routing is decided by the current code rather than by the genre of the note a claim arrived in. A
claim about present behaviour reaches a fact page only once the compiler located it at a live
`file:line`.[^kb-two-layers]

## How it works

`check-docs.sh` is the mechanical half. It ships fourteen modes covering conformance, reachability,
provenance, raw-source immutability, capture-record format, decision identifiers, the run claim,
supersession edges, and the receipt. Each exits 0 on success and 1 on any failure, printing one
`RULE(subject): detail` line per failure.[^checker-modes]

A weave run takes a repository-local claim before it does anything else, then snapshots the raw layer.
`snapshot` hashes every raw source and prints a manifest path the caller holds; at the end of the run
`verify-sources` reads that manifest back and proves the raw layer did not move.[^checker-manifest]
The claim lives beside the git directory, so it is outside every snapshot and never reaches a commit,
and a linked worktree gets its own.[^checker-claim]

`kb:capture` runs the same primitives in the opposite direction. It writes to a staging directory
under the git directory first, outside the raw layer and outside every snapshot, so nothing exists in
`thoughts/` until publication.[^capture-staging] It then tries the claim exactly once and publishes if
it is free; a refused claim leaves the record staged and the session continues with no
delay.[^capture-claim-step]

What a run consumed is written to a tab-separated receipt, one line per decision, carrying the record
path, a hash of the record's content, the state, and the decision heading. The receipt is tracked and
committed alongside the pages it describes.[^checker-receipt]

## Why it is this way

One claim covers a whole run rather than the snapshot and the verification separately. A publisher
writing the raw layer during a live session is what makes the gap matter: a claim held only across the
two ends leaves the middle open, and the run edits the compiled layer in that middle with no staged
output and nothing to roll back.[^checker-claim]

The manifest is created fresh per snapshot and named by the caller from then on. Two runs — two
repositories, or two sessions on one repository — can share a `TMPDIR`, and a manifest at a fixed path
would let one run's snapshot stand in for the other's, producing a false failure when the two trees
differ and a false pass when they happen to share relative paths.[^checker-manifest]

Acknowledgement is per decision rather than per record, because a record is routinely half compiled
and half deferred and marking the whole file done would lose the deferred half. The receipt is
tab-separated rather than markdown so the page enumeration never sees it and it needs no exemption,
and it is tracked so that reverting a bad run reverts its bookkeeping too — an untracked receipt
survives that revert and goes on claiming captures were acknowledged for pages that no longer
exist.[^checker-receipt]

The capture record's content hash is stored in the receipt rather than recomputed from a slug. The one
disclosed failure in this shape was a slug collision that staged hundreds of records and ingested
none, and the stored hash is also what proves the record on disk is the one that was acknowledged: a
published record is immutable, so a mismatch means somebody edited one.[^checker-receipt]

[^kb-two-layers]: `plugins/kb/README.md`, opening section.

[^kb-skill-table]: `plugins/kb/README.md`, The skills.

[^checker-modes]: `plugins/kb/scripts/check-docs.sh`, header.

[^checker-manifest]: `plugins/kb/scripts/check-docs.sh`, header, manifest note.

[^checker-claim]: `plugins/kb/scripts/check-docs.sh`, the run claim.

[^checker-receipt]: `plugins/kb/scripts/check-docs.sh`, receipt.

[^capture-claim-step]: `plugins/kb/skills/capture/SKILL.md`, Step 3.

[^capture-staging]: `plugins/kb/skills/capture/SKILL.md`, Step 2.
