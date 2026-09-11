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
// https://platform.claude.com/docs/en/about-claude/pricing retrieved 2026-09-05.
// A model absent here prints no cost rather than a guessed one.
const INPUT_RATE = {
  "claude-opus-5": 5,
  "claude-opus-4-8": 5,
  "claude-opus-4-7": 5,
  "claude-opus-4-6": 5,
  "claude-sonnet-5": 2,
  "claude-sonnet-4-6": 3,
  "claude-haiku-4-5": 1,
  "claude-fable-5": 10,
  "claude-fable-5-1": 10,
  "claude-mythos-5": 10,
  "claude-mythos-5-1": 10,
};

const OUTPUT_RATE = {
  "claude-opus-5": 25,
  "claude-opus-4-8": 25,
  "claude-opus-4-7": 25,
  "claude-opus-4-6": 25,
  "claude-sonnet-5": 10,
  "claude-sonnet-4-6": 15,
  "claude-haiku-4-5": 5,
  "claude-fable-5": 50,
  "claude-fable-5-1": 50,
  "claude-mythos-5": 50,
  "claude-mythos-5-1": 50,
};

// Auto-compact does not fire at a fraction of the window. Claude Code 2.1.268
// compacts once the context reaches the window less two reserves: 20,000
// tokens held back for the summary response, then a fixed 13,000-token
// buffer. `/context` reports their sum as "Autocompact buffer: 33k tokens",
// and that sum is what the percentage measures against. The payload carries
// neither reserve, so the figure is pinned here.
const AUTOCOMPACT_BUFFER = 20000 + 13000;

// Cache reads bill at 0.1x the input rate; the pricing page names Fable 5.1 and
// Mythos 5.1 alone as the 0.025x exception, and every other model as standard.
const READ_MULT = (id) =>
  /^claude-(fable|mythos)-5-1$/.test(id) ? 0.025 : 0.1;
// Cache writes bill at 1.25x on the 5-minute TTL, 2x on the 1-hour TTL.
const WRITE_MULT = (ttl) => (ttl === "1h" ? 2 : 1.25);

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

const RULE = paint("│", C.comment);

function readStdin() {
  try {
    return JSON.parse(readFileSync(0, "utf8"));
  } catch {
    return null;
  }
}

function modelId(d) {
  // Claude Code appends a context-window suffix, e.g. "claude-opus-5[1m]".
  return String(d?.model?.id ?? "").replace(/\[.*\]$/, "");
}

function contextTokens(u) {
  if (!u) return null;
  return (
    (u.input_tokens ?? 0) +
    (u.cache_creation_input_tokens ?? 0) +
    (u.cache_read_input_tokens ?? 0)
  );
}

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
  const parts = [];
  if (name) parts.push(emphasise(name, C.purple));
  const effort = d.effort?.level;
  if (effort) parts.push(paint(String(effort), C.orange));
  return parts.join(" ");
}

// ---- context -------------------------------------------------------------
function renderContext(d) {
  const used = contextTokens(d.context_window?.current_usage);
  const size = d.context_window?.context_window_size;
  if (used == null || !size) return "";
  const pct = Math.round((used / (size - AUTOCOMPACT_BUFFER)) * 100);
  return (
    paint("ctx", C.cyan) +
    " " +
    emphasise(pct + "%", tone(pct)) +
    paint(" " + compact(used), C.comment)
  );
}

// ---- cache ---------------------------------------------------------------
function renderCache(d) {
  const pc = d.prompt_cache;
  if (!pc || !pc.caching_observed) return "";
  if (pc.warm === false)
    return paint("cache", C.cyan) + " " + emphasise("cold", C.red);
  if (pc.hit_ratio == null) return "";
  const hit = Math.round(pc.hit_ratio * 100);
  const left = pc.expires_at ? minutesLeft(pc.expires_at) : null;
  // The short TTL Anthropic offers is five minutes, so once less than that is
  // left the prefix is as good as gone and the countdown stops being green.
  const ttlTone = left != null && left < 5 ? C.orange : C.green;
  return (
    paint("cache", C.cyan) +
    " " +
    emphasise(hit + "%", toneHit(hit)) +
    (left != null
      ? paint(" warm ", C.comment) + paint(duration(left), ttlTone)
      : "")
  );
}

