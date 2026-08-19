# cdx — Codex consultation bridge

`cdx` asks a current Codex model for a second opinion on a decision that has not become code yet, and checks the answer against the repository in front of you instead of repeating it. It does one job, and the boundary is the point: the subject is always a decision, never a diff.

## Requirements

The `codex` MCP server at user scope:

```bash
claude mcp add codex -s user -- codex mcp-server
```

Registered this way, the model and reasoning effort come from your `~/.codex/config.toml` rather than from the server arguments. A plugin manifest cannot declare an MCP dependency, so the skill checks for `mcp__codex__codex` first and stops with the line above rather than quietly answering from its own reasoning.

deepwiki (`mcp__deepwiki__ask_question`, `mcp__deepwiki__read_wiki_contents`) is optional. Without it, a design review skips external library validation and says so instead of guessing.

## The skill

| Skill     | What it does                                                            | When to reach for it                                     |
| --------- | ----------------------------------------------------------------------- | -------------------------------------------------------- |
| `consult` | One Codex second opinion, grounded in this repository, sized to the ask | A decision, an approach, or a whole design before coding |

This table is the single copy; `README.md` at the repository root links here rather than repeating it.

## The scope dial

`consult` sizes itself to the question rather than making you pick a command.

| Mode         | The request is                                                                 | Where it runs                               |
| ------------ | ------------------------------------------------------------------------------ | ------------------------------------------- |
| **Decision** | One decision, answerable from the files it names and their direct dependencies | The main thread, one Codex thread           |
| **Design**   | Several coupled decisions, a migration plan, or a system-level choice          | A dispatched subagent that returns a report |

Design mode exists for context, not for ceremony. Several consultation threads plus the file reads behind them are far larger than the report they produce, and the subagent is where that bulk stays. The runner carries a consultation budget — at most six replies on one thread, twelve across all of them — so a review that stops converging still returns a report naming its open questions, rather than being cut off mid-thought and returning nothing.

## What `cdx` deliberately does not do

`cdx` consults. It writes no code, and it does not review code that already exists.

Both of those belong to [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc), which bridges the same direction — Claude Code out to Codex — with a full CLI broker behind it. Send a diff to its `/codex:review` or `/codex:adversarial-review`, and an implementation task to its task commands. Duplicating either here would mean maintaining a second, worse copy of something already maintained.

## Runtimes

`cdx` installs on Claude Code and on Codex CLI. It ships no subagent definitions, so both runtimes get the same `skills/` directory and there is no separate agent-install step.

Two differences are worth knowing before the first Codex run. Codex ignores the `allowed-tools` field in a `SKILL.md`, so the per-skill pre-approval falls back to Codex's own session approval — you approve each call by hand. And Design mode dispatches a subagent, which Codex offers only when `[features] multi_agent = true` is set in `~/.codex/config.toml`; without it the skill runs the same prompt inline, and the context saving is what you lose.

## Install

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install cdx@ai-foo          # df, kb and agy do not come along
```
