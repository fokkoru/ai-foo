---
title: "The knowledge compiler"
description: "How kb turns an untracked corpus of notes into the committed pages under docs/, and what keeps the two layers from writing over each other."
status: stable
generated:
  by: "kb:weave"
  at: "2026-09-06T00:14:51-07:00"
---

# The knowledge compiler

## What it does

`kb` has two layers. The raw corpus under `thoughts/` is input and is never written to; the compiled
layer under `docs/` is output, committed, and shaped by Open Knowledge Format v0.2, whose page layout
and footnote-as-join-key it follows. The compiler's own state — the schema, and a fingerprint and a
provenance row per compiled page — lives in `.kb/`, hidden and tracked alongside `docs/`.[^kb-two-layers]

Two skills move material between them. `kb:capture` records a decision a session reached into
`thoughts/captures/` and fires on its own; `kb:weave` compiles the raw corpus into `docs/` and never
fires on its own. A third, `kb:lint`, moves nothing between the layers: it inspects the compiled
layer on its own account and repairs what has a demonstrated failure and an oracle, and it never
fires on its own either.[^kb-skill-table]

Routing is decided by the current code rather than by the genre of the note a claim arrived in. A
claim about present behaviour reaches a fact page only once the compiler located it at a live
`file:line`.[^kb-two-layers]

## How it works

`check-docs.sh` is the mechanical half. It ships eighteen modes covering conformance, reachability,
provenance, raw-source immutability, capture-record format, decision identifiers, the run claim,
supersession edges, the single ledger of what a run consumed from the raw layer, and the page
fingerprint and provenance ledgers under `.kb/`. Each exits 0 on success and 1 on any failure,
printing one `RULE(subject): detail` line per failure.[^checker-modes]

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

What a run consumed is written to one tab-separated ledger, `.kb/consumed.tsv`: a row per capture
decision, carrying the record path, the decision heading, a hash of the record's content and the
state, and a row per note the run read. The ledger is tracked and committed alongside the pages it
describes.[^checker-receipt]

`kb:lint` works over the union of two sets: `M`, the candidates `check-docs.sh check` reports and
notes across `docs/`, and `H`, whichever pages the invocation names. Eleven of `check`'s rules have a
verdict built for them — seven that fail the run, among them a missing source, a drifted fragment, an
unreachable page and a footnote no provenance row joins, and four that only note, among them an open
marker, an unused source and a page edited by hand. A finding under any other rule still enters `M`,
but goes to the report as undetermined. Naming a page authorises inspection on suspicion alone, which
is the only intake for a claim that misread evidence that never moved.[^lint-candidates]

For each candidate, one pass attaches evidence — a `file:line`, a conflicting line on another page,
or the checker record that raised it — and a finding with none attached is dropped before a second
pass ever sees it. That second pass settles each finding as one of six things: the page is wrong
and gets a named correction; the claim still holds but its citation moved, so the page's complete
citation set is restaged with the fragment that now carries the evidence and the prose is left
untouched; the page was edited by hand and still holds, so its fingerprint is advanced only after
every citation on it has been re-read; the page was renamed, recognised by a fingerprint match and
never inferred from a title; the page is right and the finding is dismissed, written nowhere; or the
answer cannot be settled from the repository, and it is reported and left for the next
run.[^lint-verdicts]

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
and half deferred and marking the whole file done would lose the deferred half. Capture rows and note
rows share one file so a run has one ledger to write rather than two, and it is tracked so that
reverting a bad run reverts its bookkeeping too — an untracked ledger survives that revert and goes on
claiming things were consumed for pages that no longer exist.[^checker-receipt]

The capture record's content hash is stored in the ledger rather than recomputed from a slug. The one
disclosed failure in this shape was a slug collision that staged hundreds of records and ingested
none, and the stored hash is also what proves the record on disk is the one that was acknowledged: a
published record is immutable, so a mismatch means somebody edited one.[^checker-receipt]

The two lint passes stay separate because a moved citation and a false claim are different
failures with different fixes. A `source-drift` record proves the cited fragment changed; it does
not prove the prose built on it is wrong, and conflating the two would either re-anchor a citation
for a page that is actually mistaken, or rewrite a page whose only fault is a stale line
number.[^lint-verdicts]

[^kb-two-layers]: `plugins/kb/README.md`, opening section.

[^kb-skill-table]: `plugins/kb/README.md`, The skills.

[^checker-modes]: `plugins/kb/scripts/check-docs.sh`, header.

[^checker-manifest]: `plugins/kb/scripts/check-docs.sh`, header, manifest note.

[^checker-claim]: `plugins/kb/scripts/check-docs.sh`, the run claim.

[^checker-receipt]: `plugins/kb/scripts/check-docs.sh`, the consumed ledger.

[^capture-claim-step]: `plugins/kb/skills/capture/SKILL.md`, Step 3.

[^capture-staging]: `plugins/kb/skills/capture/SKILL.md`, Step 2.

[^lint-candidates]: `plugins/kb/skills/lint/SKILL.md`, Step 2.

[^lint-verdicts]: `plugins/kb/skills/lint/SKILL.md`, Step 3.
