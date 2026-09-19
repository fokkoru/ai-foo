---
title: "The two-line status line"
description: "How the Claude Code status line is assembled from ccstatusline's git widgets and one local script, and how to recreate it on a new machine."
status: stable
generated:
  by: "kb:lint"
  at: "2026-09-19T12:56:29-07:00"
---

# The two-line status line

## What it does

The status line has two lines and two renderers. `ccstatusline` draws the first from its own git
widgets.[^sl-why] The second is drawn whole by `statusline/statusline.mjs`, which `ccstatusline`
runs as a `custom-command` widget.[^sl-why][^sl-not-a-plugin] Which widgets sit on the first line,
and in what order, is the configuration reproduced below.

The second line reads left to right in focus order — model, context, cache, cost, then the two
rate-limit windows — with a rule between groups and, inside a group, a word beside every number
saying what it is.[^sl-why]

The script has two modes, chosen by its first argument. `run` prints the whole second line;
`worktree` prints a single mark and is placed among the first line's widgets.[^sl-dispatch]

## How it works

Claude Code hands the status line a JSON payload on stdin. `ccstatusline` passes that same payload
to each `custom-command` widget, so the script parses stdin and writes ANSI-coloured text.[^sl-why]

**Context.** The percentage measures against the point where auto-compact fires, which is not a
fraction of the window: Claude Code 2.1.278 compacts once the context reaches the window size less
two reserves, 20,000 tokens held for the summary response, or the model's output cap where that is
smaller, which no current model's is, and a fixed 13,000-token buffer. `/context`
reports their sum as `Autocompact buffer: 33k tokens`, and the percentage is used tokens over the
window less that sum. The payload carries neither reserve, so the script pins the
figure.[^sl-buffer]

