#!/usr/bin/env node
// The second line of the Claude Code status line, rendered whole.
//
// ccstatusline renders the first line, where its git widgets do work worth
// reusing. It cannot render this one: it reads no `prompt_cache` field, paints
// each widget a single colour rather than colouring by threshold, and has no
// way to give one value more visual weight than its neighbour. All of that
// arrives here on stdin as the JSON Claude Code hands the status line.
//
// Focus order, left to right: model, context, cache, cost, then the two
// rate-limit windows. Groups are divided by a rule; inside a group every
// number carries the word that says what it is.
//
// Usage: statusline.mjs run | worktree

import { spawnSync } from "node:child_process";
import { readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join, sep } from "node:path";

// Published prices, $/1M tokens, from
// https://platform.claude.com/docs/en/about-claude/pricing retrieved 2026-11-16.
// A model absent here prints no cost rather than a guessed one.
//
// `read` is the cache-read multiplier where the pricing page names one other
// than the standard 0.1x.
//
// `fast` is the fast-mode pair, on the five models the pricing page lists one
// for. The cache multipliers stack on that base. The pricing page says so,
// and Claude Code 2.1.326's own cost ledger agrees: when `speed` is "fast" it
// swaps to a 16/80 table with 20/32/0.4 cache rates on Fable 5.2 and Mythos
// 5.2, an 8/40 table with 10/16/0.4 on Opus 5.5, and a 10/50 table with
// 12.5/20/1 on Opus 5 and Opus 4.8. That ledger also holds a 30/150 table for
// Opus 4.6 and Opus 4.7. The pricing page lists no fast-mode price for
// either, so neither carries the pair here. The payload's `fast_mode` is the
// session toggle rather than the speed the last response ran at; the
// current_usage it reports is normalised to the four token counts alone.
//
// `long` is the pair a long prompt pays. Haiku 5.5 alone is priced by prompt
// length: a request whose prompt is over 100,000 tokens pays $0.50/$2.50, and
// the prompt counts every input token, cache reads and cache writes included.
// Each request is priced on its own.
const MODELS = {
  "claude-opus-5-5": {
    input: 4,
    output: 20,
    read: 0.05,
    fast: { input: 8, output: 40 },
  },
  "claude-opus-5": { input: 5, output: 25, fast: { input: 10, output: 50 } },
  "claude-opus-4-8": { input: 5, output: 25, fast: { input: 10, output: 50 } },
  "claude-opus-4-7": { input: 5, output: 25 },
  "claude-opus-4-6": { input: 5, output: 25 },
  "claude-sonnet-5-5": { input: 2, output: 10, read: 0.05 },
  "claude-sonnet-5": { input: 2, output: 10 },
  "claude-sonnet-4-6": { input: 3, output: 15 },
  "claude-haiku-5-5": {
    input: 0.1,
    output: 0.5,
    long: { above: 100000, input: 0.5, output: 2.5 },
  },
  "claude-haiku-4-5": { input: 1, output: 5 },
  "claude-fable-5": { input: 10, output: 50 },
  "claude-fable-5-1": { input: 10, output: 50, read: 0.025 },
  "claude-fable-5-2": {
    input: 8,
    output: 40,
    read: 0.025,
    fast: { input: 16, output: 80 },
  },
  "claude-mythos-5": { input: 10, output: 50 },
  "claude-mythos-5-1": { input: 10, output: 50, read: 0.025 },
  "claude-mythos-5-2": {
    input: 8,
    output: 40,
    read: 0.025,
    fast: { input: 16, output: 80 },
  },
};

// Claude Code appends a context-window suffix, e.g. "claude-opus-5[1m]".
const modelId = (d) => String(d.model?.id ?? "").replace(/\[.*\]$/, "");

// What this payload is priced at: the input and output rates for the model,
// the fast-mode toggle and the length of the prompt being priced, the
// cache-read multiplier for the model, and the cache-write multiplier for the
// reported TTL — 1.25x on the 5-minute TTL, 2x on the 1-hour TTL. Null for a
// model the table does not list.
function pricing(d) {
  const m = MODELS[modelId(d)];
  if (!m) return null;
  const standard = d.fast_mode === true && m.fast ? m.fast : m;
  return {
    rates: (prompt) => (m.long && prompt > m.long.above ? m.long : standard),
    read: m.read ?? 0.1,
    write: d.prompt_cache?.ttl === "1h" ? 2 : 1.25,
  };
}

