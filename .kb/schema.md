---
title: "Knowledge Base Schema"
description: "What this knowledge base contains, how a page earns its place in it, and which rules a compiler must follow."
template_version: "1"
map: docs/index.md
decisions: docs/decisions
---

# Knowledge Base Schema

This file is the schema for the knowledge base under `docs/`. It is written for a person, and it is also the document `kb:weave` treats as authoritative: where this file and the skill disagree, this file wins.

## Contents

- [Editing this file is expected](#editing-this-file-is-expected)
- [A key is carried only when something reads it](#a-key-is-carried-only-when-something-reads-it)
- [The map](#the-map)
- [The three directories](#the-three-directories)
- [The routing test](#the-routing-test)
- [What adopted means](#what-adopted-means)
- [Source trust order](#source-trust-order)
- [Confidence vocabulary](#confidence-vocabulary)
- [Provenance](#provenance)

## Editing this file is expected

This is a starting point, not a contract. A project that outgrows the three directories, the routing test, or the confidence vocabulary edits this file, and nothing complains — no drift check compares it against the copy the plugin ships.

`template_version` is how a later release tells you the shipped template has moved on. It reports; it never gates. Your edits stay.

## A key is carried only when something reads it

OKF §11 makes every optional family independently cherry-pickable, and its only fixed requirement — that a page's classification be knowable — is met structurally here, by which of the three directories a page lives in, not by a `type` key. A key nobody reads is maintenance with no return, so this schema carries a key only when a human reader or `check-docs.sh` consumes it.

Three keys are absent on purpose:

| Key           | Why it is not here                                                                                                                                                                                  |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tags`        | Nothing reads it. Search reads the body                                                                                                                                                             |
| `stale_after` | It guesses a date at write time. The hash `provenance-commit` computes for each `.kb/provenance.tsv` row measures whether the source actually changed, which is the question the guess stood in for |
| `verified`    | It records a confirmation event, which is a different act from generation. `kb:weave` never performs one, so the key would always be a claim about work nobody did                                  |

Adding one back is allowed. Name what reads it first.

## The map

`map: docs/index.md` names the bundle's root index — the page `check-docs.sh` walks from, following relative `.md` links, to prove every other page is reachable. `decisions: docs/decisions` names the directory that same run holds to the `decision_id` rule. Neither key names a page `kb:weave` compiled: the map is not registered in `.kb/pages.tsv`, unlike the pages it links to, because it is the owner's table of contents, not output.

Every relative `.md` link on a page must resolve to a file — `check-docs.sh` enforces this over every page under `docs/`, whether or not that page is reachable from the map.

## The three directories

| Directory       | Holds                             |
| --------------- | --------------------------------- |
| `architecture/` | How the system works, and why     |
| `product/`      | Behaviour, concepts, capabilities |
| `decisions/`    | ADR-shaped records, numbered      |

## The routing test

Route a claim by what it is, not by which document it arrived in. One source often produces pages in more than one directory.

| The claim is                                                                        | It goes to                    | With                                                                              |
| ----------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------- |
| A statement about current behaviour, verified at a `file:line`                      | `architecture/` or `product/` | a footnote definition on the page and a row in `.kb/provenance.tsv`               |
| A rule in effect, evidenced in code or in `CLAUDE.md`, `CONTRIBUTING.md`, or config | `decisions/`                  | `status: stable`                                                                  |
| Anything else, including any plan whose change is not present in the code           | not compiled                  | named in the report as a source with no home                                      |
| A decision that a later one replaced                                                | both pages                    | the old page `status: deprecated` plus `superseded_by`, the new page `supersedes` |
| A rule that no longer holds, whose replacement is not implemented                   | the old page                  | `status: deprecated` with no `superseded_by`; the replacement is not compiled     |

## What adopted means

A plan is adopted when either test passes:

1. Its frontmatter says `status: implemented`.
2. The change it describes is present in the current code.

The second test is the one that always works — plans written before the frontmatter lifecycle carry no `status` at all — and it is the one that decides when the two disagree. A plan marked `implemented` whose change is not in the code is not adopted.

## Source trust order

Used only when two sources conflict:

```
code and commits  >  an implemented plan  >  a plan  >  research  >  a note
```

The higher tier wins the page. The loser is kept as a flagged note on that page — never deleted — so the next reader sees that the disagreement existed and how it was settled.

A verified claim is never silently overwritten by a lower tier.

## Confidence vocabulary

Confidence is a property of the claim, not of the document it came from. A single research file can hold one verified claim and one guess.

| Marker       | Means                                                                                  |
| ------------ | -------------------------------------------------------------------------------------- |
| _(none)_     | Verified. Requires a footnote definition on the page and a row in `.kb/provenance.tsv` |
| `[reported]` | A secondary source says so. The line carries the URL and `retrieved YYYY-MM-DD`        |
| `[inferred]` | Deduced rather than stated                                                             |
| `[unknown]`  | The question is open; the answer is a literal TODO                                     |

The vocabulary is closed. A marker sits inline, immediately after the claim it qualifies.

## Provenance

Every page records what it was built from, but not in its own frontmatter any more. A page's citations live in `.kb/provenance.tsv`, one row per footnote label: page, label, resource, fragment, and a hash of that fragment, computed by `provenance-commit` — never typed by hand. `check-docs.sh` reads that ledger to tell you later that the ground moved.

A page itself carries only the footnote definitions its provenance rows join to:

```markdown
The reviewer defaults to opus.[^cr-frontmatter]

[^cr-frontmatter]: `plugins/df/agents/code-reviewer.md`
```

OKF §5.1 makes the label the join key — a consumer resolves attribution through the matching `.kb/provenance.tsv` row, not by reading the footnote prose.

`fragment` takes one of three forms:

| Form              | Selects                                                                              |
| ----------------- | ------------------------------------------------------------------------------------ |
| `(whole)`         | The whole file, with any leading frontmatter block removed                           |
| A heading line    | That heading through the line before the next heading at the same or shallower level |
| `L<start>-L<end>` | That inclusive line span — the form for code and anything else with no headings      |

The hash is the first 12 hex characters of the `sha256` of the fragment, after stripping trailing whitespace from every line and dropping leading and trailing blank lines. A reformat that changes nothing therefore reads as no change.

When a `resource` no longer exists, its row is dropped and the prose it supported goes with it, never flagged and kept. The page's own history is git's to keep, not the ledger's.
