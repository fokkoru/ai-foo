# style — output styles

`style` ships output styles. An output style replaces the "how to talk" half of Claude Code's system prompt, so it changes the shape of every response in the session rather than adding a step you invoke.

## The styles

| Style          | Appears as           | What it does                                                                          |
| -------------- | -------------------- | ------------------------------------------------------------------------------------- |
| `answer-first` | `style:Answer First` | Main point first, short plain sentences, no reprinting of what the tool result showed |

This table is the single copy; `README.md` at the repository root links here rather than repeating it.

Claude Code namespaces a plugin's output styles as `<plugin>:<name>`, and the name comes from the file's frontmatter, not its filename. So `answer-first.md` — whose frontmatter reads `name: Answer First` — is selected as `style:Answer First`.

## Claude Code only

Codex CLI has no output-style concept. It reads `AGENTS.md` and a system prompt, and neither is a per-session switchable style. So this plugin ships no `.codex-plugin/plugin.json` and has no entry in `.agents/plugins/marketplace.json` — a Codex manifest here would declare a `skills` directory that does not exist.

That makes `style` the only plugin in this repository with one runtime instead of two, and the only one whose version lives in a single place: its `.claude-plugin/marketplace.json` entry.

## Install

```bash
claude /plugin marketplace add fokkoru/ai-foo
claude /plugin install style@ai-foo
```

Then pick it:

```
/output-style
```

Choosing it writes `outputStyle: "style:Answer First"` into your `settings.json`. Set it there by hand for a project-wide default — the full namespaced name, not the short one.

## Precedence, and the copy you may already have

Claude Code loads output styles from five places, lowest priority first: built-in, **plugin**, `~/.claude/output-styles/`, `.claude/output-styles/` in the project, and organization policy above all. Priority only breaks ties between styles with the _same_ name, and the plugin namespace prevents that — `style:Answer First` and a personal `Answer First` are two separate entries in the `/output-style` list, and both show up.

If you already keep a copy at `~/.claude/output-styles/answer-first.md`, delete it after switching. Two near-identical entries in the picker is the only thing that goes wrong, but it goes wrong every time you open the list.

## Editing a style

The frontmatter keys Claude Code reads from a plugin output style:

| Key                        | Effect                                                                                                                                               |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                     | The part after the `style:` prefix. Falls back to the filename                                                                                       |
| `description`              | The one line shown in the `/output-style` picker                                                                                                     |
| `keep-coding-instructions` | `true` keeps Claude Code's own engineering instructions and adds the style on top. Omitting it drops them — the style then has to carry its own      |
| `force-for-plugin`         | `true` applies the style regardless of the user's setting, and `/output-style` can no longer switch away. Not used here, and it should stay that way |

`answer-first.md` sets `keep-coding-instructions: true`. It is a prose style, not a replacement personality, so the engineering half of the prompt has to survive it.

Adding a style is one file in `output-styles/`. Editing either one is a version bump, same rule as `skills/` and `agents/` elsewhere in this repository.
