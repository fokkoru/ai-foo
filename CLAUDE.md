# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains reusable Claude Code plugins that can be installed in other projects.

Procedures used occasionally — plugin structure, adding a plugin, the semver table, Codex distribution, commit types — are in `CONTRIBUTING.md`.

## Architecture

```
ai-foo/
├── .agents/                    # Codex marketplace catalog (canonical install path)
├── .claude-plugin/             # Plugin marketplace registry
├── .claude/                    # Local Claude Code settings + skills (gitignored)
├── plugins/                    # Distributable Claude Code plugins
│   └── df/                     # Development flow plugin
├── scripts/                    # Drift checks and the Codex subagent installer
└── thoughts/                   # Research, plans, and docs (local-only)
```

`AGENTS.md` is a symlink to `CLAUDE.md` — Codex CLI reads the same instructions. Don't replace it with a real file.

## Plugins

### df (plugins/df/)

Development workflow plugin providing a structured feature development cycle:

```
/df:research → /df:planning → [/df:iterate] → /df:implement → [/df:validate] → [/df:peer-review] → /df:commit → [/df:handoff]
```

Steps in brackets `[]` are optional. All workflow steps are skills, invoked explicitly as `/df:<name>` on Claude Code or `$df:<name>` on Codex CLI. `df:commit` is the only workflow step that auto-triggers on intent; the other seven are manual-only — the model cannot invoke them, so you run them yourself.

The skill and agent tables live in `plugins/df/README.md` — that is the single copy.

## Versioning

**A `df` version bump touches exactly these two fields, bumped together in one commit:**

| Location                               | Runtime     | Field                |
| -------------------------------------- | ----------- | -------------------- |
| `.claude-plugin/marketplace.json`      | Claude Code | `plugins[0].version` |
| `plugins/df/.codex-plugin/plugin.json` | Codex CLI   | `version`            |

There is no bump script — edit both fields to the same value in a single `chore(df): bump version to X.Y.Z` commit. Do not split them across commits.

No tags. The Codex catalog (`.agents/plugins/marketplace.json`) pins the `git-subdir` source to `"ref": "main"`, so Codex always tracks the latest `plugins/df` on `main` — nothing to bump there, no tag to create or push.

> `plugins/df/.claude-plugin/plugin.json` must NOT carry a `version` (it would override the marketplace version for this relative-path plugin). The **Codex** manifest (`plugins/df/.codex-plugin/plugin.json`) is the opposite: it _must_ carry the version. `.agents/plugins/marketplace.json` uses `"ref": "main"` and carries no version — nothing to bump there.

**When to update:** Any change to files in `plugins/<name>/skills/`, `plugins/<name>/agents/`, or `plugins/<name>/codex/` → bump version.

**Version bumps are always separate commits:** `chore(<plugin>): bump version to X.Y.Z`

## Adding Commands/Agents

**New workflow surface:** Create a skill at `plugins/df/skills/<name>/SKILL.md`. df ships no slash commands — `commands/` is empty and stays that way.

**New agent:** Create _both_ `plugins/df/agents/<name>.md` and its mirror `plugins/df/codex/agents/<name>.toml`. The drift check compares the name sets first, so an `.md` without its `.toml` fails immediately. Add it to the agent table in `plugins/df/README.md`, and — if a skill spawns it — to the `<agent_selection>` table in all three of `research`, `planning`, `iterate`.

After adding, bump the plugin version (MINOR for new features).

## Authoring Style

Applies to `plugins/*/skills/`, `plugins/*/agents/`, and `.claude/` (local-only — gitignored, absent from a fresh clone). Bring a file up to this style when you edit it for another reason — don't reformat for style alone.

**Voice.** Skills are imperative and verb-first ("Read the plan", "Wait for all sub-agents") — Anthropic's `skill-creator`: "Prefer using the imperative form in instructions." Agent bodies are system prompts, so they address the agent as "you".

**Section markup.** Skills use a closed tag vocabulary: `<objective>`, `<quick_start>`, `<workflow>`, `<artifact_scope>`, `<constraints>`, `<anti_patterns>`, `<success_criteria>`. Anything else is a `###` heading inside `<workflow>` — don't mint a new tag, since tag names are how "One rule, one place" names its slots. Agents use `##` headings and no tags.

