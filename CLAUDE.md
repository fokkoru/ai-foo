# CLAUDE.md

## Repository Purpose

This repository contains reusable Claude Code plugins that can be installed in other projects.

Procedures used occasionally — plugin structure, adding a plugin, adding a command or agent, the semver table, Codex distribution, commit types — are in `CONTRIBUTING.md`.

`AGENTS.md` is a symlink to `CLAUDE.md` — Codex CLI reads the same instructions. Don't replace it with a real file.

## Plugins

### df (plugins/df/)

Development workflow plugin providing a structured feature development cycle:

```
/df:research → /df:planning → [/df:iterate] → /df:implement → [/df:validate] → [/df:peer-review] → /df:commit → [/df:handoff]
```

Steps in brackets `[]` are optional. All workflow steps are skills, invoked explicitly as `/df:<name>` on Claude Code or `$df:<name>` on Codex CLI. `df:commit` is the only workflow step that auto-triggers on intent; the other seven are manual-only — the model cannot invoke them, so you run them yourself.

The skill and agent tables live in `plugins/df/README.md` — that is the single copy.

## Versioning

**A `df` version bump touches exactly these two fields, bumped together in one commit:**

| Location                               | Runtime     | Field                |
| -------------------------------------- | ----------- | -------------------- |
| `.claude-plugin/marketplace.json`      | Claude Code | `plugins[0].version` |
| `plugins/df/.codex-plugin/plugin.json` | Codex CLI   | `version`            |

There is no bump script — edit both fields to the same value in a single `chore(df): bump version to X.Y.Z` commit. Do not split them across commits.

No tags. The Codex catalog (`.agents/plugins/marketplace.json`) pins the `git-subdir` source to `"ref": "main"`, so Codex always tracks the latest `plugins/df` on `main` — nothing to bump there, no tag to create or push.

> `plugins/df/.claude-plugin/plugin.json` must NOT carry a `version` (it would override the marketplace version for this relative-path plugin). The **Codex** manifest (`plugins/df/.codex-plugin/plugin.json`) is the opposite: it _must_ carry the version. `.agents/plugins/marketplace.json` uses `"ref": "main"` and carries no version — nothing to bump there.

**When to update:** Any change to files in `plugins/<name>/skills/`, `plugins/<name>/agents/`, or `plugins/<name>/codex/` → bump version.

**Version bumps are always separate commits:** `chore(<plugin>): bump version to X.Y.Z`

## Authoring Style

Applies to `plugins/*/skills/`, `plugins/*/agents/`, and `.claude/` (local-only — gitignored, absent from a fresh clone). Bring a file up to this style when you edit it for another reason — don't reformat for style alone.

**Voice.** Skills are imperative and verb-first ("Read the plan", "Wait for all sub-agents") — Anthropic's `skill-creator`: "Prefer using the imperative form in instructions." Agent bodies are system prompts, so they address the agent as "you".

**Section markup.** Skills use a closed tag vocabulary: `<objective>`, `<quick_start>`, `<workflow>`, `<artifact_scope>`, `<constraints>`, `<anti_patterns>`, `<success_criteria>`. Anything else is a `###` heading inside `<workflow>` — don't mint a new tag, since tag names are how "One rule, one place" names its slots. Agents use `##` headings and no tags.

**Match the form to the failure.** Name the failure a rule fixes before wording it — the form that fixes one kind backfires on another.

| Failure    | The model…                                       | Write                                                                                                                                                                                        |
| ---------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Discipline | knows the rule, skips it under pressure          | a hard prohibition plus the specific rationalizations it must not use — the one case that earns all-caps                                                                                     |
| Shaping    | complies, but the output has the wrong shape     | a positive recipe for what the output is, part by part; a prohibition here invites negotiation and tested worse than no guidance at all (obra/superpowers, `skills/writing-skills/SKILL.md`) |
| Mechanical | emits malformed output nobody sees at write time | a formatter rule or a check in `scripts/` — never prose                                                                                                                                      |

Don't bolt nuance onto a rule that works: "don't X unless it matters" reopens the negotiation. Express a real exception as its own conditional on something observable.

**Emphasis.** Explain why a rule exists instead of shouting it — `skill-creator` calls all-caps ALWAYS/NEVER "a yellow flag". Bold marks the lead-in a scanning reader navigates by; bold inside running prose is noise. Reach for a table at three parallel dimensions (agent × purpose × when-to-use).

**Limits.** SKILL.md body under 500 lines, `description` under 1024 characters — and under 250 for an auto-triggering skill, which is where the Claude Code listing slices, enforced by `scripts/check-skill-description-length.sh` — and a reference file over 100 lines gets a table of contents. `df:commit` and `df:deslop` auto-trigger, so theirs are the only descriptions worth tuning for trigger phrases; the other seven set `disable-model-invocation: true` and are read by a human picking a command.

## Verify Before Finishing

