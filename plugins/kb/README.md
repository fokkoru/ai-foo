# kb — Knowledge Base

`kb` compiles the raw notes a project accumulates — research, plans, handoffs, loose markdown — into a durable knowledge base that lives in the repository and is reviewed like code.

The raw corpus under `thoughts/` is the input and is never written to. The compiled layer under `docs/` is the output: committed, readable by a person, and conformant to [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog) v0.2, so its schema is adopted rather than invented. Every compiled page records where each claim came from, together with a hash of the exact fragment it was built from, so drift between a page and its source is something a script reports rather than something you discover by reading.

Routing is decided by the current code, not by the genre of the note it came from. A claim about how the system behaves today reaches a fact page only when the compiler verified it against a live `file:line`. Everything else — a recommendation, an option, a plan whose change is not in the code — lands in the roadmap marked as a proposal.

## Requires no other plugin

`kb` is installable and usable on its own. It depends on no other plugin's skills, subagents, or artifacts, and it reads `thoughts/` as plain markdown — frontmatter is an optional fast path, never a requirement, so a corpus of hand-written notes compiles as readily as a generated one.

## The skills

| Skill        | Description                                                                    |
| ------------ | ------------------------------------------------------------------------------ |
| `kb:weave`   | Weave the raw corpus under `thoughts/` into a knowledge base in `docs/`        |
| `kb:capture` | Record a decision the session reached into `thoughts/captures/`, as it happens |

`kb:capture` fires on its own when a session reaches a decision. `kb:weave` never does — invoke it yourself:

- **Claude Code**: `/kb:weave`
- **Codex CLI**: `$kb:weave`

The compiler leaves its output uncommitted in the working tree. Read the diff, then commit it however you normally would — by hand, or with `df:commit` if you happen to have that plugin installed.

### It's working if

What the skill guarantees, stated so you can check it from your own working copy and the run in front of you — no need to open a `SKILL.md`. A run that does not produce its row is a bug worth reporting, and a change that removes a row has to say so here first.

| Skill        | You know it worked when                                                                                                                                                     |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kb:capture` | a file appeared under `thoughts/captures/` naming the decision, the alternative you rejected and the reason, and `docs/` did not change                                     |
| `kb:weave`   | `docs/` changed and `thoughts/` did not — the run reports a source-hash verification, and a second document on a topic updated an existing page instead of adding a sibling |

## Customize paths (optional)

The skill uses these default paths:

- Raw corpus it reads: `thoughts/`
- Knowledge base it writes: `docs/`

To override either, add a one-line note to your project's `CLAUDE.md` (or `AGENTS.md` for Codex), for example: `kb: read notes from notes/ and write the knowledge base to wiki/`. Claude Code and Codex CLI pick this up automatically because `CLAUDE.md` / `AGENTS.md` is always in context — no env vars or skill edits needed.

## Upgrading from 1.0.x

`kb:compile` is gone and `kb:weave` replaces it. Type the new name; there is no alias.

Three edits the skill will not make for you. A project already running `kb` has to make them by hand, because they are changes to your schema and your own pages, and the skill may rewrite neither:

1. **The new routing row.** `docs/WIKI.md` gains a row for a rule that no longer holds whose replacement was never built: it goes to the old decision page as `status: deprecated` with no `superseded_by`, and the replacement is not compiled. Without the row there is nowhere for that case to land.
2. **An identifier on every existing decision page**, plus the line in your decision page template. Run `check-docs.sh assign-id <page>` on each page under `docs/decisions/` and write the value into a `decision_id` key. Until you do, `check-docs.sh check` reports every one of them.
3. **The two mentions of the old skill name in `docs/WIKI.md` prose.** Generator identity in page frontmatter stays on the old name: a renamed producer did not retroactively produce those pages.

`thoughts/captures/` is written by `kb:capture` and stays untracked. Keep it out of git the way you keep the rest of `thoughts/` out.

## Installation

### Claude Code

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install kb@ai-foo
```

### Codex CLI

```bash
codex plugin marketplace add fokkoru/ai-foo
codex plugin add kb@ai-foo
```

Two steps, and there is no third: `kb` ships no subagents, so nothing needs installing separately.

Opening a clone directly with `cd ai-foo && codex` auto-discovers the marketplace from `.agents/plugins/marketplace.json`, which is a convenience for working on the plugin itself rather than an install path.