**Match the form to the failure.** Name the failure a rule fixes before wording it — the form that fixes one kind backfires on another.

| Failure    | The model…                                       | Write                                                                                                                                                                                        |
| ---------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Discipline | knows the rule, skips it under pressure          | a hard prohibition plus the specific rationalizations it must not use — the one case that earns all-caps                                                                                     |
| Shaping    | complies, but the output has the wrong shape     | a positive recipe for what the output is, part by part; a prohibition here invites negotiation and tested worse than no guidance at all (obra/superpowers, `skills/writing-skills/SKILL.md`) |
| Mechanical | emits malformed output nobody sees at write time | a formatter rule or a check in `scripts/` — never prose                                                                                                                                      |

Don't bolt nuance onto a rule that works: "don't X unless it matters" reopens the negotiation. Express a real exception as its own conditional on something observable.

**Emphasis.** Explain why a rule exists instead of shouting it — `skill-creator` calls all-caps ALWAYS/NEVER "a yellow flag". Bold marks the lead-in a scanning reader navigates by; bold inside running prose is noise. Reach for a table at three parallel dimensions (agent × purpose × when-to-use).

**Limits.** SKILL.md body under 500 lines, `description` under 1024 characters, a reference file over 100 lines gets a table of contents. `df:commit` and `df:deslop` auto-trigger, so theirs are the only descriptions worth tuning for trigger phrases; the other seven set `disable-model-invocation: true` and are read by a human picking a command.

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

**Scope:** plugin name (e.g., `feat(df): add new research agent`)

## Verify Before Finishing

```bash
prettier --check .                     # Prettier 3.x, global install — there is no package.json
scripts/check-codex-agent-drift.sh     # after editing any plugins/df/agents/*.md
scripts/check-agent-selection-drift.sh # after editing an <agent_selection> table
```

## Gotchas

- In command/skill `.md` files, `` !`command` `` is **preprocessing** — it runs at invocation time and injects output before Claude sees the prompt. Use plain `` `command` `` in workflow instructions for commands Claude should execute itself.
- Run `scripts/check-codex-agent-drift.sh` after editing any agent — it verifies the `plugins/df/agents/*.md` ↔ `plugins/df/codex/agents/*.toml` mirror bodies haven't drifted.
- Formatting is Prettier's job — run `prettier --write .` and gate with `prettier --check .`. `.prettierignore` excludes `plugins/df/agents/` (mirrored byte-for-byte into `.toml`, which Prettier can't reformat) and `thoughts/`. One rule Prettier can't enforce: leave a blank line before a closing section tag. Without it Prettier pulls the tag into the list above and indents it, then treats that shape as correct forever, so no later run flags it.
- Run `scripts/check-agent-selection-drift.sh` after editing the `<agent_selection>` table in any of `research`, `planning`, `iterate` — all three carry it verbatim, and they have drifted apart before (`cc3ef2c`). Three copies is the deliberate choice: only one skill loads at a time, so a shared reference file would trade inline tokens for a `Read` at equal cost.
- Never lower `code-reviewer`'s model tier (`model: opus` / `model_reasoning_effort = "high"`). A cheap reviewer doesn't merely miss defects — it argues for them: in a measured comparison, a haiku-tier reviewer flagged **0 of 10** planted defects at correct severity, praising a DRY violation as YAGNI and calling an assert-nothing test plan-compliant.
- **One rule, one place.** A behavioural rule in a skill or agent file belongs at its **point of use** — the workflow step or section where it fires — plus `<constraints>` when it is a hard gate. Restating it in a catch-all Guidelines or Key Principles section, in `<success_criteria>`, or in an agent's `## Important Guidelines` tail does not reinforce it; it creates copies that drift apart. Before removing a restatement, classify it: **duplicate** (the rule survives at an equal-or-stronger slot → delete), **orphan** (no other copy → move it to its strongest slot verbatim, never delete), **conflict** (two copies disagree → resolve, don't cut). Classify against the _post-edit_ file: two blocks being deleted together cannot cover for each other. Slot strength, strongest first: `<constraints>` and the workflow step that fires the rule > `<anti_patterns>` > `<success_criteria>` and `<quick_start>` > any catch-all guidelines section.