**Cost.** Three figures, priced from a table of published rates. Every rate below is
[reported](https://platform.claude.com/docs/en/about-claude/pricing), retrieved 2026-09-19.

Session spend comes straight from the payload. The last-request figure prices the token split
`context_window.current_usage` reports, charging each of its four classes once at its own rate:
plain input, cache writes at the TTL multiplier, cache reads at the read multiplier, and output at
the output rate. It is an estimate at published prices, not the billed figure, and a request that
wrote at mixed TTLs is priced at the single TTL the payload reports. When the payload's `fast_mode`
is true and the model is Claude Opus 5 or Claude Opus 4.8, the last and next figures use the
fast-mode rates, $10 and $50 per million tokens in place of $5 and $25, with the cache multipliers
on that base: the pricing page sells fast mode on those two models alone, and Claude Code 2.1.278's
own cost ledger swaps to the same table. Opus 4.7 rejects fast mode and Opus 4.6 bills it at
standard rates, so the toggle changes nothing on any other model.[^sl-rates]

The next-request figure is the whole context re-sent, and it has three states. While the cache is
warm, the tokens the last response read or wrote are priced at the read multiplier, 0.1× the input
rate or 0.025× on Claude Fable 5.1 and Claude Mythos 5.1 alone, and the rest at the write
multiplier for the reported TTL: the last request's uncached input sat after the final cache
breakpoint and its output joins the context now, so both are written on the next request. What the
user types next is unknown and left out. Once the prefix has to be rebuilt, the recache size the
payload reports is priced at 1.25× on the five-minute TTL or 2× on the one-hour TTL, in red. Where no response has reported cache tokens at all it is priced at the plain
input rate, in grey, because nothing has measured the cache and a red figure would assert a cold
cache the payload does not claim. Printing nothing there was the alternative, and it is what the
cache group itself does in the same state: `renderCache` returns early unless a response has
reported cache tokens.[^sl-cache] The cost group prints the figure anyway, because a blank cost
group cannot be told apart from a widget that broke, while a grey figure says both what an uncached
request would cost and that the cache state is unknown. A cold cache whose recache size is null — the state right after a
compaction — prints `next ?` rather than substituting the last context and printing a guess as a
measurement. A model absent from the rate table prints no cost rather than a guessed
one.[^sl-rates][^sl-cost]

**Colour.** Colour encodes state, not identity. A percentage is green below 60%, amber from 60%,
red from 85% — 60% is where there is still room to act and 85% is where there is not. The cache hit
ratio is toned the other way round, since a healthy session sits high and anything under 60% means
the prefix is being rebuilt on most requests.[^sl-thresholds]

**Worktree.** The `worktree` mode prints a mark only when the current directory really is a linked
worktree. The payload answers that in either of two fields. `workspace.git_worktree` carries the
worktree's name when the session's own working directory resolves to a linked worktree's git
directory; a session the harness itself moved into a worktree carries a top-level `worktree` object
instead — name, path, branch, `original_cwd`, `original_branch` — and then `workspace.git_worktree`
is absent. The mark fires on either, because reading only the first left every worktree the harness
made unmarked. Both shapes were observed on Claude Code 2.1.269. That replaced a walk up from the
working directory reading each `.git` it found on every render, and nothing was kept behind as a
fallback for a Claude Code that predates the fields: the script has exactly one
installation,[^sl-not-a-plugin] so a second path would be a branch nothing here ever runs. The cost
of that is a behaviour, not a risk — on an older Claude Code the mark stops appearing, and nothing
else on either line changes.[^sl-worktree] The space that sets the
mark off from the path lives in a `custom-text` widget in the config, because `ccstatusline` trims
a widget's own output.[^sl-worktree]

## Why it is this way

`ccstatusline` renders the first line because its git widgets do work worth reusing. It cannot
render the second: it reads no `prompt_cache` field of the ones Claude Code sends, it paints each
widget a single colour rather than colouring by threshold, and it has no way to give one value more
visual weight than its neighbour.[^sl-why][^sl-not-a-plugin]

None of this can ship as a plugin. `PluginSettingsSchema` is
`SettingsSchema().pick({ agent: true }).strip()`, so `agent` is the only settings key a plugin may
carry, and `${CLAUDE_PLUGIN_ROOT}` is not expanded in a status line command. Distribution is
therefore a written instruction that puts an absolute path into a settings file, which is what the
next section is.[^sl-not-a-plugin]

## Installing it

Three steps, none of which a clone performs for you.

1. Install `ccstatusline` globally with npm.
2. Point Claude Code at it, in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "ccstatusline",
  "padding": 0,
  "refreshInterval": 10
}
```

3. Write `~/.config/ccstatusline/settings.json`, replacing both occurrences of the absolute path
   with this repository's checkout:

```json
{
  "version": 4,
  "lines": [
    [
      {
        "id": "cwd-1",
        "type": "current-working-dir",
        "color": "ansi256:189",
        "rawValue": true,
        "metadata": { "abbreviateHome": "true" }
      },
      {
        "id": "gap-wt",
        "type": "custom-text",
        "customText": " ",
        "merge": true,
        "metadata": { "hide": "merge-target-hidden" }
      },
      {
        "id": "wt-1",
        "type": "custom-command",
        "commandPath": "/absolute/path/to/ai-foo/statusline/statusline.mjs worktree",
        "timeout": 2000,
        "preserveColors": true
      },
      {
        "id": "sep-1",
        "type": "custom-text",
        "customText": " │ ",
        "color": "ansi256:243"
      },
      {
        "id": "branch-1",
        "type": "git-branch",
        "color": "ansi256:183",
        "character": "",
        "metadata": { "hide": "no-git" }
      },
      {
        "id": "sep-2",
        "type": "custom-text",
        "customText": " │ ",
        "color": "ansi256:243",
        "merge": true,
        "metadata": { "hide": "merge-target-hidden" }
      },
      {
        "id": "ins-1",
        "type": "git-insertions",
        "color": "ansi256:151",
        "metadata": { "hide": "no-git,zero" }
      },
      {
        "id": "gap-3",
        "type": "custom-text",
        "customText": " ",
        "merge": true,
        "metadata": { "hide": "merge-target-hidden" }
      },
      {
        "id": "del-1",
        "type": "git-deletions",
        "color": "ansi256:211",
        "metadata": { "hide": "no-git,zero" }
      },
      {
        "id": "sep-3",
        "type": "custom-text",
        "customText": " │ ",
        "color": "ansi256:243",
        "merge": true,
        "metadata": { "hide": "merge-target-hidden" }
      },
      {
        "id": "pr-1",
        "type": "git-review",
        "color": "ansi256:243",
        "metadata": { "hide": "no-git,no-data,status" }
      }
    ],
    [
      {
        "id": "run-1",
        "type": "custom-command",
        "commandPath": "/absolute/path/to/ai-foo/statusline/statusline.mjs run",
        "timeout": 2000,
        "preserveColors": true
      }
    ]
  ],
  "flexMode": "full-minus-40",
  "compactThreshold": 60,
  "colorLevel": 2,
  "defaultPaddingSide": "both",
  "inheritSeparatorColors": false,
  "globalBold": false,
  "gitCacheTtlSeconds": 5,
  "minimalistMode": false,
  "powerline": {
    "enabled": false,
    "separators": [""],
    "separatorInvertBackground": [false],
    "startCaps": [],
    "endCaps": [],
    "autoAlign": false,
    "continueThemeAcrossLines": false
  },
  "installation": { "method": "self-managed", "packageManager": "npm" }
}
```

Neither settings file is inside this repository, so neither can be cited and neither is
drift-checked. This page is the only tracked copy of them: an edit made through the `ccstatusline`
TUI will not be reflected here until somebody updates this section.

[^sl-not-a-plugin]: `CLAUDE.md`, the statusline section.

[^sl-why]: `statusline/statusline.mjs`, header comment.

[^sl-buffer]: `statusline/statusline.mjs`, the auto-compact buffer constant.

[^sl-rates]: `statusline/statusline.mjs`, the cache-rate multipliers.

[^sl-cache]: `statusline/statusline.mjs`, `renderCache`.

[^sl-thresholds]: `statusline/statusline.mjs`, the threshold helpers.

[^sl-cost]: `statusline/statusline.mjs`, `renderCost`.

[^sl-dispatch]: `statusline/statusline.mjs`, argument dispatch and the group join.

[^sl-worktree]: `statusline/statusline.mjs`, the worktree mode.
