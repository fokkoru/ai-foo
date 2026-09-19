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

import { readFileSync } from "node:fs";

// Published prices, $/1M tokens, from
// https://platform.claude.com/docs/en/about-claude/pricing retrieved 2026-09-19.
// A model absent here prints no cost rather than a guessed one.
//
// `read` is the cache-read multiplier where it departs from the standard 0.1x:
// the pricing page names Fable 5.1 and Mythos 5.1 alone as the 0.025x exception.
//
// `fast` is the fast-mode pair. It is sold on two models, at $10/$50 in place
// of $5/$25, and the cache multipliers stack on that base — the pricing page
// says so, and Claude Code 2.1.278's own cost ledger swaps to a 10/50 table
// with 12.5/20/1 cache rates when `speed` is "fast". Opus 4.7 rejects fast
// mode and Opus 4.6 bills it at standard rates, so neither carries the pair.
// The payload's `fast_mode` is the session toggle rather than the speed the
// last response ran at; the current_usage it reports is normalised to the four
// token counts alone.
const MODELS = {
  "claude-opus-5": { input: 5, output: 25, fast: { input: 10, output: 50 } },
  "claude-opus-4-8": { input: 5, output: 25, fast: { input: 10, output: 50 } },
  "claude-opus-4-7": { input: 5, output: 25 },
  "claude-opus-4-6": { input: 5, output: 25 },
  "claude-sonnet-5": { input: 2, output: 10 },
  "claude-sonnet-4-6": { input: 3, output: 15 },
  "claude-haiku-4-5": { input: 1, output: 5 },
  "claude-fable-5": { input: 10, output: 50 },
  "claude-fable-5-1": { input: 10, output: 50, read: 0.025 },
  "claude-mythos-5": { input: 10, output: 50 },
  "claude-mythos-5-1": { input: 10, output: 50, read: 0.025 },
};

// The four multipliers this payload is priced at: the input and output rates
// for the model and fast-mode toggle, the cache-read multiplier for the model,
// and the cache-write multiplier for the reported TTL — 1.25x on the 5-minute
// TTL, 2x on the 1-hour TTL. Null for a model the table does not list.
function pricing(d) {
  // Claude Code appends a context-window suffix, e.g. "claude-opus-5[1m]".
  const m = MODELS[String(d.model?.id ?? "").replace(/\[.*\]$/, "")];
  if (!m) return null;
  const { input, output } = d.fast_mode === true && m.fast ? m.fast : m;
  return {
    input,
    output,
    read: m.read ?? 0.1,
    write: d.prompt_cache?.ttl === "1h" ? 2 : 1.25,
  };
}

// The four token counts current_usage carries, zero where a class is absent.
// The three input classes are disjoint: their sum is the context, and each is
// charged once at its own multiplier. Null before the first response, and
// documented null right after a compaction too.
function usage(d) {
  const u = d.context_window?.current_usage;
  if (!u) return null;
  return {
    fresh: u.input_tokens ?? 0,
    written: u.cache_creation_input_tokens ?? 0,
    read: u.cache_read_input_tokens ?? 0,
    output: u.output_tokens ?? 0,
  };
}

// Auto-compact does not fire at a fraction of the window. Claude Code 2.1.278
// compacts once the context reaches the window less two reserves: 20,000
// tokens held back for the summary response (the model's output cap where
// that is smaller, which no current model's is), then a fixed 13,000-token
// buffer. `/context` reports their sum as "Autocompact buffer: 33k tokens",
// and that sum is what the percentage measures against. The payload carries
// neither reserve, so the figure is pinned here.
const AUTOCOMPACT_BUFFER = 20000 + 13000;

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
  const used = u.fresh + u.written + u.read;
  const pct = Math.round((used / (size - AUTOCOMPACT_BUFFER)) * 100);
  return label(
    "ctx",
    C.cyan,
    emphasise(pct + "%", tone(pct)) + paint(" " + compact(used), C.comment),
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
  // Input tokens weighted by their multipliers, priced at the input rate.
  const priced = (tokens, colour) =>
    paint(money((tokens * p.input) / 1e6), colour);

  // The request that just finished, priced from the token split the payload
  // reports. This is an estimate at published prices rather than the billed
  // figure: the payload reports one ttl, so a request that wrote at mixed TTLs
  // is priced at the last one.
  if (u)
    parts.push(
      label(
        "last",
        C.comment,
        paint(
          money(
            (u.fresh * p.input +
              u.written * p.input * p.write +
              u.read * p.input * p.read +
              u.output * p.output) /
              1e6,
          ),
          C.yellow,
        ),
      ),
    );

  // The next request re-sends the whole context: at read rates while the cache
  // is warm, at write rates once the prefix has to be rebuilt, and at the plain
  // input rate where no response has reported cache tokens at all. That last
  // state prints grey, because nothing measured the cache — printing the cold
  // figure in red there asserts a fact the payload does not carry. While warm,
  // only what the last response read or wrote is behind a breakpoint: its
  // uncached input sat after the last one, and its output joins the context
  // now, so both are written next time. What the user types next is unknown
  // and left out.
  let next;
  if (pc?.caching_observed === true) {
    if (pc.warm === false)
      // Documented null right after a compaction: the quantity is unknown, and
      // substituting the last context would print a guess as a measurement.
      next =
        pc.recache_tokens_if_cold == null
          ? paint("?", C.red)
          : priced(pc.recache_tokens_if_cold * p.write, C.red);
    else if (u)
      next = priced(
        (u.read + u.written) * p.read + (u.fresh + u.output) * p.write,
        C.yellow,
      );
  } else if (u)
    next = priced(u.fresh + u.written + u.read + u.output, C.comment);
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
  // prints a mark and only when the directory really is a linked worktree.
  // Claude Code carries that in two fields, and every payload captured on
  // 2.1.269 carried one or the other. `workspace.git_worktree` is the git
  // answer: the worktree's name, present when the session's own cwd resolves
  // to a linked worktree's git directory. A session the harness moved into a
  // worktree itself gets the top-level `worktree` object instead — name, path,
  // branch, original_cwd, original_branch — and then `workspace.git_worktree`
  // is absent. Both observed on Claude Code 2.1.269; reading only the first
  // left every harness-made worktree unmarked.
  //
  // ccstatusline trims a widget's output, so the space that sets the mark off
  // from the path is a custom-text widget in the config, not a space here.
  if (data.worktree?.name || data.workspace?.git_worktree)
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
