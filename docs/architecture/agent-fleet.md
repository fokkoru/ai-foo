---
type: architecture
title: "Agent fleet and its tiers"
description: "The nine subagents df ships, and how each one's model and effort are pinned together in frontmatter."
status: stable
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
sources:
  - resource: "plugins/df/agents/codebase-locator.md"
    id: "locator-frontmatter"
    fragment: "L1-L7"
    sha256: "14f02113f2e9"
  - resource: "plugins/df/agents/codebase-analyzer.md"
    id: "analyzer-frontmatter"
    fragment: "L1-L7"
    sha256: "aec3045de004"
  - resource: "plugins/df/agents/finding-verifier.md"
    id: "verifier-frontmatter"
    fragment: "L1-L7"
    sha256: "c9ec183c79cd"
  - resource: "plugins/df/README.md"
    id: "agent-table"
    fragment: "## Subagents"
    sha256: "a776d1b2f6cf"
  - resource: "CLAUDE.md"
    id: "tiering-gotcha"
    fragment: "## Gotchas"
    sha256: "0e90536983a8"
---

# Agent fleet and its tiers

## What it does

df ships nine subagents. Each one names a model and an effort level in its own frontmatter, and the
two move together — there is no agent with a model and no effort, and none with neither.

| Tier  | Model    | Effort   | Agents                                                                                                       |
| ----- | -------- | -------- | ------------------------------------------------------------------------------------------------------------ |
| Find  | `haiku`  | `low`    | `codebase-locator`, `thoughts-locator`                                                                       |
| Read  | `sonnet` | `medium` | `codebase-analyzer`, `codebase-pattern-finder`, `thoughts-analyzer`, `web-search-researcher`, `voice-prober` |
| Judge | `opus`   | `high`   | `code-reviewer`, `finding-verifier`                                                                          |

Find is cheap, reading is mid, judging is strong.[^locator-frontmatter][^analyzer-frontmatter][^verifier-frontmatter]

## How it works

Every agent declares its tools explicitly, and the shapes are narrow. A locator gets
`Grep, Glob, LS` and cannot read a file.[^locator-frontmatter] An analyzer adds
`Read`.[^analyzer-frontmatter] Both reviewers get `Read, Grep, Glob, LS` and nothing that
writes.[^verifier-frontmatter]

The readme's agent table is the single copy of what each one is for.[^agent-table] On the second
runtime the same bodies live as TOML mirrors that carry no model, so the tier there comes from the
user's own configuration rather than from the agent file.[^tiering-gotcha]

## Why it is this way

The tier is a property of the step, not of the agent, and the fleet encodes that by giving each
agent exactly one job. The counter-example is in the fleet's own history: the agent whose job was
"implement a phase" never carried a model, because its tier genuinely varied with how complete the
plan text was, and it was removed rather than pinned. An agent that cannot name its tier is a sign
the job is too broad. [inferred]

Effort is pinned in frontmatter beside the model rather than chosen per dispatch, because the
harness reads `effort:` only from there.[^tiering-gotcha] Which tier a step earns, and why judging
never moves down, is in
[Model tiering for dispatched work](../decisions/0002-model-tiering-for-dispatched-work.md).

[^locator-frontmatter]: `plugins/df/agents/codebase-locator.md`, frontmatter.

[^analyzer-frontmatter]: `plugins/df/agents/codebase-analyzer.md`, frontmatter.

[^verifier-frontmatter]: `plugins/df/agents/finding-verifier.md`, frontmatter.

[^agent-table]: `plugins/df/README.md`, Subagents.

[^tiering-gotcha]: `CLAUDE.md`, Gotchas.