// The four token counts current_usage carries, zero where a class is absent.
// The three input classes are disjoint: their sum, `prompt`, is the context,
// and each is charged once at its own multiplier. Null before the first
// response, and documented null right after a compaction too.
function usage(d) {
  const u = d.context_window?.current_usage;
  if (!u) return null;
  const fresh = u.input_tokens ?? 0;
  const written = u.cache_creation_input_tokens ?? 0;
  const read = u.cache_read_input_tokens ?? 0;
  return {
    fresh,
    written,
    read,
    prompt: fresh + written + read,
    output: u.output_tokens ?? 0,
  };
}

// Auto-compact has a hard limit, and it is not a fraction of the window.
// Claude Code 2.1.325 takes the auto-compact window and subtracts two
// reserves: 20,000 tokens held back for the summary response (the model's
// output cap where that is smaller, which no current model's is), then a fixed
// 13,000-token buffer. The percentage measures against what is left. The
// payload carries neither reserve, so their sum is pinned here.
//
// It is the hard limit rather than the only trigger. Transcripts from October
// and November 2026 record auto compactions on Opus 5.5 and Fable 5.2 both at
// that limit and well below it, and the payload gives no way to predict the
// early ones.
const SUMMARY_RESERVE = 20000;
const AUTOCOMPACT_BUFFER = SUMMARY_RESERVE + 13000;

// With auto-compact off there is no such limit. Claude Code 2.1.326 then
// reports the context as blocked once it comes within 3,000 tokens of the
// model's window less the same summary reserve, whatever auto-compact window
// is configured.
const BLOCKING_BUFFER = SUMMARY_RESERVE + 3000;

// The sizes Claude Code 2.1.325 takes for an auto-compact window, in tokens.
const WINDOW_MIN = 100000;
const WINDOW_MAX = 1000000;

// The window CLAUDE_CODE_AUTO_COMPACT_WINDOW names, read the way Claude Code
// 2.1.325 reads it, or undefined where the variable is unset or names no
// size. A trailing "k" or "m" multiplies. Without one the value may carry an
// exponent, which must come to a whole number, or grouped thousands; Claude
// Code tries those two forms on a value of at most 32 characters. Anything
// else is read as far as its leading digits go. A size under the minimum
// counts as the minimum and one over the maximum as the maximum.
function windowFromEnv() {
  const text = (process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW ?? "").trim();
  const unit = { k: 1e3, m: 1e6 }[text.slice(-1).toLowerCase()];
  const short = text.length <= 32;
  const grouped =
    short && /^[+-]?\d{1,3}([_,\u00A0\u202F ])\d{3}(?:\1\d{3})*$/.exec(text);
  let tokens;
  if (unit) tokens = parseFloat(text) * unit;
  else if (short && /^[+-]?(\d+(\.\d*)?|\.\d+)[eE][+-]?\d+$/.test(text))
    tokens = Number.isInteger(Number(text)) ? Number(text) : NaN;
  else if (grouped) tokens = parseInt(text.replaceAll(grouped[1], ""), 10);
  else tokens = parseInt(text, 10);
  if (Number.isNaN(tokens) || tokens < 1) return undefined;
  return Math.min(Math.max(Math.round(tokens), WINDOW_MIN), WINDOW_MAX);
}

// The settings files read here, lowest-ranking first, in the order Claude
// Code 2.1.326 ranks them: the user's, then the project's shared and local
// ones under `workspace.project_dir`. A file that is absent or is not JSON is
// left out. Claude Code ranks two more sources above these, settings passed
// on the command line and managed settings, and neither is read here. It may
// also keep the local file under what it calls the canonical git root in
// place of the project directory, and that is not followed.
function settingsFiles(d) {
  const project = d.workspace?.project_dir;
  return [
    join(
      process.env.CLAUDE_CONFIG_DIR ?? join(homedir(), ".claude"),
      "settings.json",
    ),
    ...(project
      ? ["settings.json", "settings.local.json"].map((file) =>
          join(project, ".claude", file),
        )
      : []),
  ].flatMap((path) => {
    try {
      return [JSON.parse(readFileSync(path, "utf8"))];
    } catch {
      return [];
    }
  });
}

// Whether auto-compact is switched off, as Claude Code 2.1.326 decides it:
// by DISABLE_COMPACT or DISABLE_AUTO_COMPACT set to 1, true, yes or on, and
// otherwise by `autoCompactEnabled` in the highest-ranking settings file that
// names it. Where no settings file names it Claude Code also consults its
// older global config file, which is not read here. A value other than true
// or false counts as no setting here; what Claude Code makes of a file that
// holds one was not read.
function autoCompactOff(files) {
  const set = (value) =>
    ["1", "true", "yes", "on"].includes((value ?? "").toLowerCase().trim());
  if (set(process.env.DISABLE_COMPACT) || set(process.env.DISABLE_AUTO_COMPACT))
    return true;
  return (
    files
      .map((settings) => settings?.autoCompactEnabled)
      .findLast((enabled) => typeof enabled === "boolean") === false
  );
}

