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

| Skill                 | Purpose                                                                                           |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| `df:research`         | Comprehensive codebase research with parallel sub-agents                                          |
| `df:planning`         | Create detailed implementation plans                                                              |
| `df:iterate`          | Update existing plans based on feedback                                                           |
| `df:implement`        | Execute plans phase by phase with verification (continuous or phased mode)                        |
| `df:validate`         | Verify implementation against plan, identify issues                                               |
| `df:peer-review`      | Independent two-stage (spec + quality) code review by an isolated reviewer                        |
| `df:handoff`          | Create handoff document for session transfer                                                      |
| `df:commit`           | Commit changes in logical chunks (auto-triggers on commit intent; also invocable as `/df:commit`) |

| Agent                     | Purpose                                       |
| ------------------------- | --------------------------------------------- |
| `codebase-locator`        | Find files by topic/feature                   |
| `codebase-analyzer`       | Understand implementation details             |
| `codebase-pattern-finder` | Find similar patterns and examples            |
| `thoughts-locator`        | Discover documents in thoughts/ directory     |
| `thoughts-analyzer`       | Extract insights from thought documents       |
| `web-search-researcher`   | Research modern web information               |
| `code-reviewer`           | Independent, isolated two-stage code reviewer |

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

> `plugins/df/.claude-plugin/plugin.json` must NOT carry a `version` (it would override the marketplace version for this relative-path plugin). The **Codex** manifest (`plugins/df/.codex-plugin/plugin.json`) is the opposite: it *must* carry the version. `.agents/plugins/marketplace.json` uses `"ref": "main"` and carries no version — nothing to bump there.

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
