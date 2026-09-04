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
// Usage: statusline.mjs run

import { readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";

// Published input prices, $/1M tokens. A model absent here prints no cost
// rather than a guessed one.
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

// Auto-compact does not fire at a fraction of the window: Claude Code 2.1.260
// compacts once the context reaches the window less a fixed 13,000-token
// buffer, so that difference is what the meter measures against.
const AUTOCOMPACT_BUFFER = 13000;

// Cache reads bill at 0.1x the input rate, except on the Fable/Mythos tier.
const READ_MULT = (id) => (/^claude-(fable|mythos)-/.test(id) ? 0.025 : 0.1);
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
  track: "\x1b[38;5;238m", // the unfilled part of a bar
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

// The meter sits on the baseline and stops at half a cell, so it is no taller
// than a lowercase letter beside it. The full block it replaced filled the
// cell and stood above the whole line. Half blocks have no partial-width
// siblings, so the meter steps a whole cell at a time; the percentage printed
// beside it carries the precision that costs.
function bar(pct, cells, colour) {
  const full = Math.round((Math.max(0, Math.min(100, pct)) / 100) * cells);
  return (
    paint("▄".repeat(full), colour) + paint("▁".repeat(cells - full), C.track)
  );
}

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
  // meter, so only the name is kept.
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
    bar(pct, 12, tone(pct)) +
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

  // The next request re-sends the whole context: at read rates while the cache
  // is warm, at write rates once the prefix has to be rebuilt.
  const rate = INPUT_RATE[modelId(d)];
  if (rate) {
    const pc = d.prompt_cache;
    const warm = pc ? pc.warm !== false : true;
    const tokens = warm
      ? contextTokens(d.context_window?.current_usage)
      : (pc?.recache_tokens_if_cold ??
        contextTokens(d.context_window?.current_usage));
    const mult = warm ? READ_MULT(modelId(d)) : WRITE_MULT(pc?.ttl);
    if (tokens)
      parts.push(
        paint("next", C.comment) +
          " " +
          paint(money((tokens / 1e6) * rate * mult), warm ? C.yellow : C.red),
      );
  }
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

// A linked worktree has a `.git` file rather than a `.git` directory, and that
// file names a git dir under `worktrees/`. Reading it beats shelling out to
// git, which would cost a second process on every render.
function inWorktree(start) {
  for (let dir = start; dir; dir = dirname(dir) === dir ? null : dirname(dir)) {
    const dotGit = join(dir, ".git");
    let st;
    try {
      st = statSync(dotGit);
    } catch {
      continue;
    }
    if (st.isDirectory()) return false;
    try {
      return /\/worktrees\//.test(readFileSync(dotGit, "utf8"));
    } catch {
      return false;
    }
  }
  return false;
}

const data = readStdin();
if (!data) process.exit(0);

// The first line is ccstatusline's, but its worktree widget prints the word
// "main" in an ordinary checkout, which read as a second branch name. This
// prints a mark and only when the directory really is a linked worktree.
if (process.argv[2] === "worktree") {
  const cwd = data.workspace?.current_dir ?? data.cwd;
  // ccstatusline trims a widget's output, so the space that sets the mark off
  // from the path is a custom-text widget in the config, not a space here.
  if (cwd && inWorktree(cwd)) process.stdout.write("🌿");
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