// The window the settings files name for a model in `autoCompactWindow`, or
// undefined where they name none. Claude Code 2.1.326 takes an integer from
// the minimum to the maximum, and under `modelSettings` the word "auto" too;
// any other value is no setting. An entry under `modelSettings` for the model
// wins over a top-level window, and its "auto" sets that window aside. A file
// that names a top-level window replaces what the lower-ranking files said
// for the model; a file that names none adds its entry to theirs.
//
// A `modelSettings` key names the model by the id the payload carries, with
// or without "[1m]" behind it. The plain id wins, and among the others the
// first does. Claude Code matches a dated, Bedrock or Vertex spelling and an
// alias too; those are not matched here.
function windowFromSettings(files, model) {
  const inRange = (w) =>
    Number.isInteger(w) && w >= WINDOW_MIN && w <= WINDOW_MAX;
  let topLevel, perModel;
  for (const settings of files) {
    let own;
    for (const [key, entry] of Object.entries(settings?.modelSettings ?? {})) {
      const window = entry?.autoCompactWindow;
      if (window !== "auto" && !inRange(window)) continue;
      if (key === model) own = window;
      else if (key.replace(/\[1m\]$/i, "") === model) own ??= window;
    }
    if (inRange(settings?.autoCompactWindow))
      [topLevel, perModel] = [settings.autoCompactWindow, own];
    else perModel = own ?? perModel;
  }
  return perModel === "auto" ? undefined : (perModel ?? topLevel);
}

// The size the context percentage measures against. With auto-compact off it
// is the model's context window less the blocking buffer. With it on it is
// the auto-compact window less its buffer. That window is the model's
// context window unless something names a smaller one, and the payload does
// not say whether anything did. Two sources are read, in the order Claude
// Code 2.1.325 gives them: the CLAUDE_CODE_AUTO_COMPACT_WINDOW variable, then
// the settings files. The variable reaches a status line command through its
// environment, as seen on Claude Code 2.1.326. Claude Code also takes the
// window from a choice made inside the session, from an agent definition and
// from defaults of its own; none of those is read here, so the percentage is
// an estimate wherever one of them, or a settings source left unread above,
// is in force.
function contextLimit(d, size) {
  const files = settingsFiles(d);
  if (autoCompactOff(files)) return size - BLOCKING_BUFFER;
  const window =
    windowFromEnv() ?? windowFromSettings(files, modelId(d)) ?? size;
  return Math.min(size, window) - AUTOCOMPACT_BUFFER;
}

// Catppuccin Mocha, mapped to the nearest xterm-256 entries. colorLevel is 2,
// so 256 colours are what the terminal is told to expect. The names are roles
// rather than hues, so swapping the theme is this one object.
const C = {
  purple: "\x1b[38;5;183m", // #cba6f7 mauve — the model
  cyan: "\x1b[38;5;116m", // #89dceb sky — group labels
  green: "\x1b[38;5;151m", // #a6e3a1 — healthy
  orange: "\x1b[38;5;216m", // #fab387 peach — getting close
  red: "\x1b[38;5;211m", // #f38ba8 — out of room
  yellow: "\x1b[38;5;223m", // #f9e2af — money
  pink: "\x1b[38;5;218m", // #f5c2e7 — the limit windows
  comment: "\x1b[38;5;243m", // #6c7086 overlay — words, rules, units
  off: "\x1b[0m",
};

// Colour encodes state. 60% is where there is still room to act; 85% is where
// there is not.
const tone = (pct) => (pct >= 85 ? C.red : pct >= 60 ? C.orange : C.green);
// Hit ratio runs the other way: a healthy session sits above 90%, and anything
// under 60% means the prefix is being rebuilt on most requests.
const toneHit = (pct) => (pct >= 85 ? C.green : pct >= 60 ? C.orange : C.red);
const paint = (s, c) => c + s + C.off;
const emphasise = (s, c) => "\x1b[1m" + c + s + C.off;
const label = (word, colour, value) => paint(word, colour) + " " + value;

const RULE = paint("│", C.comment);

function money(n) {
  return n < 0.01 && n > 0 ? "<$0.01" : "$" + n.toFixed(2);
}

function compact(n) {
  if (n >= 1e6) return (n / 1e6).toFixed(1) + "M";
  if (n >= 1e3) return (n / 1e3).toFixed(1) + "k";
  return String(n);
}

