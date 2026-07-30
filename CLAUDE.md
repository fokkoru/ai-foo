# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains reusable Claude Code plugins that can be installed in other projects.

## Architecture

```
ai-foo/
├── .claude/                    # Project-level agents and commands
├── .claude-plugin/             # Plugin marketplace registry
├── plugins/                    # Distributable Claude Code plugins
│   └── df/                     # Development flow plugin
└── thoughts/                   # Research, plans, and docs
```

## Plugins

### df (plugins/df/)

Development workflow plugin providing a structured feature development cycle:

```
/df:research → /df:planning → [/df:iterate] → /df:implement → [/df:validate] → [/df:peer-review] → /df:commit → [/df:handoff]
```

Steps in brackets `[]` are optional. All workflow steps are skills, invoked explicitly as `/df:<name>` on Claude Code or `$df:<name>` on Codex CLI. Only `df:commit` auto-triggers on intent; the other seven are manual-only — the model cannot invoke them, so you run them yourself.

| Skill            | Purpose                                                                                                                               |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `df:research`    | Comprehensive codebase research with parallel sub-agents                                                                              |
| `df:planning`    | Create detailed implementation plans                                                                                                  |
| `df:iterate`     | Update existing plans based on feedback                                                                                               |
| `df:implement`   | Execute plans phase by phase with verification (continuous or phased mode)                                                            |
| `df:validate`    | Verify implementation against plan, identify issues                                                                                   |
| `df:peer-review` | Independent code review by an isolated reviewer — one pass, spec + quality verdicts                                                   |
| `df:handoff`     | Create handoff document for session transfer                                                                                          |
| `df:commit`      | Commit changes in logical chunks, message length sized to the change (auto-triggers on commit intent; also invocable as `/df:commit`) |

| Agent                     | Purpose                                                  |
| ------------------------- | -------------------------------------------------------- |
| `codebase-locator`        | Find files by topic/feature                              |
| `codebase-analyzer`       | Understand implementation details                        |
| `codebase-pattern-finder` | Find similar patterns and examples                       |
| `thoughts-locator`        | Discover documents in thoughts/ directory                |
| `thoughts-analyzer`       | Extract insights from thought documents                  |
| `web-search-researcher`   | Research modern web information                          |
| `code-reviewer`           | Independent, isolated reviewer (spec + quality verdicts) |
| `codex-advisor`           | Fast second opinion from Codex on one narrow decision    |
| `architecture-advisor`    | Review a solution design before it becomes code          |

**Install in another project:**

```bash
claude --plugin-dir /path/to/ai-foo/plugins/df
```

**Customize paths (optional):** add a line to your project's CLAUDE.md, e.g. "df: write plans to docs/plans". No env vars needed.

## Versioning

