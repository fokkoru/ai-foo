# Page Skeletons

Six skeletons: the four page types, the bundle-root `index.md`, and `log.md`. Fill the placeholders and delete nothing else — every key shown is one that a reader or `check-docs.sh` consumes.

The schema behind these shapes is `wiki-template.md`, which ships to `docs/WIKI.md`. Where the two disagree, that file wins.

## Contents

- [Common frontmatter](#common-frontmatter)
- [Architecture page](#architecture-page)
- [Product page](#product-page)
- [Decision page](#decision-page)
- [Roadmap page](#roadmap-page)
- [Bundle-root index.md](#bundle-root-indexmd)
- [log.md](#logmd)

## Common frontmatter

Every page in the four directories opens with this block. `type` changes per directory; the rest is identical.

```yaml
---
type: architecture
title: "Human-readable display name"
description: "One sentence."
status: stable
generated:
  by: "kb:compile"
  at: "2026-08-10T11:02:33-07:00"
sources:
  - resource: "thoughts/research/2026-08-02_1531_code-reviewer-dispatch-and-tiering.md"
    id: "cr-tiering"
    fragment: "## Summary"
    sha256: "3f9a1c2d4e5b"
  - resource: "plugins/df/agents/code-reviewer.md"
    id: "cr-frontmatter"
    fragment: "L1-L8"
    sha256: "b71e0d94a2cf"
---
```

`status` is OKF's vocabulary — `draft`, `stable`, `deprecated` — and `stable` is the default when the key is absent. Write it anyway; the routing test in `wiki-template.md` assigns it.

Six keys are deliberately absent from every skeleton here: `tags`, `stale_after`, `verified`, and `sources[].author`, `sources[].last_modified`, `sources[].title`. Nothing reads any of them. Restoring one means naming what will.

A `sources[]` entry whose `resource` no longer exists gains `retired: true` rather than being deleted.

## Architecture page

```markdown
---
type: architecture
title: "Wave review dispatch"
description: "How a wave is reviewed and each finding gated."
status: stable
generated:
  by: "kb:compile"
  at: "2026-08-10T11:02:33-07:00"
sources:
  - resource: "plugins/df/agents/code-reviewer.md"
    id: "cr-frontmatter"
    fragment: "L1-L8"
    sha256: "b71e0d94a2cf"
---

# Wave review dispatch

## What it does

The reviewer defaults to opus.[^cr-frontmatter]

## How it works

One paragraph per mechanism, each claim either backed by a `sources[]` entry or
carrying a confidence marker.

## Why it is this way

The reasoning, and what it cost. A claim deduced rather than stated carries
`[inferred]` immediately after it.

[^cr-frontmatter]: `plugins/df/agents/code-reviewer.md`, frontmatter.
```

## Product page

The body answers what the thing does for whoever uses it, not how it is built.

```markdown
---
type: product
title: "Continuous mode"
description: "Phases run back to back, stopping only for a blocking manual check."
status: stable
generated:
  by: "kb:compile"
  at: "2026-08-10T11:02:33-07:00"
sources:
  - resource: "plugins/df/skills/implement/SKILL.md"
    id: "mode-selection"
    fragment: "L1-L6"
    sha256: "bd6bc015366b"
---

# Continuous mode

## What it is

Phases run back to back, stopping only for a blocking manual check.[^mode-selection]

## When it applies

## What it does not cover

[^mode-selection]: `plugins/df/skills/implement/SKILL.md`, frontmatter.
```

## Decision page

ADR-shaped, and the only skeleton carrying the two supersession keys. Filename is `NNNN-slug.md` with a zero-padded four-digit sequence — `decisions/0007-sonnet-is-the-floor.md`.

```markdown
---
type: decision
title: "Sonnet is the floor for code-reviewer"
description: "Why haiku is never a valid tier for a review dispatch."
status: stable
supersedes: ""
superseded_by: ""
generated:
  by: "kb:compile"
  at: "2026-08-10T11:02:33-07:00"
sources:
  - resource: "CLAUDE.md"
    id: "tiering-gotcha"
    fragment: "## Gotchas"
    sha256: "c40a7e18b6d3"
---

# Sonnet is the floor for code-reviewer

## Context

What was true when the decision was made, and what forced it.

## Decision

One sentence, in the present tense, stating the rule in effect.[^tiering-gotcha]

## Consequences

What this costs, what it rules out, and what would have to change for it to be
revisited.

[^tiering-gotcha]: `CLAUDE.md`, Gotchas.
```

Both keys hold a `docs/decisions/NNNN-slug.md` path or an empty string. When one decision replaces another, write both sides: the replaced page gains `status: deprecated` and points forward, the new page points back.

## Roadmap page

`status` is always `draft` here. Everything not yet present in the code lands on this page type, including a plan that has not been implemented.

```markdown
---
type: roadmap
title: "Fragment hashing as a script mode"
description: "Exposing the hash the compiler has to write."
status: draft
generated:
  by: "kb:compile"
  at: "2026-08-10T11:02:33-07:00"
sources:
  - resource: "plugins/kb/skills/compile/scripts/check-docs.sh"
    id: "hash-modes"
    fragment: "L1-L5"
    sha256: "838bb8597bef"
---

# Fragment hashing as a script mode

## Where this stands

The three modes the script ships today do not include one.[^hash-modes]

## What it would change

## What is not decided

[^hash-modes]: `plugins/kb/skills/compile/scripts/check-docs.sh`, header.
```

## Bundle-root index.md

Exactly one frontmatter key, and every entry in §8's shape with the description copied from the linked page's own frontmatter.

```markdown
---
okf_version: "0.2"
---

# Knowledge Base

- [Architecture](architecture/index.md) - how the system is put together
- [Product](product/index.md) - behaviour, concepts, capabilities
- [Decisions](decisions/index.md) - rules in effect and why
- [Roadmap](roadmap/index.md) - direction and planned work
- [Schema](WIKI.md) - what belongs here and how a page earns its place
```

An `index.md` in any subdirectory is the same shape with no frontmatter block at all.

## log.md

No frontmatter. An H1, then dated sections newest first.

```markdown
# Log

## 2026-08-10

- **Creation**: [Wave review dispatch](architecture/wave-review-dispatch.md)
- **Update**: [Continuous mode](product/continuous-mode.md) — dispatch tier corrected against current frontmatter
- **Deprecation**: [Per-phase review](decisions/0004-per-phase-review.md) — superseded by 0007

## 2026-08-01

- **Creation**: seeded the bundle
```