function minutesLeft(epochSeconds) {
  const mins = Math.round((epochSeconds * 1000 - Date.now()) / 60000);
  return mins > 0 ? mins : null;
}

function duration(mins) {
  return mins >= 60
    ? Math.floor(mins / 60) + "h" + (mins % 60) + "m"
    : mins + "m";
}

// ---- model and effort ----------------------------------------------------
function renderModel(d) {
  // The display name carries a parenthetical for the wide-context variants,
  // "Opus 5 (1M context)". The window size is already implied by the context
  // percentage, so only the name is kept.
  const name = String(d.model?.display_name ?? "")
    .replace(/\s*\(.*\)\s*$/, "")
    .trim();
  const effort = d.effort?.level;
  return [
    name && emphasise(name, C.purple),
    effort && paint(String(effort), C.orange),
  ]
    .filter(Boolean)
    .join(" ");
}

// ---- context -------------------------------------------------------------
function renderContext(d) {
  const u = usage(d);
  const size = d.context_window?.context_window_size;
  if (!u || !size) return "";
  const pct = Math.round((u.prompt / contextLimit(d, size)) * 100);
  return label(
    "ctx",
    C.cyan,
    emphasise(pct + "%", tone(pct)) + paint(" " + compact(u.prompt), C.comment),
  );
}

// ---- cache ---------------------------------------------------------------
function renderCache(d) {
  const pc = d.prompt_cache;
  if (!pc || !pc.caching_observed) return "";
  if (pc.warm === false)
    return label("cache", C.cyan, emphasise("cold", C.red));
  if (pc.hit_ratio == null) return "";
  const hit = Math.round(pc.hit_ratio * 100);
  const left = pc.expires_at ? minutesLeft(pc.expires_at) : null;
  // The short TTL Anthropic offers is five minutes, so once less than that is
  // left the prefix is as good as gone and the countdown stops being green.
  const ttlTone = left != null && left < 5 ? C.orange : C.green;
  return label(
    "cache",
    C.cyan,
    emphasise(hit + "%", toneHit(hit)) +
      (left != null
        ? paint(" warm ", C.comment) + paint(duration(left), ttlTone)
        : ""),
  );
}

// ---- cost ----------------------------------------------------------------
function renderCost(d) {
  const parts = [];
  const spent = d.cost?.total_cost_usd;
  if (typeof spent === "number")
    parts.push(label("cost", C.comment, emphasise(money(spent), C.yellow)));

  const p = pricing(d);
  if (!p) return parts.join(" ");
  const u = usage(d);
  const pc = d.prompt_cache;
  // Input tokens weighted by their multipliers, priced at the input rate a
  // prompt of that length pays.
  const priced = (prompt, weighted, colour) =>
    paint(money((weighted * p.rates(prompt).input) / 1e6), colour);

  // The request that just finished, priced from the token split the payload
  // reports. This is an estimate at published prices rather than the billed
  // figure: the payload reports one ttl, so a request that wrote at mixed TTLs
  // is priced at the last one.
  if (u) {
    const { input, output } = p.rates(u.prompt);
    parts.push(
      label(
        "last",
        C.comment,
        paint(
          money(
            (u.fresh * input +
              u.written * input * p.write +
              u.read * input * p.read +
              u.output * output) /
              1e6,
          ),
          C.yellow,
        ),
      ),
    );
  }

  // The next request re-sends the whole context: at read rates while the cache
  // is warm, at write rates once the prefix has to be rebuilt, and at the plain
  // input rate where no response has reported cache tokens at all. That last
  // state prints grey, because nothing measured the cache — printing the cold
  // figure in red there asserts a fact the payload does not carry. While warm,
  // only what the last response read or wrote is behind a breakpoint: its
  // uncached input sat after the last one, and its output joins the context
  // now, so both are written next time. What the user types next is unknown
  // and left out.
  const nextPrompt = u && u.prompt + u.output;
  let next;
  if (pc?.caching_observed === true) {
    if (pc.warm === false) {
      // Documented null right after a compaction: the quantity is unknown, and
      // substituting the last context would print a guess as a measurement.
      // Where it is known it is the last request's input alone — Claude Code
      // 2.1.325 sums that request's uncached, cache-read and cache-written
      // tokens — so the next prompt is that plus the last output, and with
      // nothing cached all of it is written.
      const cold =
        pc.recache_tokens_if_cold == null
          ? null
          : pc.recache_tokens_if_cold + (u?.output ?? 0);
      next =
        cold == null ? paint("?", C.red) : priced(cold, cold * p.write, C.red);
    } else if (u)
      next = priced(
        nextPrompt,
        (u.read + u.written) * p.read + (u.fresh + u.output) * p.write,
        C.yellow,
      );
  } else if (u) next = priced(nextPrompt, nextPrompt, C.comment);
  if (next) parts.push(label("next", C.comment, next));
  return parts.join(" ");
}