When committing changes to a plugin, update its version in `.claude-plugin/marketplace.json` using [Semantic Versioning](https://semver.org/):

**Version format:** `MAJOR.MINOR.PATCH`

| Change Type                                           | Bump  | Example       |
| ----------------------------------------------------- | ----- | ------------- |
| Breaking changes (removed commands, changed behavior) | MAJOR | 1.0.0 → 2.0.0 |
| New features (new commands, agents, skills)           | MINOR | 1.0.0 → 1.1.0 |
| Bug fixes, docs, minor tweaks                         | PATCH | 1.0.0 → 1.0.1 |

**A `df` version bump touches exactly these two fields, bumped together in one commit:**

| Location                               | Runtime     | Field                |
| -------------------------------------- | ----------- | -------------------- |
| `.claude-plugin/marketplace.json`      | Claude Code | `plugins[0].version` |
| `plugins/df/.codex-plugin/plugin.json` | Codex CLI   | `version`            |

There is no bump script — edit both fields to the same value in a single `chore(df): bump version to X.Y.Z` commit. Do not split them across commits.

No tags. The Codex catalog (`.agents/plugins/marketplace.json`) pins the `git-subdir` source to `"ref": "main"`, so Codex always tracks the latest `plugins/df` on `main` — nothing to bump there, no tag to create or push.

> `plugins/df/.claude-plugin/plugin.json` must NOT carry a `version` (it would override the marketplace version for this relative-path plugin). The **Codex** manifest (`plugins/df/.codex-plugin/plugin.json`) is the opposite: it _must_ carry the version. `.agents/plugins/marketplace.json` uses `"ref": "main"` and carries no version — nothing to bump there.

**When to update:**

- Any change to files in `plugins/<name>/skills/`, `plugins/<name>/agents/`, or `plugins/<name>/codex/` → bump version
- Changes only to README or docs → bump PATCH
- No version bump needed for changes outside plugin folders

**Version bumps are always separate commits:** `chore(<plugin>): bump version to X.Y.Z`

## Codex Distribution

There is **one** canonical Codex install path: the self-hosted `.agents/plugins/marketplace.json` catalog (`codex plugin marketplace add` → `codex plugin add`) followed by the **required** `scripts/install-codex-agents.sh`. Codex plugins can bundle only skills, so the 7 subagents in `plugins/df/codex/agents/*.toml` must be copied into `~/.codex/agents/` by that script — there is no way to deliver them via `codex plugin add`.

`scripts/sync-to-codex-plugin.sh` publishes `plugins/df/` to the official `openai/plugins` catalog. It is an **internal/parked maintainer tool**, not a user install channel — it is not advertised in the user docs, and it cannot carry subagents either.

## Plugin Structure

Each plugin follows this standard structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata (required)
├── commands/            # Slash commands (optional)
│   └── command-name.md
├── agents/              # Agent definitions (optional)
│   └── agent-name.md
├── skills/              # Skill definitions (optional)
├── hooks/               # Event handlers (optional)
├── .mcp.json            # MCP server configuration (optional)
└── README.md            # Plugin documentation
```

## Adding a New Plugin

1. Create plugin directory: `plugins/<plugin-name>/`
2. Create metadata file: `plugins/<plugin-name>/.claude-plugin/plugin.json`

   ```json
   {
     "name": "<plugin-name>",
     "description": "Brief description",
     "author": { "name": "fokkoru" }
   }
   ```

3. Add commands/agents as needed
4. Create `README.md` with usage instructions
5. Register in `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<plugin-name>",
     "source": "./plugins/<plugin-name>",
     "version": "1.0.0",
     "description": "Brief description"
   }
   ```

## Adding Commands/Agents

**New command:** Create `plugins/<plugin-name>/commands/<command-name>.md`

**New agent:** Create `plugins/<plugin-name>/agents/<agent-name>.md`

After adding, bump the plugin version (MINOR for new features).

## Authoring Style

Applies to `plugins/*/skills/`, `plugins/*/agents/`, and `.claude/`. Bring a file up to this style when you edit it for another reason — don't reformat for style alone.

**Voice.** Skills are imperative and verb-first ("Read the plan", "Wait for all sub-agents") — Anthropic's `skill-creator`: "Prefer using the imperative form in instructions." Agent bodies are system prompts, so they address the agent as "you".

**Section markup.** Skills use a closed tag vocabulary: `<objective>`, `<quick_start>`, `<workflow>`, `<artifact_scope>`, `<constraints>`, `<circuit_breakers>`, `<anti_patterns>`, `<success_criteria>`. Anything else is a `###` heading inside `<workflow>` — don't mint a new tag, since tag names are how "One rule, one place" names its slots. Agents use `##` headings and no tags.

**Match the form to the failure.** Name the failure a rule fixes before wording it — the form that fixes one kind backfires on another.

