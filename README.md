# ai-foo

Reusable plugins for development workflows. Runs on both **Claude Code** and **Codex CLI**.

## Plugins

### df

Development workflow plugin providing a structured feature development cycle:

```
research → plan → [iterate] → implement → [validate] → commit → [handoff]
```

Steps in brackets `[]` are optional. Each step is a skill invoked explicitly (only `commit` auto-triggers on intent; the rest are manual-only):

- **Claude Code**: `/df:<name>` (e.g. `/df:research`).
- **Codex CLI**: `$df:<name>` or `$<name>` (e.g. `$df:research`). The Claude-style `/df:<name>` slash is **not** a valid Codex command.

| Skill                 | Purpose                                                                       |
| --------------------- | ----------------------------------------------------------------------------- |
| `df:research`         | Comprehensive codebase research with parallel sub-agents                      |
| `df:plan`             | Create detailed implementation plans                                          |
| `df:iterate`          | Update existing plans based on feedback                                       |
| `df:implement`        | Execute plans phase by phase with verification                                |
| `df:phased-implement` | Implement a plan one phase at a time with human review and a commit per phase |
| `df:validate`         | Verify implementation against plan, identify issues                           |
| `df:handoff`          | Create handoff document for session transfer                                  |
| `df:commit`           | Commit changes in logical chunks (Conventional Commits)                       |

## Install

### Claude Code

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install df@ai-foo
```

### Codex CLI

```bash
# 1. Add the marketplace
codex plugin marketplace add fokkoru/ai-foo

# 2. Install and enable the plugin (installs the skills)
codex plugin add df@ai-foo

# 3. REQUIRED: install subagents — Codex plugins can't bundle them, and
#    research/plan/iterate depend on them.
bash <(curl -fsSL https://raw.githubusercontent.com/fokkoru/ai-foo/main/scripts/install-codex-agents.sh)
# …or, from a local clone:  bash scripts/install-codex-agents.sh
```

Step 3 is **required**, not optional: Codex plugins can only bundle skills, so the 6 subagents that `research`/`plan`/`iterate` spawn must be copied into `~/.codex/agents/` separately. The script does that (and reminds you to enable `web_search` for `web-search-researcher`).

As a **dev-only** shortcut, opening the repo directly with `cd ai-foo && codex` auto-discovers the marketplace from `.agents/plugins/marketplace.json` — no `codex plugin marketplace add` needed, only the plugin-enable line in `~/.codex/config.toml`. The subagent step (3) is still required even on this path.

After install you have:

- **Skills**: `commit`, `research`, `plan`, `implement`, `phased-implement`, `validate`, `iterate`, `handoff`. Only `commit` auto-triggers on natural-language matches against its `description`; the other seven are manual-only (`disable-model-invocation: true` on Claude Code, `allow_implicit_invocation: false` on Codex) and run only when you invoke them explicitly. Explicit invocation differs by runtime: `/df:<name>` on Claude Code, `$df:<name>` or `$<name>` on Codex CLI.
- **Subagents**: 6 read-only subagents — `codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder`, `thoughts-locator`, `thoughts-analyzer`, `web-search-researcher`. Claude Code auto-loads them; Codex CLI requires the one-time subagent install step above (step 3: `install-codex-agents.sh`). The `web-search-researcher` Codex agent additionally requires `web_search` enabled under `[tools]` in `~/.codex/config.toml`.
- **Tool gating note (Codex only)**: the `allowed-tools` declarations inside each `SKILL.md` are honored by Claude Code as a per-skill pre-approval list. Codex CLI ignores this field and falls back to session-level approval prompts — Codex users will see more "approve this tool call?" prompts than Claude users for the same skill. This is a UX difference, not a security issue.

### Naming and invocation

All df skills are plugin-namespaced. The canonical invocation forms are:

- **Claude Code**: `/df:<name>` (e.g. `/df:plan`, `/df:research`). Per the Claude Code skills docs, plugin skills use a `plugin-name:skill-name` namespace and cannot collide with personal, project, or enterprise skills of the same short name.
- **Codex CLI**: `$df:<name>` or `$<name>` (e.g. `$df:plan`). The Claude-style `/df:plan` slash is **not** a valid Codex command and will error.

The unprefixed forms `/plan`, `/research`, `/implement`, etc. are **not** provided by this plugin. If your environment binds them to something (a personal skill, a bundled command, a different plugin), that's a different artifact — invoke df's workflows via `/df:<name>` to be explicit.

### Update

```bash
# Claude Code
claude /plugin marketplace upgrade ai-foo

# Codex CLI
codex plugin marketplace upgrade ai-foo
# then re-run the subagent install if any agent body changed:
bash <(curl -fsSL https://raw.githubusercontent.com/fokkoru/ai-foo/main/scripts/install-codex-agents.sh)
```

### From a local clone

```bash
git clone https://github.com/fokkoru/ai-foo.git
claude --plugin-dir /path/to/ai-foo/plugins/df
```

### Customize paths (optional)

df writes research to `thoughts/research`, plans to `thoughts/plans`, and handoffs to `thoughts/handoffs`. If your project uses different paths, add a one-line note to your `CLAUDE.md` (or `AGENTS.md` for Codex), for example: `df: write research to docs/research and plans to docs/plans`. Claude Code and Codex CLI pick this up automatically because `CLAUDE.md` / `AGENTS.md` is always in context — no env vars or skill edits needed.

See [plugins/df/README.md](plugins/df/README.md) for detailed usage.