```bash
prettier --check .                        # Prettier 3.x, global install — there is no package.json
claude plugin validate .                  # after editing either manifest; --strict is not usable, see Gotchas
scripts/check-codex-agent-drift.sh        # after editing any plugins/df/agents/*.md body or frontmatter
scripts/check-agent-selection-drift.sh    # after editing an <agent_selection> table
scripts/check-skill-description-length.sh # after editing any skill's frontmatter description
```

These check structure, and none of them can see a lost capability. So when a change removes one — a named step, a workflow trigger, an agent dispatch, a documented behaviour — the commit body names what replaces it, or says nothing does. `CONTRIBUTING.md` carries the rule; the audit that earned it is `thoughts/research/2026-08-05_0043_summer-regression-audit.md`. A skill's row in `plugins/df/README.md`'s **It's working if** table is the second place a guarantee is written down, so removing one from a skill must fail that table too.

## Gotchas

- In command/skill `.md` files, `` !`command` `` is **preprocessing** — it runs at invocation time and injects output before Claude sees the prompt. Use plain `` `command` `` in workflow instructions for commands Claude should execute itself.
- `claude plugin validate .` passes; `--strict` does not, and adopting it would cost more than it returns. Both manifests raise one warning — `version: No version specified` — and for `plugins/df/.claude-plugin/plugin.json` that absence is the deliberate invariant described under Versioning. `--strict` turns that warning into exit 1, so the strict gate and the invariant cannot both hold.
- Run `scripts/check-codex-agent-drift.sh` after editing any agent — it verifies the `plugins/df/agents/*.md` ↔ `plugins/df/codex/agents/*.toml` mirror bodies haven't drifted, and that each pair's `effort:` and `model_reasoning_effort` name the same value.
- Formatting is Prettier's job — run `prettier --write .` and gate with `prettier --check .`. `.prettierignore` excludes `plugins/df/agents/` (mirrored byte-for-byte into `.toml`, which Prettier can't reformat) and `thoughts/`. One rule Prettier can't enforce: leave a blank line before a closing section tag. Without it Prettier pulls the tag into the list above and indents it, then treats that shape as correct forever, so no later run flags it.
- Run `scripts/check-agent-selection-drift.sh` after editing the `<agent_selection>` table in any of `research`, `planning`, `iterate` — all three carry it verbatim, and they have drifted apart before (`cc3ef2c`). Three copies is the deliberate choice: only one skill loads at a time, so a shared reference file would trade inline tokens for a `Read` at equal cost.
- `sonnet` is the floor for `code-reviewer`; `effort` never moves. `effort: high` stays in both agents' frontmatter — Claude Code reads `effort:` only from there, so it is not a per-dispatch knob, and the Codex mirrors carry the same value as `model_reasoning_effort = "high"`. `finding-verifier` stays pinned at `model: opus`: a lenient refuter costs more than a lenient finder, because a missed defect can still be caught downstream but a wrongly refuted finding is gone and nothing else looks at it. `code-reviewer`'s frontmatter also keeps `model: opus`, so a caller that names nothing gets the strong tier; a caller may name `sonnet` for a narrow, task-scoped review, and that scoping is what makes it safe — no surveyed framework routes code review to a cheap model without a compensating structure. df's two callers both name nothing and so keep the `opus` default. `df:implement` dropped its `model: sonnet` when review moved from per-phase to per-wave: the justification was one phase's diff against one brief, and a wave can carry two phases, so the scoping that made the cheap tier safe stopped describing the dispatch. Naming a cheaper tier there again needs a measurement at wave width, and there is none. `phase-implementer` is the one agent that pins no model at all — it inherits the session's tier, and a dispatch names one only to deviate, never below `sonnet`. `haiku` is never valid for either agent, and that is the tier the local measurement covers: df's own haiku-tier run flagged 0 of 10 planted defects at correct severity. Weak judges' measurably higher false-negative rates under suggestive framing and spec-kitty's independent 0.35 task-fit score for haiku on code review point the same way. Read the run with its caveat — planted defects are the exact condition under which review F1 was measured to collapse 92% from synthetic samples to real PRs. The Codex mirrors pin no model, so that half comes from `~/.codex/config.toml`. Evidence: `thoughts/research/2026-08-02_1531_code-reviewer-dispatch-and-tiering.md`.
- **One rule, one place.** A behavioural rule in a skill or agent file belongs at its **point of use** — the workflow step or section where it fires — plus `<constraints>` when it is a hard gate. Restating it in a catch-all Guidelines or Key Principles section, in `<success_criteria>`, or in an agent's `## Important Guidelines` tail does not reinforce it; it creates copies that drift apart. Before removing a restatement, classify it: **duplicate** (the rule survives at an equal-or-stronger slot → delete), **orphan** (no other copy → move it to its strongest slot verbatim, never delete), **conflict** (two copies disagree → resolve, don't cut). Classify against the _post-edit_ file: two blocks being deleted together cannot cover for each other. Slot strength, strongest first: `<constraints>` and the workflow step that fires the rule > `<anti_patterns>` > `<success_criteria>` and `<quick_start>` > any catch-all guidelines section.
