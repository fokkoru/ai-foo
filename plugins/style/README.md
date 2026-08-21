# style — output styles

`style` ships output styles. An output style replaces the "how to talk" half of Claude Code's system prompt, so it changes the shape of every response in the session rather than adding a step you invoke.

## The styles

| Style          | Appears as           | What it does                                                                          |
| -------------- | -------------------- | ------------------------------------------------------------------------------------- |
| `answer-first` | `style:Answer First` | Main point first, short plain sentences, no reprinting of what the tool result showed |

This table is the single copy; `README.md` at the repository root links here rather than repeating it.

Claude Code namespaces a plugin's output styles as `<plugin>:<name>`, and the name comes from the file's frontmatter, not its filename. So `answer-first.md` — whose frontmatter reads `name: Answer First` — is selected as `style:Answer First`.

Claude Code ships a built-in `Concise` style that covers part of the same ground: lead with the result, skip preamble. `answer-first` goes further — it names what the reader cannot see, forbids reprinting a tool result, and puts status on its own line — and it treats readability, not brevity, as the budget. Pick one; running neither is also fine.

## Claude Code only

Codex CLI has no output-style concept. It reads `AGENTS.md` and a system prompt, and neither is a per-session switchable style. So this plugin ships no `.codex-plugin/plugin.json` and has no entry in `.agents/plugins/marketplace.json` — a Codex manifest here would declare a `skills` directory that does not exist.

That makes `style` the only plugin in this repository with one runtime instead of two, and the only one whose version lives in a single place: its `.claude-plugin/marketplace.json` entry.

## Install

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install style@ai-foo
```

Then pick it under `/config` → **Output style**, in the "Model & output" group. The dedicated `/output-style` command was removed; typing it now just opens `/config`.

Choosing it there writes `outputStyle: "style:Answer First"` into `.claude/settings.local.json` — the project-local file, not the shared one. For a default the whole project gets, put the same key in `.claude/settings.json` by hand, using the full namespaced name rather than the short one.

## Precedence, and the copy you may already have

Claude Code loads output styles from five places, lowest priority first: built-in, **plugin**, `~/.claude/output-styles/`, `.claude/output-styles/` in the project, and organization policy above all. Priority only breaks ties between styles with the _same_ name, and the plugin namespace prevents that — `style:Answer First` and a personal `Answer First` are two separate entries in the picker, and both show up.

If you already keep a copy at `~/.claude/output-styles/answer-first.md`, delete it after switching. Two near-identical entries in the picker is the only thing that goes wrong, but it goes wrong every time you open the list.

## The two system-prompt modes

Claude Code assembles its system prompt in one of two shapes, and which one you get changes what the style has to carry. Verified by reading Claude Code 2.1.238; the names below are behaviours, not internal identifiers, which turn over between releases.

|                   | Lean                                                                                                                                      | Full                                                                                                                                                                           |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base rules        | one short `# Harness` block — output is markdown in a terminal, permission modes, hook output, prefer file tools, `file_path:line_number` | six sections: what the agent is, how to write text output, engineering instructions, acting carefully on irreversible things, todo-tool guidance, and a tone-and-style section |
| Guidance on prose | one sentence, about matching surrounding code                                                                                             | a full section on writing for the user between tool calls                                                                                                                      |
| Your output style | injected, always                                                                                                                          | injected, always                                                                                                                                                               |

**Lean is the default on current models.** The choice is made per model and per account, server-side, and older models get the full prompt today — but nothing about that is a promise. The one reliable control is the environment variable:

```bash
CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1   # force lean
CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0   # force the full prompt
```

This is not the `Verbose output` toggle in `/config`. That one controls how much the terminal displays and never reaches the system prompt at all, even though it sits in the same settings group.

**What this means for `answer-first`.** Under lean, the base prompt says almost nothing about how to talk, so the style is the only thing shaping prose — which is what it was rewritten to do. Under the full prompt it lands on top of a tone section that says responses should be short and concise. `answer-first` deliberately disagrees: comprehension is the budget, not word count. The style is injected after those sections and is meant to win. If you want the terse reading instead, the built-in `Concise` is it.

## Editing a style

The frontmatter keys Claude Code reads from a plugin output style — the schema is strict, so an unrecognised key fails to load rather than being ignored:

| Key                        | Effect                                                                                                                                          |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                     | The part after the `style:` prefix. Falls back to the filename                                                                                  |
| `description`              | The one line shown in the Output style picker under `/config`                                                                                   |
| `keep-coding-instructions` | `true` keeps Claude Code's own engineering instructions and adds the style on top. Omitting it drops them — the style then has to carry its own |
| `force-for-plugin`         | `true` applies the style regardless of the user's setting, and the picker can no longer switch away. Not used here, and it should stay that way |

`answer-first.md` sets `keep-coding-instructions: true`. It is a prose style, not a replacement personality, so the engineering half of the prompt has to survive it. Note that this key only does anything under the full prompt — lean drops those instructions for everyone, style or no style — which is a reason to keep it, not to remove it: it is what protects the style on the models that still get the full prompt.

Adding a style is one file in `output-styles/`. Editing either one is a version bump, same rule as `skills/` and `agents/` elsewhere in this repository.