// ---- rate-limit windows --------------------------------------------------
function renderLimits(d) {
  const rl = d.rate_limits;
  if (!rl) return "";
  return [
    ["5h", rl.five_hour?.used_percentage],
    ["7d", rl.seven_day?.used_percentage],
  ]
    .filter(([, pct]) => pct != null)
    .map(([w, pct]) =>
      label(w, C.pink, paint(Math.round(pct) + "%", tone(pct))),
    )
    .join(" ");
}

// ---- the worktree mark ---------------------------------------------------
// Whether a directory is inside the worktree the payload's top-level
// `worktree` object names. Claude Code 2.1.325 sends that object while the
// session runs in a worktree Claude Code put it in, and ccstatusline 2.2.29
// forwards it. It is the only sign of a worktree a WorktreeCreate hook made
// for another version-control system: Claude Code records such a worktree's
// name and path, and git knows nothing of it. The object describes the
// session and not the directory, so it counts only while the directory is
// inside the path it names. The two are compared as the file system resolves
// them, because the payload may reach one directory through a symbolic link
// or end its path in a separator. A path that cannot be resolved is compared
// as given.
function inSessionWorktree(worktree, dir) {
  if (!worktree?.path) return false;
  const [root, at] = [worktree.path, dir].map((path) => {
    try {
      return realpathSync(path);
    } catch {
      return path;
    }
  });
  return at === root || at.startsWith(root + sep);
}

// Whether git calls a directory part of a linked worktree. In a linked
// worktree `--git-dir` is the worktree's own directory under the
// repository's `worktrees/` and `--git-common-dir` is the repository's; in a
// main checkout or a submodule the two are one directory.
// `--path-format=absolute` is what makes them comparable: without it git
// 2.55.0 prints one absolute and the other relative from a subdirectory of a
// main checkout, and two spellings of one directory compare unequal.
//
// The payload cannot stand in for git. Claude Code 2.1.325 names a linked
// worktree in `workspace.git_worktree`, and ccstatusline 2.2.29 passes
// `workspace` on to a custom-command widget with `current_dir` and
// `project_dir` alone.
function inLinkedWorktree(dir) {
  // git is asked about the directory and nothing else. An inherited GIT_DIR
  // names a repository and git answers for that one, so the variables git
  // lists as belonging to one repository leave its environment first.
  const local = spawnSync("git", ["rev-parse", "--local-env-vars"], {
    encoding: "utf8",
  });
  if (local.status !== 0) return false;
  const env = { ...process.env };
  for (const name of local.stdout.split("\n")) delete env[name];
  const git = spawnSync(
    "git",
    [
      "-C",
      dir,
      "rev-parse",
      "--path-format=absolute",
      "--git-dir",
      "--git-common-dir",
    ],
    { encoding: "utf8", env },
  );
  // A git that does not know `--path-format` prints the flag back and exits
  // 0, as git 2.55.0 does with a made-up flag. Its paths are not comparable,
  // so an answer that does not open with an absolute path is no answer.
  if (git.status !== 0 || !isAbsolute(git.stdout)) return false;
  // git prints each path on a line of its own, and a path may itself hold a
  // newline. The two paths are equal exactly when the output's halves are.
  const half = git.stdout.length / 2;
  return git.stdout.slice(0, half) !== git.stdout.slice(half);
}

let data;
try {
  data = JSON.parse(readFileSync(0, "utf8"));
} catch {
  process.exit(0);
}
if (!data) process.exit(0);

if (process.argv[2] === "worktree") {
  // The first line is ccstatusline's, but its worktree widget prints the word
  // "main" in an ordinary checkout, which read as a second branch name. This
  // prints a mark and only when the directory, `workspace.current_dir`, is
  // inside a worktree.
  //
  // ccstatusline trims a widget's output, so the space that sets the mark off
  // from the path is a custom-text widget in the config, not a space here.
  const dir = data.workspace?.current_dir;
  if (dir && (inSessionWorktree(data.worktree, dir) || inLinkedWorktree(dir)))
    process.stdout.write("🌿");
} else if (process.argv[2] === "run") {
  process.stdout.write(
    [
      renderModel(data),
      renderContext(data),
      renderCache(data),
      renderCost(data),
      renderLimits(data),
    ]
      .filter(Boolean)
      .join(" " + RULE + " "),
  );
}
