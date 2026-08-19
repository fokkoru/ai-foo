# agy — Antigravity bridge

`agy` bridges Claude Code to Google's Antigravity CLI (`agy` binary). It does two jobs: hand an already-decided implementation to `agy` so the edits happen outside Claude's context, and ask `agy` one scoped question for a networked second opinion — a trade-off, a theoretical point, or a claim that needs checking against the live web.

## Requirements

`agy` on `PATH`, authenticated. The safety matrix below was measured on v1.1.14 and says nothing about any other version — re-running those probes is what moves the boundary, not reading the help text. A plugin manifest cannot declare this dependency, so both skills check `command -v agy` first and stop with a clear message rather than failing with `command not found` from the middle of a pipe.

## The skills

| Skill      | What it does                                                    | When to reach for it                                                                  |
| ---------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `consult`  | One scoped question, answered read-only, with internet access   | A trade-off, a theoretical point, or a claim that needs checking against the live web |
| `delegate` | An already-decided change, implemented outside the main context | The plan exists and only the typing remains                                           |

This table is the single copy; `README.md` at the repository root links here rather than repeating it.

## Safety

Every cell in this table comes from a live probe against `agy` v1.1.14, not from the help text, with one exception noted below it.

| Flags                            | Edit existing file | Create new file | Shell command | Write outside workspace |
| -------------------------------- | ------------------ | --------------- | ------------- | ----------------------- |
| no permission flags              | denied             | denied\*        | denied        | denied                  |
| `--mode accept-edits`            | works              | works           | denied        | denied                  |
| `--dangerously-skip-permissions` | works              | works           | works         | works                   |
| `--sandbox` + skip-permissions   | works              | works           | works         | works, via self-bypass  |

\* Not probed directly. Creating a file and editing one both go through `write_file`, and the denial landed on that tool — `permission check failed for write_file`. The cell is an inference from the same mechanism, not a separate measurement.

**Deleting a file is not a column, because it is not one of `agy`'s verbs.** The only file-mutation tool is `write_to_file`, whose `CodeContent` field is required, so no call it can make removes a path — and `accept-edits` has already closed shell, so `rm` is gone too. Three probes on v1.1.14 under that mode: once it declined in prose and returned `status: SUCCESS` with the deletion undone; twice the attempt surfaced as `error: … CodeContent is a required parameter` while the response narrated the other operations as complete, and one of those two left an `export {}` placeholder in the file it was told to remove. Nothing in the envelope names the path it failed to delete. So `delegate` refuses a task that removes or renames a path, and the caller does that part.

Three rules follow. `delegate` runs under `--mode accept-edits`. `--dangerously-skip-permissions` is not shipped. `--sandbox` is not shipped either — under `accept-edits` it adds nothing, because shell is already closed, and row 4 is what it is worth alongside skip-permissions.

`consult` ships no `Bash(agy:*)` grant, so every consultation costs one permission prompt. That is the price of the first row: Bash rules match by prefix, so a grant on `agy` would pre-approve `agy --dangerously-skip-permissions` and `agy --mode` as well, and "read-only by mechanism" would come back down to prose.

## Runtimes

`agy` installs on Claude Code and on Codex CLI. It ships no subagent definitions, so both runtimes get the same `skills/` directory and there is no separate agent-install step.

Two differences are worth knowing before the first Codex run. Codex ignores the `allowed-tools` field in a `SKILL.md`, so the per-skill pre-approval that keeps `consult` read-only on Claude Code falls back to Codex's own session approval — you approve each `agy` call by hand, which is more prompts rather than fewer. And `delegate` dispatches a subagent, which Codex offers only when `[features] multi_agent = true` is set in `~/.codex/config.toml`; without it the skill runs the same prompt inline.

## Install

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install agy@ai-foo          # df and kb do not come along
```
