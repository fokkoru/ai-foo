# Page Skeletons

Four skeletons, one per page type. Fill the placeholders and delete nothing else — every key shown is one that a reader or `check-docs.sh` consumes.

The schema behind these shapes is `schema-template.md`, which ships to `.kb/schema.md`. Where the two disagree, that file wins.

## Contents

- [Common frontmatter](#common-frontmatter)
- [Citing a source](#citing-a-source)
- [Architecture page](#architecture-page)
- [Product page](#product-page)
- [Decision page](#decision-page)
- [Roadmap page](#roadmap-page)

## Common frontmatter

Every page in the four directories opens with this block, identical across directories.

```yaml
---
title: "Human-readable display name"
description: "One sentence."
status: stable
generated:
  by: "kb:weave"
  at: "2026-08-10T11:02:33-07:00"
---
```

`status` is OKF's vocabulary — `draft`, `stable`, `deprecated` — and `stable` is the default when the key is absent. Write it anyway; the routing test in `schema-template.md` assigns it.

`type` and `sources[]` are absent because the checker reads classification from the directory and provenance from `.kb/provenance.tsv`.

Three keys are deliberately absent from every skeleton here: `tags`, `stale_after`, `verified`. Nothing reads any of them. Restoring one means naming what will.

## Citing a source

A page cites a source with a footnote: a label in the body, and a definition naming the file and the fragment.

```markdown
The reviewer defaults to opus.[^cr-frontmatter]

[^cr-frontmatter]: `plugins/df/agents/code-reviewer.md`, frontmatter.
```

That definition is prose for the reader; the hash that lets `check-docs.sh` detect drift lives in `.kb/provenance.tsv`, one row per label, written by `provenance-commit` rather than typed by hand. Stage one line per citation in the staging file it takes:

```
docs/<page>	<label>	<resource>	<L<a>-L<b> | heading | empty for whole>
```

## Architecture page

```markdown
---
title: "Wave review dispatch"
description: "How a wave is reviewed and each finding gated."
status: stable
generated:
  by: "kb:weave"
  at: "2026-08-10T11:02:33-07:00"
---

# Wave review dispatch

## What it does

The reviewer defaults to opus.[^cr-frontmatter]

## How it works

One paragraph per mechanism, each claim either backed by a footnote citation or
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
title: "Continuous mode"
description: "Phases run back to back, stopping only for a blocking manual check."
status: stable
generated:
  by: "kb:weave"
  at: "2026-08-10T11:02:33-07:00"
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
title: "Sonnet is the floor for code-reviewer"
description: "Why haiku is never a valid tier for a review dispatch."
status: stable
decision_id: "unset"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:weave"
  at: "2026-08-10T11:02:33-07:00"
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
title: "Fragment hashing as a script mode"
description: "Exposing the hash the compiler has to write."
status: draft
generated:
  by: "kb:weave"
  at: "2026-08-10T11:02:33-07:00"
---

# Fragment hashing as a script mode

## Where this stands

The three modes the script ships today do not include one.[^hash-modes]

## What it would change

## What is not decided

[^hash-modes]: `plugins/kb/scripts/check-docs.sh`, header.
```
