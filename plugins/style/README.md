# style — output styles

`style` ships output styles. An output style replaces the "how to talk" half of Claude Code's system prompt, so it changes the shape of every response in the session rather than adding a step you invoke.

## The styles

| Style          | Appears as           | What it does                                                                                                                        |
| -------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `answer-first` | `style:Answer First` | Main point first, brief plain sentences with the AI tells cut, no reprinting of what the tool result showed, status on its own line |

This table is the single copy; `README.md` at the repository root links here rather than repeating it.

Claude Code namespaces a plugin's output styles as `<plugin>:<name>`, and the name comes from the file's frontmatter, not its filename. So `answer-first.md` — whose frontmatter reads `name: Answer First` — is selected as `style:Answer First`.

Claude Code ships a built-in `Concise` style that covers part of the same ground: lead with the result, skip preamble. `answer-first` goes further — it names what the reader cannot see, forbids reprinting a tool result, and puts status on its own line. Both cut length, and they cut it the same way: out of what you leave out, never out of the grammar of what stays. Pick one. Output styles are mutually exclusive, so selecting `answer-first` means `Concise` is not loaded at all, which is why this file states the brevity rules itself instead of leaning on them.

## Where the brevity and format rules came from

The brevity rules, the carve-out for text that must survive intact, and the closing precedence line come from Anthropic's own prompts. [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) records that the effort parameter changes how much the model thinks rather than how much it says, so response length has to be prompted for explicitly; it supplies the sample instructions this style adapts for conversational length, for narration during a task, and for the length of a document written to disk. The built-in `Concise` style, read out of the Claude Code 2.1.251 binary, supplied the other two — both rewritten here. Naming exempt categories the way `Concise` does ("failing test output keeps its full content") licenses pasting a whole transcript, so this style names the information that must survive instead. And an unscoped "these rules win" would let presentation override a format the user explicitly asked for, so the closing line overrides general defaults only.

One more line from the same page decided the file's form: "The formatting style used in your prompt may influence Claude's response style." This style asks for complete sentences and flowing prose, so it is written that way. A rule set that demands prose while writing in numbered fragments teaches the wrong thing by example, which is why this file did not adopt the numbered shape `Concise` and `Proactive` use.

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

**What this means for `answer-first`.** Under lean, the base prompt says almost nothing about how to talk, so the style is the only thing shaping prose — which is what it was rewritten to do. Under the full prompt it lands on top of a tone section that also asks for short, concise responses. The two agree on length and differ on where it comes from: the style takes it out of what you leave out and keeps the grammar of what stays. It is injected after those sections, and its closing paragraph says so in as many words.

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
