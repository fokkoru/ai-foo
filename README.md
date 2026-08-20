# ai-foo

Reusable plugins for development workflows. Four of them run on both **Claude Code** and **Codex CLI**; `style` is Claude Code only, because output styles have no Codex equivalent.

## Plugins

Five independent plugins live here — installing one does not install the others.

### df

Development workflow plugin providing a structured feature development cycle:

```
research → planning → [iterate] → implement → [validate] → [peer-review] → commit → [handoff]
```

Steps in brackets `[]` are optional. Each step is a skill invoked explicitly (`commit` is the only workflow step that auto-triggers on intent; the rest are manual-only):

- **Claude Code**: `/df:<name>` (e.g. `/df:research`).
- **Codex CLI**: `$df:<name>` or `$<name>` (e.g. `$df:research`). The Claude-style `/df:<name>` slash is **not** a valid Codex command.

| Skill            | Purpose                                                                                                   |
| ---------------- | --------------------------------------------------------------------------------------------------------- |
| `df:research`    | Comprehensive codebase research with parallel sub-agents                                                  |
| `df:planning`    | Create detailed implementation plans                                                                      |
| `df:iterate`     | Update existing plans based on feedback                                                                   |
| `df:implement`   | Execute plans phase by phase with verification (continuous or phased mode)                                |
| `df:validate`    | Verify implementation against plan, identify issues                                                       |
| `df:peer-review` | Independent code review by an isolated reviewer — one pass, spec + quality                                |
| `df:handoff`     | Create handoff document for session transfer                                                              |
| `df:commit`      | Commit changes in logical chunks (Conventional Commits)                                                   |
| `df:deslop`      | Revise outbound prose against a sample of your own writing (not a workflow step; auto-triggers on intent) |

### kb

Knowledge base compiler. One skill, `kb:compile`, reads markdown under `thoughts/` and writes a committed knowledge base under `docs/`. `kb` reads what `df` writes but requires none of it.

- **Claude Code**: `/kb:compile`.
- **Codex CLI**: `$kb:compile`.

See [plugins/kb/README.md](plugins/kb/README.md) for the skill table and detailed usage.

### agy

Bridges Claude Code and Codex CLI to Google's Antigravity CLI (`agy` binary). It does two jobs: `agy:consult` asks `agy` one scoped question for a networked second opinion, and `agy:delegate` hands an already-decided implementation to `agy` so the edits happen outside Claude's context. Requires the `agy` binary on `PATH`, authenticated.

See [plugins/agy/README.md](plugins/agy/README.md) for the skill table and detailed usage.

### cdx

Bridges Claude Code and Codex CLI to a current Codex model for second opinions. One skill, `cdx:consult`, asks Codex about a decision that has not become code yet and checks the answer against this repository. It sizes itself to the ask: one decision is settled in the main thread, a whole solution design goes to a subagent that returns a validation report. Requires the `codex` MCP server at user scope; deepwiki is optional.

It consults and nothing else. Reviewing code that already exists, and handing implementation work over, belong to [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc).

See [plugins/cdx/README.md](plugins/cdx/README.md) for the skill table and detailed usage.

### style

Output styles. An output style replaces the "how to talk" half of Claude Code's system prompt, so it reshapes every response in the session instead of adding a step you invoke. One style ships: `answer-first`, which puts the main point first, keeps sentences short and plain, and stops the model reprinting file contents and command output the tool result already showed.

It appears in the `/output-style` picker as `style:Answer First` — plugin output styles are namespaced, and the name comes from the file's frontmatter rather than its filename.

**Claude Code only.** Codex CLI has no output-style concept, so there is no `$style:` anything and no Codex install path.

See [plugins/style/README.md](plugins/style/README.md) for the style table and the frontmatter keys.

## Install

### df

#### Claude Code

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install df@ai-foo
```

#### Codex CLI

```bash
# 1. Add the marketplace
codex plugin marketplace add fokkoru/ai-foo

# 2. Install and enable the plugin (installs the skills)
codex plugin add df@ai-foo

