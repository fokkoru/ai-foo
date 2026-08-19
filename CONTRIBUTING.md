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

6. Create `plugins/<plugin-name>/.codex-plugin/plugin.json` for the Codex half — Codex plugins can only bundle skills, so `skills` points at the skills directory:

   ```json
   {
     "name": "<plugin-name>",
     "version": "1.0.0",
     "description": "Brief description",
     "skills": "./skills/",
     "interface": {
       "displayName": "<plugin-name>",
       "shortDescription": "Brief description",
       "longDescription": "..."
     }
   }
   ```

7. Register in `.agents/plugins/marketplace.json` using the `git-subdir` source with `"ref": "main"`:

   ```json
   {
     "name": "<plugin-name>",
     "source": {
       "source": "git-subdir",
       "url": "fokkoru/ai-foo",
       "path": "plugins/<plugin-name>",
       "ref": "main"
     },
     "policy": {
       "installation": "AVAILABLE",
       "authentication": "ON_USE"
     },
     "category": "Coding"
   }
   ```

The split that is easy to get backwards: `version` lives in the Codex manifest (`.codex-plugin/plugin.json`) and in the Claude marketplace entry, never in `.claude-plugin/plugin.json`.

## Adding a Command or Agent

**New workflow surface:** Create a skill at `plugins/df/skills/<name>/SKILL.md`. df ships no slash commands — `commands/` is empty and stays that way. A manual-only skill also needs `agents/openai.yaml` with `allow_implicit_invocation: false`; an auto-triggering skill has no `agents/` directory.

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

There is **one** canonical Codex install path: the self-hosted `.agents/plugins/marketplace.json` catalog (`codex plugin marketplace add` → `codex plugin add`) followed by the **required** `scripts/install-codex-agents.sh`. Codex plugins can bundle only skills, so all 9 subagents in `plugins/df/codex/agents/*.toml` must be copied into `~/.codex/agents/` by that script. There is no way to deliver them via `codex plugin add`.

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

**A commit that removes a capability names its replacement in the body**, or states that there is none. This applies to a named step, a workflow trigger, an agent dispatch, a documented behaviour — anything a user could have relied on. The subject line describes the change the commit is _for_; a removal that rides along under it leaves no record anywhere, which is how three summer regressions reached `main` (`thoughts/research/2026-08-05_0043_summer-regression-audit.md`). A removal is also never `refactor` — if behaviour changed, the type is `feat` or `fix`.
