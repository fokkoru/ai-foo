# Contributing

Reference material for working on this repo. The rules that fire during ordinary work live in `CLAUDE.md`; this file holds the procedures you need occasionally — adding a plugin, the version bump table, Codex distribution, and commit types.

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

## Adding a Command or Agent

**New workflow surface:** Create a skill at `plugins/df/skills/<name>/SKILL.md`. df ships no slash commands — `commands/` is empty and stays that way.

**New agent:** Create _both_ `plugins/df/agents/<name>.md` and its mirror `plugins/df/codex/agents/<name>.toml`. The drift check compares the name sets first, so an `.md` without its `.toml` fails immediately. Add it to the agent table in `plugins/df/README.md`, and — if a skill spawns it — to the `<agent_selection>` table in all three of `research`, `planning`, `iterate`.

After adding, bump the plugin version (MINOR for new features).

## Versioning (semver reference)

When committing changes to a plugin, update its version in `.claude-plugin/marketplace.json` using [Semantic Versioning](https://semver.org/):

**Version format:** `MAJOR.MINOR.PATCH`

| Change Type                                           | Bump  | Example       |
| ----------------------------------------------------- | ----- | ------------- |
| Breaking changes (removed commands, changed behavior) | MAJOR | 1.0.0 → 2.0.0 |
| New features (new commands, agents, skills)           | MINOR | 1.0.0 → 1.1.0 |
| Bug fixes, docs, minor tweaks                         | PATCH | 1.0.0 → 1.0.1 |

**When to update** (the bump rule for `skills/`, `agents/`, and `codex/` is in `CLAUDE.md`):

- Changes only to README or docs → bump PATCH
- No version bump needed for changes outside plugin folders

## Codex Distribution

There is **one** canonical Codex install path: the self-hosted `.agents/plugins/marketplace.json` catalog (`codex plugin marketplace add` → `codex plugin add`) followed by the **required** `scripts/install-codex-agents.sh`. Codex plugins can bundle only skills, so all 12 subagents in `plugins/df/codex/agents/*.toml` must be copied into `~/.codex/agents/` by that script — the 10 the skills spawn plus the two advisors you invoke yourself. There is no way to deliver them via `codex plugin add`.

`scripts/sync-to-codex-plugin.sh` publishes `plugins/df/` to the official `openai/plugins` catalog. It is an **internal/parked maintainer tool**, not a user install channel — it is not advertised in the user docs, and it cannot carry subagents either.

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>`.

**Scope:** plugin name (e.g., `feat(df): add new research agent`).

| Type       | Usage              |
| ---------- | ------------------ |
| `feat`     | New feature        |
| `fix`      | Bug fix            |
| `docs`     | Documentation only |
| `refactor` | Code refactoring   |
| `chore`    | Maintenance tasks  |

**Examples:**

- `feat(df): add validate command`
- `fix(df): correct path resolution in plan command`
- `docs(df): update installation instructions`