# 3. REQUIRED: install subagents — Codex plugins can't bundle them, and
#    research/planning/iterate depend on them.
bash <(curl -fsSL https://raw.githubusercontent.com/fokkoru/ai-foo/main/scripts/install-codex-agents.sh)
# …or, from a local clone:  bash scripts/install-codex-agents.sh
```

Step 3 is **required**, not optional: Codex plugins can only bundle skills, so the 8 subagents that `research`/`planning`/`iterate`/`peer-review` spawn must be copied into `~/.codex/agents/` separately. The script copies all nine — those 8 plus `voice-prober`, which `deslop` and `commit` spawn (and it reminds you to enable `web_search` for `web-search-researcher`).

As a **dev-only** shortcut, opening the repo directly with `cd ai-foo && codex` auto-discovers the marketplace from `.agents/plugins/marketplace.json` — no `codex plugin marketplace add` needed, only the plugin-enable line in `~/.codex/config.toml`. The subagent step (3) is still required even on this path.

After install you have:

- **Skills**: `commit`, `deslop`, `research`, `planning`, `implement`, `validate`, `peer-review`, `iterate`, `handoff`. `commit` and `deslop` auto-trigger on natural-language matches against their `description`; the other seven are manual-only (`disable-model-invocation: true` on Claude Code, `allow_implicit_invocation: false` on Codex) and run only when you invoke them explicitly. Explicit invocation differs by runtime: `/df:<name>` on Claude Code, `$df:<name>` or `$<name>` on Codex CLI.
- **Subagents**: 9 read-only subagents — `codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder`, `thoughts-locator`, `thoughts-analyzer`, `web-search-researcher`, `code-reviewer`, `finding-verifier`, `voice-prober`. Claude Code auto-loads them; Codex CLI requires the one-time subagent install step above (step 3: `install-codex-agents.sh`). The `web-search-researcher` Codex agent additionally requires `web_search` enabled under `[tools]` in `~/.codex/config.toml`; no subagent here needs an MCP server (see [External dependencies](plugins/df/README.md#external-dependencies)).
- **Tool gating note (Codex only)**: the `allowed-tools` declarations inside each `SKILL.md` are honored by Claude Code as a per-skill pre-approval list. Codex CLI ignores this field and falls back to session-level approval prompts — Codex users will see more "approve this tool call?" prompts than Claude users for the same skill. This is a UX difference, not a security issue.

#### Naming and invocation

All df skills are plugin-namespaced. The canonical invocation forms are:

- **Claude Code**: `/df:<name>` (e.g. `/df:planning`, `/df:research`). Per the Claude Code skills docs, plugin skills use a `plugin-name:skill-name` namespace and cannot collide with personal, project, or enterprise skills of the same short name.
- **Codex CLI**: `$df:<name>` or `$<name>` (e.g. `$df:planning`). The Claude-style `/df:planning` slash is **not** a valid Codex command and will error.

The unprefixed forms `/research`, `/implement`, etc. are **not** provided by this plugin. If your environment binds them to something (a personal skill, a bundled command, a different plugin), that's a different artifact — invoke df's workflows via `/df:<name>` to be explicit.

#### Update

```bash
# Claude Code
claude /plugin marketplace upgrade ai-foo

# Codex CLI
codex plugin marketplace upgrade ai-foo
# then re-run the subagent install if any agent body changed:
bash <(curl -fsSL https://raw.githubusercontent.com/fokkoru/ai-foo/main/scripts/install-codex-agents.sh)
```

#### From a local clone

```bash
git clone https://github.com/fokkoru/ai-foo.git
claude --plugin-dir /path/to/ai-foo/plugins/df
```

#### Customize paths (optional)

df writes research to `thoughts/research`, plans to `thoughts/plans`, and handoffs to `thoughts/handoffs`. If your project uses different paths, add a one-line note to your `CLAUDE.md` (or `AGENTS.md` for Codex), for example: `df: write research to docs/research and plans to docs/plans`. Claude Code and Codex CLI pick this up automatically because `CLAUDE.md` / `AGENTS.md` is always in context — no env vars or skill edits needed.

See [plugins/df/README.md](plugins/df/README.md) for detailed usage.

### kb

#### Claude Code

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install kb@ai-foo
```

#### Codex CLI

```bash
codex plugin marketplace add fokkoru/ai-foo
codex plugin add kb@ai-foo
```

Two steps, and there is no third: `kb` ships no subagents, so nothing needs installing separately — the visible difference from df's install path above.

See [plugins/kb/README.md](plugins/kb/README.md) for detailed usage.

### agy

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install agy@ai-foo
```

#### Codex CLI

```bash
codex plugin marketplace add fokkoru/ai-foo
codex plugin add agy@ai-foo
```

There is no subagent step — `agy` ships only skills. Codex ignores `allowed-tools`, so `consult` costs one approval prompt per `agy` call instead of a per-skill pre-approval, and `delegate` needs `[features] multi_agent = true` in `~/.codex/config.toml` to dispatch a subagent rather than run inline.

See [plugins/agy/README.md](plugins/agy/README.md) for detailed usage.

### cdx

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install cdx@ai-foo
```

#### Codex CLI

```bash
codex plugin marketplace add fokkoru/ai-foo
codex plugin add cdx@ai-foo
```

There is no subagent step — `cdx` ships only skills. Codex ignores `allowed-tools`, so each Codex MCP call costs an approval prompt instead of a per-skill pre-approval, and a Design-mode consultation needs `[features] multi_agent = true` in `~/.codex/config.toml` to dispatch a subagent rather than run inline.

See [plugins/cdx/README.md](plugins/cdx/README.md) for detailed usage.

### style

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install style@ai-foo
```

Then run `/output-style` and pick **style:Answer First**. That writes `outputStyle: "style:Answer First"` into your `settings.json`; set it there by hand to make it a project-wide default, using the full namespaced name.

There is no Codex CLI block here, and that is the visible difference from every other plugin above.

See [plugins/style/README.md](plugins/style/README.md) for detailed usage.
