---
type: decision
title: "A page cites only what a clone carries"
description: "Every sources[] entry names a tracked file; a path inside the raw root is refused, and a capture record is refused on separate grounds."
status: stable
decision_id: "bd12e77b6a2b"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:weave"
  at: "2026-09-06T00:14:51-07:00"
sources:
  - resource: "plugins/kb/scripts/check-docs.sh"
    id: "raw-citation-refusal"
    fragment: "L786-L806"
    sha256: "0524b3f6aafb"
  - resource: "plugins/kb/README.md"
    id: "kb-raw-untracked"
    fragment: "## Upgrading from 1.0.x"
    sha256: "0f3f2bc5e26c"
  - resource: "plugins/kb/skills/weave/SKILL.md"
    id: "weave-routing"
    fragment: "### Step 2: Route each claim"
    sha256: "1270ab486483"
  - resource: "plugins/kb/skills/capture/SKILL.md"
    id: "capture-not-compiled-layer"
    fragment: "L12-L12"
    sha256: "eab17e8746e9"
---

# A page cites only what a clone carries

## Context

The raw corpus the compiler reads is untracked. `thoughts/captures/` is written by `kb:capture` and
stays out of git the way the rest of `thoughts/` does.[^kb-raw-untracked] A compiled page, by
contrast, is committed and read by whoever clones the repository. A citation that crossed from one
layer to the other would name a file the reader does not have, so the claim resting on it could be
checked by nobody but its author, and the provenance check would fail for everyone else.

## Decision

Every `sources[]` entry names a file the reader's clone holds. The checker resolves both the citation
and the raw root to absolute paths before comparing, so a relative citation into an absolute raw root
is still recognised as the same tree, and reports `source-in-raw-root` for any entry inside
it.[^raw-citation-refusal]

A citation of a capture record is refused separately, as `source-is-capture`. The grounds differ: a
record is not merely untracked, it sits outside the source trust order entirely, never competing for a
page and never cited by one.[^raw-citation-refusal]

A claim whose only evidence is external is written in the page body instead, marked `[reported]` with
its URL and retrieval date on the same line, so the two rules never overlap.[^weave-routing]

## Consequences

A claim that lives only in a working note is not compiled. What the record does instead is send the
compiler to look at the code, the config and the plans;[^weave-routing] where it finds nothing, the
source fits no directory and the run names it in the report rather than forcing it into
one.[^weave-routing]

`kb:capture` is kept out of the compiled layer on its own grounds: a second writer there would bypass
routing, evidence checking, contradiction handling and page
consolidation.[^capture-not-compiled-layer] The citation rule is the mechanical half of the same
boundary, in that even a record that reached the raw layer cannot become a page's evidence.
[inferred]

Revisiting the rule would take tracking the raw corpus, which would put unreviewed session notes into
every clone and into the provenance-drift check. [inferred]

[^raw-citation-refusal]: `plugins/kb/scripts/check-docs.sh`, the citation-path checks.

[^weave-routing]: `plugins/kb/skills/weave/SKILL.md`, Step 2.

[^kb-raw-untracked]: `plugins/kb/README.md`, Upgrading from 1.0.x.

[^capture-not-compiled-layer]: `plugins/kb/skills/capture/SKILL.md`, objective.
