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
/df:research → /df:plan → [/df:iterate] → /df:implement → [/df:validate] → /df:commit
```

Commands in brackets `[]` are optional.

| Command         | Purpose                                                  |
| --------------- | -------------------------------------------------------- |
| `/df:research`  | Comprehensive codebase research with parallel sub-agents |
| `/df:plan`      | Create detailed implementation plans                     |
| `/df:iterate`   | Update existing plans based on feedback                  |
| `/df:implement` | Execute plans phase by phase with verification           |
| `/df:validate`  | Verify implementation against plan, identify issues      |
| `/df:commit`    | Commit changes in logical chunks (Conventional Commits)  |

| Agent                     | Purpose                                   |
| ------------------------- | ----------------------------------------- |
| `codebase-locator`        | Find files by topic/feature               |
| `codebase-analyzer`       | Understand implementation details         |
| `codebase-pattern-finder` | Find similar patterns and examples        |
| `thoughts-locator`        | Discover documents in thoughts/ directory |
| `thoughts-analyzer`       | Extract insights from thought documents   |
| `web-search-researcher`   | Research modern web information           |

**Install in another project:**

```bash
claude --plugin-dir /path/to/ai-foo/plugins/df
```

**Configure paths** using environment variables (optional):

```bash
export DF_RESEARCH_DIR=custom/research
export DF_PLANS_DIR=custom/plans
```

Defaults: `thoughts/research` and `thoughts/plans`.

## Versioning

When committing changes to a plugin, update its version in `.claude-plugin/marketplace.json` using [Semantic Versioning](https://semver.org/):

**Version format:** `MAJOR.MINOR.PATCH`

| Change Type                                           | Bump  | Example       |
| ----------------------------------------------------- | ----- | ------------- |
| Breaking changes (removed commands, changed behavior) | MAJOR | 1.0.0 → 2.0.0 |
| New features (new commands, agents, skills)           | MINOR | 1.0.0 → 1.1.0 |
| Bug fixes, docs, minor tweaks                         | PATCH | 1.0.0 → 1.0.1 |

**Files to update:**

1. `plugins/<name>/.claude-plugin/plugin.json` — update `"version"` field
2. `.claude-plugin/marketplace.json` — update `"version"` in the plugin entry

**When to update:**

- Any change to files in `plugins/<name>/commands/` or `plugins/<name>/agents/` → bump version
- Changes only to README or docs → bump PATCH
- No version bump needed for changes outside plugin folders

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
     "version": "1.0.0",
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

## Claude Code Documentation (Source of Truth)

**Concepts:**

- [How Claude Code Works](https://code.claude.com/docs/en/how-claude-code-works)
- [Features Overview](https://code.claude.com/docs/en/features-overview)
- [Memory](https://code.claude.com/docs/en/memory)
- [Best Practices](https://code.claude.com/docs/en/best-practices)
- [Common Workflows](https://code.claude.com/docs/en/common-workflows)

**Extensibility:**

- [Skills](https://code.claude.com/docs/en/skills)
- [Sub-agents](https://code.claude.com/docs/en/sub-agents)
- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Plugins](https://code.claude.com/docs/en/plugins)
- [Discover Plugins](https://code.claude.com/docs/en/discover-plugins)
- [MCP](https://code.claude.com/docs/en/mcp)
- [Output Styles](https://code.claude.com/docs/en/output-styles)
- [Headless Mode](https://code.claude.com/docs/en/headless)

**Reference:**

- [CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [Settings](https://code.claude.com/docs/en/settings)
- [Hooks](https://code.claude.com/docs/en/hooks)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Troubleshooting](https://code.claude.com/docs/en/troubleshooting)
