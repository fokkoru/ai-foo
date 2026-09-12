---
title: "A version bump touches two manifests and no tag"
description: "A plugin's version lives in its marketplace entry and its Codex manifest, bumped to the same value in one commit; the Codex catalog tracks main, so there is nothing to tag."
status: stable
decision_id: "1ffb5b5f2f4a"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:weave"
  at: "2026-09-06T00:14:51-07:00"
---

# A version bump touches two manifests and no tag

## Context

Each plugin is installed by two runtimes that read different files. Claude Code reads the plugin's
entry in `.claude-plugin/marketplace.json`; Codex CLI reads `plugins/<name>/.codex-plugin/plugin.json`.
A version recorded in one and not the other reports a different release to each
runtime. [inferred]

## Decision

A bump edits both fields to the same value in a single
`chore(<plugin>): bump version to X.Y.Z` commit, and the two edits are never split across commits. A
Claude-only plugin carries only the marketplace field, so its bump touches one field. Any change under
a plugin's `skills/`, `agents/`, `codex/`, or `output-styles/` requires one.[^versioning-rule]

No plugin's `.claude-plugin/plugin.json` may carry a `version` — for a relative-path plugin it would
override the marketplace version. The Codex manifest is the opposite and must carry
one.[^versioning-rule]

There are no tags. Every entry in `.agents/plugins/marketplace.json` pins its `git-subdir` source at
`"ref": "main"`,[^catalog-ref-main] so Codex always tracks the latest `plugins/<name>` on `main` and
the catalog itself carries no version to bump.[^versioning-rule]

## Consequences

A Codex user installs whatever is on `main`, with no way to pin an older release and no tag to check
out. [inferred] The two manifests are the only places a release number exists.[^versioning-rule]

The semver table classifies the bump, and one deviation from it is recorded rather than corrected:
`kb` 1.1.0 removed `kb:compile` and shipped `kb:weave` in its place, which the table puts at MAJOR. The
owner was shown the conflict and chose MINOR, on the grounds that `kb` had no released consumer beyond
this repository and the release note tells an existing user the one thing they must retype. It is
written down so a later reader treats it as a decision rather than an error and does not reopen
it.[^semver-table]

[^versioning-rule]: `CLAUDE.md`, Versioning.

[^semver-table]: `CONTRIBUTING.md`, Versioning (semver reference).

[^catalog-ref-main]: `.agents/plugins/marketplace.json`.
