---
type: schema
title: "Knowledge Base Schema"
description: "What this knowledge base contains, how a page earns its place in it, and which rules a compiler must follow."
template_version: "1"
---

# Knowledge Base Schema

This file is the schema for the knowledge base under `docs/`. It is written for a person, and it is also the document `kb:compile` treats as authoritative: where this file and the skill disagree, this file wins.

## Contents

- [Editing this file is expected](#editing-this-file-is-expected)
- [OKF v0.2, pinned](#okf-v02-pinned)
- [A key is carried only when something reads it](#a-key-is-carried-only-when-something-reads-it)
- [The four directories](#the-four-directories)
- [The routing test](#the-routing-test)
- [What adopted means](#what-adopted-means)
- [Source trust order](#source-trust-order)
- [Confidence vocabulary](#confidence-vocabulary)
- [Provenance](#provenance)
- [index.md and log.md](#indexmd-and-logmd)

## Editing this file is expected

This is a starting point, not a contract. A project that outgrows the four directories, the routing test, or the confidence vocabulary edits this file, and nothing complains — no drift check compares it against the copy the plugin ships.

`template_version` is how a later release tells you the shipped template has moved on. It reports; it never gates. Your edits stay.

## OKF v0.2, pinned

The bundle conforms to the Open Knowledge Format, version 0.2. Re-evaluate at the next OKF release rather than tracking drafts.

Conformance costs a `type:` key on every page and two reserved filenames, `index.md` and `log.md`. That is the whole surface. Everything else below is this project's convention, and a consumer that ignores all of it still reads the bundle.

## A key is carried only when something reads it

OKF §11 requires nothing beyond `type` and makes every optional family independently cherry-pickable. A key nobody reads is maintenance with no return, so this schema carries a key only when a human reader or `check-docs.sh` consumes it.

Three keys are absent on purpose:

| Key           | Why it is not here                                                                                                                                                   |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tags`        | Nothing reads it. Search reads the body                                                                                                                              |
| `stale_after` | It guesses a date at write time. `sources[].sha256` measures whether the source actually changed, which is the question the guess stood in for                       |
| `verified`    | It records a confirmation event, which is a different act from generation. `kb:compile` never performs one, so the key would always be a claim about work nobody did |

Adding one back is allowed. Name what reads it first.

## The four directories

| Directory       | Holds                             | `type` value   |
| --------------- | --------------------------------- | -------------- |
| `architecture/` | How the system works, and why     | `architecture` |
| `product/`      | Behaviour, concepts, capabilities | `product`      |
| `decisions/`    | ADR-shaped records, numbered      | `decision`     |
| `roadmap/`      | Direction and planned work        | `roadmap`      |

## The routing test

Route a claim by what it is, not by which document it arrived in. One source often produces pages in more than one directory.

| The claim is                                                                        | It goes to                    | With                                                                              |
| ----------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------- |
| A statement about current behaviour, verified at a `file:line`                      | `architecture/` or `product/` | a `sources[]` entry                                                               |
| A rule in effect, evidenced in code or in `CLAUDE.md`, `CONTRIBUTING.md`, or config | `decisions/`                  | `status: stable`                                                                  |
| Anything else, including any plan whose change is not present in the code           | `roadmap/`                    | `status: draft`                                                                   |
| A decision that a later one replaced                                                | both pages                    | the old page `status: deprecated` plus `superseded_by`, the new page `supersedes` |

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

| Marker       | Means                                              |
| ------------ | -------------------------------------------------- |
| _(none)_     | Verified. Requires a `sources[]` entry             |
| `[reported]` | A secondary source says so                         |
| `[inferred]` | Deduced rather than stated                         |
| `[unknown]`  | The question is open; the answer is a literal TODO |

The vocabulary is closed. A marker sits inline, immediately after the claim it qualifies.

## Provenance

Every page records what it was built from. A `sources[]` entry names a resource, a fragment of it, and a hash of that fragment, so `check-docs.sh` can tell you later that the ground moved.

```yaml
sources:
  - resource: "thoughts/research/2026-08-02_1531_code-reviewer-dispatch-and-tiering.md"
    id: "cr-tiering"
    fragment: "## Summary"
    sha256: "3f9a1c2d4e5b"
  - resource: "plugins/df/agents/code-reviewer.md"
    id: "cr-frontmatter"
    fragment: "L1-L8"
    sha256: "b71e0d94a2cf"
```

Cite a claim in the body by footnote label. OKF §5.1 makes that label the join key — a consumer resolves attribution through the matching `sources[].id`, not by reading the footnote prose:

```markdown
The reviewer defaults to opus.[^cr-frontmatter]
```

`fragment` takes one of three forms:

| Form              | Selects                                                                              |
| ----------------- | ------------------------------------------------------------------------------------ |
| `(whole)`         | The whole file, with any leading frontmatter block removed                           |
| A heading line    | That heading through the line before the next heading at the same or shallower level |
| `L<start>-L<end>` | That inclusive line span — the form for code and anything else with no headings      |

The hash is the first 12 hex characters of the `sha256` of the fragment, after stripping trailing whitespace from every line and dropping leading and trailing blank lines. A reformat that changes nothing therefore reads as no change.

When a `resource` no longer exists, add `retired: true` to that entry rather than deleting it. The page keeps the record of where its claim came from.

## index.md and log.md

Both filenames are reserved by OKF, and both are exempt from the rule that every page declares a `type`.

**`index.md`** is a directory's table of contents. The one at the bundle root carries frontmatter of exactly one key, `okf_version`; every `index.md` below it carries none at all. Entries follow §8's shape, with the description taken from the linked page's own frontmatter:

```markdown
- [Routing](routing.md) - how a request reaches its handler
```

**`log.md`** is the bundle's history. No frontmatter, an H1, then `## YYYY-MM-DD` sections newest first. Each section holds bullets labelled `**Update**`, `**Creation**`, or `**Deprecation**` — the three §9 names, as a convention rather than a requirement — linking the pages they affected.

`check-docs.sh` enforces two rules beyond the spec: every relative `.md` link resolves, and every page is reachable from the bundle-root `index.md` (`log.md` and this file are exempt). OKF §6 and §11 both say a consumer must tolerate broken links, so a bundle failing either rule is still conformant. They stay because the most common compiler failure is writing a page and forgetting to link it, and a producer may hold itself to more than a consumer may demand.
