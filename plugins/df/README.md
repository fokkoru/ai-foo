# df

Development flow — workflow automation for individual developers. Runs on both Claude Code and Codex CLI.

## Overview

This plugin provides a structured workflow for feature development:

```
research → plan → [iterate] → implement → [validate] → commit → [handoff]
```

Steps in brackets `[]` are optional. Each step is a skill that auto-triggers on intent, and is also reachable via explicit invocation:

- **Claude Code**: `/df:<name>` (e.g. `/df:research`).
- **Codex CLI**: `$df:<name>` or `$<name>` (e.g. `$df:research`). The Claude-style `/df:<name>` slash is **not** a valid Codex command.

**Naming**: skills are namespaced as `df:<name>` on Claude Code (`/df:plan`) and on Codex CLI (`$df:plan` or `$<name>`). Always use the namespaced form — the unprefixed `/plan`, `/research`, etc. are not provided by this plugin and may resolve to something else (a personal skill, a bundled command, another plugin) in your environment.

## Skills

All workflow surfaces are skills (no slash commands). They auto-trigger on description matches in both runtimes.

| Skill                 | Description                                                                                    |
| --------------------- | ---------------------------------------------------------------------------------------------- |
| `df:research`         | Comprehensive codebase research with parallel sub-agents                                       |
| `df:plan`             | Create detailed implementation plans with thorough research                                    |
| `df:iterate`          | Update existing plans based on feedback                                                        |
| `df:implement`        | Execute plans with verification and phase-by-phase progress                                    |
| `df:phased-implement` | Implement a plan one phase at a time with human review and a commit per phase                  |
| `df:validate`         | Verify implementation against plan, identify issues                                            |
| `df:handoff`          | Create handoff document for session transfer                                                   |
| `df:commit`           | Commit changes in logical chunks (full Conventional Commits 1.0.0 spec incl. breaking changes) |

## Subagents

| Agent                     | Description                               |
| ------------------------- | ----------------------------------------- |
| `codebase-locator`        | Find files by topic/feature               |
| `codebase-analyzer`       | Understand implementation details         |
| `codebase-pattern-finder` | Find similar patterns and examples        |
| `thoughts-locator`        | Discover documents in thoughts/ directory |
| `thoughts-analyzer`       | Extract insights from thought documents   |
| `web-search-researcher`   | Research modern web information           |

**Claude Code**: Subagents are auto-discovered from `plugins/df/agents/*.md` when the plugin is installed.

**Codex CLI**: Codex plugins cannot bundle subagents; the canonical TOML versions live at `plugins/df/codex/agents/*.toml`. After installing the plugin, copy them into `~/.codex/agents/` once:

```bash
git clone --depth 1 https://github.com/fokkoru/ai-foo /tmp/ai-foo
mkdir -p ~/.codex/agents
cp /tmp/ai-foo/plugins/df/codex/agents/*.toml ~/.codex/agents/
```

The `web-search-researcher` Codex agent additionally requires `web_search` enabled in `~/.codex/config.toml` under `[tools]`.

## Customize paths (optional)

Skills use these default paths:

- Research documents: `thoughts/research`
- Implementation plans: `thoughts/plans`
- Handoffs: `thoughts/handoffs`

To override, add a one-line note to your project's `CLAUDE.md` (or `AGENTS.md` for Codex), for example: `df: write plans to docs/plans`. Claude Code and Codex CLI pick this up automatically because `CLAUDE.md` / `AGENTS.md` is always in context — no env vars or skill edits needed.

## Installation

See the root [`README.md`](../../README.md) of `fokkoru/ai-foo` for canonical install instructions for both Claude Code and Codex CLI.

Brief recap:

- **Claude Code** loads the plugin from `plugins/df/` automatically once the marketplace has been registered against `fokkoru/ai-foo` (see the root README for the exact command).
- **Codex CLI** auto-discovers the marketplace at `.agents/plugins/marketplace.json`; enable the plugin with `[plugins."df@ai-foo"] enabled = true` in `~/.codex/config.toml`, then perform the one-time subagent copy step above.

### As Project-Local Files (Claude Code only)

Copy skills and agents directly into your project's `.claude/` directory:

```bash
cp -r df/skills your-project/.claude/skills/df
cp -r df/agents your-project/.claude/agents
```

Note: Project-local installation embeds the skills and agents in your repository. Plugin installation keeps them external.

## Tool gating differences

The `allowed-tools` declarations inside each `SKILL.md` are honored by Claude Code as a per-skill pre-approval list. Codex CLI ignores this field and falls back to session-level approval prompts — Codex users will see more "approve this tool call?" prompts than Claude users for the same skill. This is a UX difference, not a security issue.

## Usage Examples

### Research the codebase

```
> How does authentication work in this project?  (auto-triggers df:research)
```

### Create an implementation plan

```
> I need to add rate limiting to the API  (auto-triggers df:plan)
```

### Execute a plan

```
/df:implement thoughts/plans/2024-01-15_rate-limiting.md     # Claude
$df:implement thoughts/plans/2024-01-15_rate-limiting.md     # Codex
```

### Commit changes

```
> commit these changes  (auto-triggers df:commit)
```

## Workflow

1. **Research**: Understand the codebase and existing patterns
2. **Plan**: Create a detailed, phased implementation plan
3. **Iterate**: Adjust the plan based on findings
4. **Implement**: Execute the plan phase by phase with verification
5. **Validate**: Verify implementation against plan, identify issues
6. **Commit**: Create logical, well-organized commits