| Failure    | The model…                                       | Write                                                                                                                                                                                        |
| ---------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Discipline | knows the rule, skips it under pressure          | a hard prohibition plus the specific rationalizations it must not use — the one case that earns all-caps                                                                                     |
| Shaping    | complies, but the output has the wrong shape     | a positive recipe for what the output is, part by part; a prohibition here invites negotiation and tested worse than no guidance at all (obra/superpowers, `skills/writing-skills/SKILL.md`) |
| Mechanical | emits malformed output nobody sees at write time | a formatter rule or a check in `scripts/` — never prose                                                                                                                                      |

Don't bolt nuance onto a rule that works: "don't X unless it matters" reopens the negotiation. Express a real exception as its own conditional on something observable.

**Emphasis.** Explain why a rule exists instead of shouting it — `skill-creator` calls all-caps ALWAYS/NEVER "a yellow flag". Bold marks the lead-in a scanning reader navigates by; bold inside running prose is noise. Reach for a table at three parallel dimensions (agent × purpose × when-to-use).

**Limits.** SKILL.md body under 500 lines, `description` under 1024 characters, a reference file over 100 lines gets a table of contents. Only `df:commit` auto-triggers, so it is the only description worth tuning for trigger phrases; the other seven set `disable-model-invocation: true` and are read by a human picking a command.

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

| Type       | Usage              |
| ---------- | ------------------ |
| `feat`     | New feature        |
| `fix`      | Bug fix            |
| `docs`     | Documentation only |
| `refactor` | Code refactoring   |
| `chore`    | Maintenance tasks  |

**Scope:** plugin name (e.g., `feat(df): add new research agent`)

**Examples:**

- `feat(df): add validate command`
- `fix(df): correct path resolution in plan command`
- `docs(df): update installation instructions`

## Gotchas

- In command/skill `.md` files, `` !`command` `` is **preprocessing** — it runs at invocation time and injects output before Claude sees the prompt. Use plain `` `command` `` in workflow instructions for commands Claude should execute itself.
- Run `scripts/check-codex-agent-drift.sh` after editing any agent — it verifies the `plugins/df/agents/*.md` ↔ `plugins/df/codex/agents/*.toml` mirror bodies haven't drifted.
- Formatting is Prettier's job — run `prettier --write .` and gate with `prettier --check .`. `.prettierignore` excludes `plugins/df/agents/` (mirrored byte-for-byte into `.toml`, which Prettier can't reformat) and `thoughts/`. One rule Prettier can't enforce: leave a blank line before a closing section tag. Without it Prettier pulls the tag into the list above and indents it, then treats that shape as correct forever, so no later run flags it.
- Run `scripts/check-agent-selection-drift.sh` after editing the `<agent_selection>` table in any of `research`, `planning`, `iterate` — all three carry it verbatim, and they have drifted apart before (`cc3ef2c`). Three copies is the deliberate choice: only one skill loads at a time, so a shared reference file would trade inline tokens for a `Read` at equal cost.
- Never lower `code-reviewer`'s model tier (`model: opus` / `model_reasoning_effort = "high"`). A cheap reviewer doesn't merely miss defects — it argues for them: in a measured comparison, a haiku-tier reviewer flagged **0 of 10** planted defects at correct severity, praising a DRY violation as YAGNI and calling an assert-nothing test plan-compliant.
- **One rule, one place.** A behavioural rule in a skill or agent file belongs at its **point of use** — the workflow step or section where it fires — plus `<constraints>` when it is a hard gate. Restating it in a catch-all Guidelines or Key Principles section, in `<success_criteria>`, or in an agent's `## Important Guidelines` tail does not reinforce it; it creates copies that drift apart. Before removing a restatement, classify it: **duplicate** (the rule survives at an equal-or-stronger slot → delete), **orphan** (no other copy → move it to its strongest slot verbatim, never delete), **conflict** (two copies disagree → resolve, don't cut). Classify against the _post-edit_ file: two blocks being deleted together cannot cover for each other. Slot strength, strongest first: `<constraints>` and the workflow step that fires the rule > `<circuit_breakers>` > `<anti_patterns>` > `<success_criteria>` and `<quick_start>` > any catch-all guidelines section.
