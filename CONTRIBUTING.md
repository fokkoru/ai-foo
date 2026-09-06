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
├── scripts/             # Scripts two or more skills share (optional)
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

Steps 6 and 7 are the Codex half, and a plugin that bundles no skills skips both — Codex plugins can carry only skills, so a manifest for one would point `skills` at a directory that does not exist. `plugins/style/` is the worked example: output styles are a Claude Code concept, so it is registered in `.claude-plugin/marketplace.json` and nowhere else.

The split that is easy to get backwards: `version` lives in the Codex manifest (`.codex-plugin/plugin.json`) and in the Claude marketplace entry, never in `.claude-plugin/plugin.json`.

## Adding a Command or Agent

**New workflow surface:** Create a skill at `plugins/df/skills/<name>/SKILL.md`. df ships no slash commands — `commands/` is empty and stays that way. A manual-only skill also needs `agents/openai.yaml` with `allow_implicit_invocation: false`; an auto-triggering skill has no `agents/` directory.

**New agent:** Create _both_ `plugins/df/agents/<name>.md` and its mirror `plugins/df/codex/agents/<name>.toml`. The drift check compares the name sets first, so an `.md` without its `.toml` fails immediately. Add it to the agent table in `plugins/df/README.md`, and — if a skill spawns it — to the `<agent_selection>` table in all three of `research`, `planning`, `iterate`.

After adding, bump the plugin version (MINOR for new features).

## Referencing a Bundled File from a Skill

A skill reaches its own `scripts/` and `references/` by a path relative to the skill's directory, and never by an absolute path or an environment variable. Both runtimes tell the skill where it is, by different means: Claude Code prepends `Base directory for this skill: <path>` to the body, and Codex wraps the body in a `<skill>` fragment carrying a `<path>` element with the absolute path to `SKILL.md`. Observed on Claude Code 2.1.261 and codex-cli 0.153.4. A relative path is the one form both resolve.

Spell that out in the skill body once, the way `kb`'s does — name the directory the harness announces, say what hangs off it rather than off `PATH` or the working directory, and resolve every such path at the first step. `kb:compile` is the worked example of both shapes at once: its `references/` sit under the skill's own directory, while the checker it shares reaches out to `../../scripts/check-docs.sh`.

**A script two skills share** lives at `plugins/<name>/scripts/`, reached as `../../scripts/<script>.sh`. Ownership is the reason, not convenience: a script under one skill's directory belongs to that skill, and the second skill reaching across the tree breaks when the first is renamed. The climb out of the skill directory resolves on both runtimes for the same reason a downward path does.

## Changing a Shipped Prompt

Applies to any prose this repository ships whose effect is on how the model behaves rather than on what a script computes: an output style body, an agent body, a skill. It does not apply to anything a checker already decides — frontmatter length, tag vocabulary, agent mirror drift and docs conformance each have a script, and a behavioural experiment is the wrong instrument for a question with a mechanical answer.

What picks the rung is what the edit is expected to do, not what the diff looks like. Rewording a rule can change its scope, its strength or its exceptions, and moving one can change its salience or its precedence, so no reading of the text alone decides this.

| Rung | The edit                                                                                   | What runs                                                                                             |
| ---- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| R0   | No behavioural change is intended or claimed. Meaning, scope, strength and precedence hold | Nothing paid. The mechanical checkers in `scripts/` are the whole gate                                |
| R1   | Output is expected to change, and what changes has a mechanical proxy                      | `scripts/eval/check.sh`: two arms, one primary metric, one cell set, all three named before the run   |
| R2   | Output is expected to change and no mechanical proxy exists                                | Known negatives, then a floor check, then the sweep, then judging restricted to the cells with no key |

The author proposes the rung from the edit's intent, and whoever ships the change confirms it. At R1 and R2 the confirmed rung is written into `thoughts/docs/prompt-change-log.md` before the run, together with the baseline, the candidate, the primary metric and the cells, all fixed in writing while the numbers are still unknown. Reading a second metric afterwards is a new question, not a second chance at the first one.

Price the rung before queueing it. Run `python3 scripts/eval/cost.py` on the previous results directory and multiply its median by arms × models × cells × repetitions. No rung has a fixed price, because the cells decide it. All arms run on one Claude Code version and the writeup records it, since scores from either side of a version change are not comparable.

`scripts/eval/README.md` is the runbook, and it defines arm, cell and repetition.

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

**A commit that removes a capability names its replacement in the body**, or states that there is none. This applies to a named step, a workflow trigger, an agent dispatch, a documented behaviour — anything a user could have relied on. The subject line describes the change the commit is _for_; a removal that rides along under it leaves no record anywhere, which is how three summer regressions reached `main` (`docs/decisions/0004-a-removal-names-its-replacement.md`). A removal is also never `refactor` — if behaviour changed, the type is `feat` or `fix`.
