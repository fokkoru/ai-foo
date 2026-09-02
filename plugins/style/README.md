# style — output styles

`style` ships output styles. An output style replaces the "how to talk" half of Claude Code's system prompt, so it changes the shape of every response in the session rather than adding a step you invoke.

## The styles

| Style          | Appears as           | What it does                                                                                                               |
| -------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `answer-first` | `style:Answer First` | Front-loaded, brief responses in plain sentences that end with what the reader must do next, when anything is theirs to do |

This table is the single copy; `README.md` at the repository root links here rather than repeating it.

Claude Code namespaces a plugin's output styles as `<plugin>:<name>`, and the name comes from the file's frontmatter, not its filename. So `answer-first.md` — whose frontmatter reads `name: Answer First` — is selected as `style:Answer First`.

Claude Code ships a built-in `Concise` style that covers part of the same ground: lead with the result, skip preamble. `answer-first` goes further — it writes for a reader who did not watch the session, holds a report's length to the size of the change rather than the length of the session, and ends the message with one labelled line when something is the reader's to do. Both cut length, and they cut it the same way: out of what you leave out, never out of the grammar of what stays. Pick one. Output styles are mutually exclusive, so selecting `answer-first` means `Concise` is not loaded at all, which is why this file states the brevity rules itself instead of leaning on them.

## Where the rules came from

Three Anthropic sources supply most of the sentences, and the file quotes them rather than paraphrasing, so that where the base prompt carries the same rule the two read as a repeat and not a disagreement.

- [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) records that the effort parameter changes how much the model thinks rather than how much it says, so length has to be prompted for explicitly. Its sample conciseness instruction opens the file's second paragraph, verbatim.
- [Prompting Claude Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1) supplies the turn-updates sentence ("Before you start, say in a line what you're about to do; brief updates while you work help the user follow along"), verbatim, and the advice the rewrite followed: a brief instruction holds as well as an enumerated one, and a prompt written for an earlier model is usually too prescriptive.
- The `# Writing for the user` block that Claude Code 2.1.258 adds to its own prompt on some models (see "What the base prompt already says about prose" below) supplies the clarity and format sentences: lead with the answer, one idea per sentence with a verb, no em dashes or parentheticals or arrows, a list for parallel items, headers only in a message over about 500 words, stop when the content stops. The built-in `Concise` style from the same binary supplies "one to three sentences" for a simple question and the carve-out for text that must survive intact.

The file adds one thing none of those carry: the end state. When something is the reader's to act on, the last line is one of four labels — **Need from you**, **Blocked**, **Not verified**, **Next** — exclusive, taken in that order, and only when the condition is observable. **Next** marks an action that is the reader's, never advice; an action the model can take itself is taken instead. When nothing is open the message stops with the content, which is what the base prompt asks for too.

One line from the Opus 5 page decided the file's form: "The formatting style used in your prompt may influence Claude's response style." This style asks for prose, so it is written as prose paragraphs with no section headings, one list for the four end states, and one worked example. A rule set that demands prose while writing in numbered fragments teaches the wrong thing by example, which is why this file did not adopt the numbered shape `Concise` and `Proactive` use.

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

## What the base prompt already says about prose

Claude Code assembles its system prompt in one of two shapes, and on the lean shape a second, separately gated block decides whether the model gets prose rules of its own. Verified by reading Claude Code 2.1.258; the names below are behaviours, not internal identifiers, which turn over between releases.

|                   | Lean                                                                                                                                      | Full                                                                                                                                                                           |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base rules        | one short `# Harness` block — output is markdown in a terminal, permission modes, hook output, prefer file tools, `file_path:line_number` | six sections: what the agent is, how to write text output, engineering instructions, acting carefully on irreversible things, todo-tool guidance, and a tone-and-style section |
| Guidance on prose | one sentence about matching surrounding code, plus the writing block below when its gate is on                                            | a full section on writing for the user between tool calls                                                                                                                      |
| Your output style | injected, always                                                                                                                          | injected, always                                                                                                                                                               |

**Lean is the default on current models.** The choice is made per model and per account, server-side, and older models get the full prompt today — but nothing about that is a promise. The one reliable control is the environment variable:

```bash
CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1   # force lean
CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0   # force the full prompt
```

This is not the `Verbose output` toggle in `/config`. That one controls how much the terminal displays and never reaches the system prompt at all, even though it sits in the same settings group.

**The writing block.** On the lean prompt, 2.1.258 can add a `# Writing for the user` block of ten rules: lead with the answer, one idea per sentence, no em dashes, lists for parallel items, headers only in a message over about 500 words, stop when the content stops. Whether it appears is decided per model by a prompt-bundle attribute the server attaches to the model, and per session by the entrypoint — it is off in Slack, Teams, remote cowork and local-agent sessions — with a client-side flag and the environment variable `CLAUDE_CODE_WILLOW_TERN` able to override both. In 2.1.258 the attribute the gate reads is named for Fable 5.1, and a second, server-flagged path covers Opus 5; which models actually carry either attribute is set server-side and cannot be read from the binary. It is not keyed to the model family, so do not read the family name as the gate.

**What this means for `answer-first`.** Where the block is absent, the style is the only prose rule set in the prompt, which is why it is standalone rather than a delta on the base prompt. Where the block is present, the style is emitted _before_ it, so the base prompt's text carries recency; the style therefore repeats the base prompt's own sentences where the two overlap instead of rewording them, and adds only what the base prompt does not carry: the explicit length rule, and the end state. The closing paragraph of the style says which defaults it overrides.

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
