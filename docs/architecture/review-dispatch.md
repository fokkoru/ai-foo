---
title: "Independent review dispatch"
description: "How df reviews a run: one pass per phase, one over the whole run, and a refuter behind every blocking finding."
status: stable
generated:
  by: "kb:compile"
  at: "2026-09-03T23:13:58-07:00"
---

# Independent review dispatch

## What it does

Every phase of a run gets one `code-reviewer` pass over that phase's diff. A run of two or more
phases gets one more, `branch-scoped`, over the whole run. Every spec gap and every Critical or
Important finding goes to a `finding-verifier` dispatched to refute it before any fix round
opens.[^impl-gates]

The reviewer receives only a path to the diff file and a path to the spec with its acceptance
criteria, never the implementation conversation.[^reviewer-frontmatter] That isolation is the point
of the pass: the controller holds the whole implementation conversation, and the pass exists to
remove exactly that non-independence.[^impl-gates]

## How it works

The two dispatches differ in scope and in nothing else. A phase pass is one phase's diff against
one phase's section.[^impl-phase-pass] The branch-scoped pass is the only one that sees how phases fit
together, and its recall on a large diff is weaker than a phase pass's on the same code, so depth
belongs to the phase passes and integration to the run pass.[^impl-run-pass]

Neither dispatch names a model.[^impl-phase-pass][^impl-run-pass] The agent's own frontmatter carries `model: opus` and
`effort: high`, so a caller that names nothing gets the strong tier.[^reviewer-frontmatter] The
reasoning is in [Model tiering for dispatched work](../decisions/0002-model-tiering-for-dispatched-work.md).

Verification is separate from finding because a reviewer assigns its own severity and nothing else
checks it.[^impl-gates] `REFUTED` clears a finding; `CONFIRMED` and `CANNOT DETERMINE` keep it
blocking.[^impl-phase-pass]

## Why it is this way

The guarantee is published where a user can check it without opening a skill file: df's readme
states that every phase ends with one reviewer pass, that a multi-phase run ends with one more, and
that each blocking finding goes to a verifier first.[^df-guarantees]

That second place exists because of a past failure. Three regressions reached the main branch as
refactors whose commit subjects described something else, which is what earned the rule that a
removal names its replacement in the commit body.[^removal-rule] The readme table gives such a
removal a second file to contradict. See
[A removal names its replacement](../decisions/0004-a-removal-names-its-replacement.md).

[^impl-gates]: `plugins/df/skills/implement/SKILL.md`, `<constraints>`.

[^impl-phase-pass]: `plugins/df/skills/implement/SKILL.md`, Step 3.5.

[^impl-run-pass]: `plugins/df/skills/implement/SKILL.md`, Step 4.5.

[^reviewer-frontmatter]: `plugins/df/agents/code-reviewer.md`, frontmatter.

[^df-guarantees]: `plugins/df/README.md`, "It's working if".

[^removal-rule]: `CONTRIBUTING.md`, commit-body rules.