// ---- cost ----------------------------------------------------------------
function renderCost(d) {
  const parts = [];
  const spent = d.cost?.total_cost_usd;
  if (typeof spent === "number")
    parts.push(
      paint("cost", C.comment) + " " + emphasise(money(spent), C.yellow),
    );

  const id = modelId(d);
  const rate = INPUT_RATE[id];
  if (!rate) return parts.join(" ");
  const pc = d.prompt_cache;
  const usage = d.context_window?.current_usage;

  // The request that just finished, priced from the token split the payload
  // reports. The three input classes are disjoint, so each is charged once at
  // its own multiplier, and contextTokens() — which sums them deliberately — is
  // the wrong tool here. This is an estimate at published prices rather than
  // the billed figure: the payload reports one ttl, so a request that wrote at
  // mixed TTLs is priced at the last one.
  const outRate = OUTPUT_RATE[id];
  if (usage && outRate)
    parts.push(
      paint("last", C.comment) +
        " " +
        paint(
          money(
            ((usage.input_tokens ?? 0) * rate +
              (usage.cache_creation_input_tokens ?? 0) *
                rate *
                WRITE_MULT(pc?.ttl) +
              (usage.cache_read_input_tokens ?? 0) * rate * READ_MULT(id) +
              (usage.output_tokens ?? 0) * outRate) /
              1e6,
          ),
          C.yellow,
        ),
    );

  // The next request re-sends the whole context: at read rates while the cache
  // is warm, at write rates once the prefix has to be rebuilt, and at the plain
  // input rate where no response has reported cache tokens at all. That last
  // state prints grey, because nothing measured the cache — printing the cold
  // figure in red there asserts a fact the payload does not carry.
  const context = contextTokens(usage);
  let tokens = context;
  let mult = 1;
  let colour = C.comment;
  if (pc?.caching_observed === true) {
    if (pc.warm === false) {
      // Documented null right after a compaction: the quantity is unknown, and
      // substituting the last context would print a guess as a measurement.
      if (pc.recache_tokens_if_cold == null) {
        parts.push(paint("next", C.comment) + " " + paint("?", C.red));
        return parts.join(" ");
      }
      tokens = pc.recache_tokens_if_cold;
      mult = WRITE_MULT(pc.ttl);
      colour = C.red;
    } else {
      mult = READ_MULT(id);
      colour = C.yellow;
    }
  }
  if (tokens)
    parts.push(
      paint("next", C.comment) +
        " " +
        paint(money((tokens / 1e6) * rate * mult), colour),
    );
  return parts.join(" ");
}

// ---- rate-limit windows --------------------------------------------------
function renderLimits(d) {
  const rl = d.rate_limits;
  if (!rl) return "";
  const one = (label, pct) =>
    paint(label, C.pink) + " " + paint(Math.round(pct) + "%", tone(pct));
  const parts = [];
  if (rl.five_hour?.used_percentage != null)
    parts.push(one("5h", rl.five_hour.used_percentage));
  if (rl.seven_day?.used_percentage != null)
    parts.push(one("7d", rl.seven_day.used_percentage));
  return parts.join(" ");
}

const data = readStdin();
if (!data) process.exit(0);

// The first line is ccstatusline's, but its worktree widget prints the word
// "main" in an ordinary checkout, which read as a second branch name. This
// prints a mark and only when the directory really is a linked worktree.
// Claude Code carries that in two fields, and every payload captured on 2.1.269
// carried one or the other. `workspace.git_worktree` is the git answer: the
// worktree's name, present when the session's own cwd resolves to a linked
// worktree's git directory. A session the harness moved into a worktree itself
// gets the top-level `worktree` object instead — name, path, branch,
// original_cwd, original_branch — and then `workspace.git_worktree` is absent.
// Both observed on Claude Code 2.1.269; reading only the first left every
// harness-made worktree unmarked.
if (process.argv[2] === "worktree") {
  // ccstatusline trims a widget's output, so the space that sets the mark off
  // from the path is a custom-text widget in the config, not a space here.
  if (data.worktree?.name || data.workspace?.git_worktree)
    process.stdout.write("🌿");
  process.exit(0);
}

if (process.argv[2] !== "run") process.exit(0);

const out = [
  renderModel(data),
  renderContext(data),
  renderCache(data),
  renderCost(data),
  renderLimits(data),
]
  .filter(Boolean)
  .join(" " + RULE + " ");
if (out) process.stdout.write(out);
