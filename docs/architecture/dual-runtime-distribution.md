---
title: "Shipping one plugin tree to two runtimes"
description: "How the same plugins reach Claude Code and Codex CLI: two catalogs, two manifests, a mirrored agent set, and the one install step a Codex plugin cannot carry."
status: stable
generated:
  by: "kb:weave"
  at: "2026-09-06T00:14:51-07:00"
---

# Shipping one plugin tree to two runtimes

## What it does

`plugins/<name>/` is written once and installed by both Claude Code and Codex CLI. Each runtime reads
its own catalog and its own manifest over the same directory, so a skill body, a reference file and a
bundled script are shared rather than duplicated. [inferred]

The Codex catalog is the self-hosted `.agents/plugins/marketplace.json`, which lists four plugins and
pins every entry's `git-subdir` source at `"ref": "main"`.[^codex-catalog] There is one canonical
Codex install path: add the catalog, add the plugin, then run the required
`scripts/install-codex-agents.sh`.[^codex-distribution]

## How it works

A Codex plugin can bundle only skills. df's nine subagents therefore cannot be delivered by
`codex plugin add` at all, and the install script copies the hand-written TOML agents into
`~/.codex/agents/` instead. It runs from a local checkout or standalone, shallow-cloning the
repository when it cannot find the source directory.[^agent-install][^codex-distribution]

Each agent exists twice: `plugins/df/agents/<name>.md` for Claude Code and
`plugins/df/codex/agents/<name>.toml` for Codex. `scripts/check-codex-agent-drift.sh` enforces three
rules over the pair. The two directories must name the same set of agents, so an `.md` with no `.toml`
fails immediately. The `.toml` body must equal the `.md` body byte for byte, or that body followed by a
literal `<!-- codex-only -->` marker and a Codex-only suffix. And both sides must declare the same
effort level, the `.md` frontmatter's `effort:` matching the `.toml`'s `model_reasoning_effort`, with
the value drawn from `low|medium|high`.[^drift-rules]

That effort set is the intersection of what the two runtimes honour rather than what either accepts
alone: Claude Code also takes `max` and integers, Codex also takes `none`, `minimal` and `xhigh`, and a
value outside a runtime's set is dropped with only a debug log.[^drift-rules]

A skill reaches its own bundled files by a path relative to the skill's directory, never by an absolute
path or an environment variable. Both runtimes announce that directory by different means — Claude Code
prepends `Base directory for this skill: <path>` to the body, Codex wraps the body in a `<skill>`
fragment carrying a `<path>` element — and a relative path is the one form both resolve. Observed on
Claude Code 2.1.261 and codex-cli 0.153.4.[^bundled-file-reference]

## Why it is this way

Body extraction in the drift check is anchored on the exact line `developer_instructions = """` rather
than on the first triple quote in the file, because several `.toml` files carry a multi-line
`description` field above it. Effort extraction is anchored at column 0 and stops at the body, because
two agents quote `model_reasoning_effort` again inside their prose as a Codex call
example.[^drift-extraction]

A script shared by two skills lives at `plugins/<name>/scripts/` and is reached as
`../../scripts/<script>.sh`. Ownership decides this rather than convenience: a script under one skill's
directory belongs to that skill, and the second skill reaching across the tree breaks when the first is
renamed. The climb out of the skill directory resolves on both runtimes for the same reason a downward
path does.[^bundled-file-reference]

`scripts/sync-to-codex-plugin.sh` publishes `plugins/df/` to the official Codex catalog. It is an
internal maintainer tool rather than a user install channel, it is not advertised in the user docs, and
it cannot carry subagents either.[^codex-distribution]

[^codex-distribution]: `CONTRIBUTING.md`, Codex Distribution.

[^bundled-file-reference]: `CONTRIBUTING.md`, Referencing a Bundled File from a Skill.

[^agent-install]: `scripts/install-codex-agents.sh`, header.

[^drift-rules]: `scripts/check-codex-agent-drift.sh`, the pairing, body and effort rules.

[^drift-extraction]: `scripts/check-codex-agent-drift.sh`, extraction anchors.

[^codex-catalog]: `.agents/plugins/marketplace.json`.
