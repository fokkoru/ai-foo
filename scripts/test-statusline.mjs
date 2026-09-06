#!/usr/bin/env node
// Tests statusline/statusline.mjs at its only public seam: a JSON payload on
// stdin, a rendered line on stdout. No internal is imported, so a rewrite of
// any renderer leaves these tests standing.
//
// Every money assertion is an exact value computed by hand from the published
// rates, never the presence of a label — a test that only checks "last" appears
// passes on wrong arithmetic. Colour is asserted before the escapes are
// stripped, because a figure in the wrong colour is what these tests exist for.
//
// Usage: node scripts/test-statusline.mjs

import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(
  dirname(dirname(fileURLToPath(import.meta.url))),
  "statusline",
  "statusline.mjs",
);

const GREY = "\x1b[38;5;243m";
const RED = "\x1b[38;5;211m";
const YELLOW = "\x1b[38;5;223m";
const OFF = "\x1b[0m";

let fail = 0;

function render(payload, mode = "run") {
  const r = spawnSync(process.execPath, [SCRIPT, mode], {
    input: JSON.stringify(payload),
    encoding: "utf8",
  });
  if (r.status !== 0) throw new Error(`exit ${r.status}: ${r.stderr}`);
  return r.stdout;
}

const plain = (s) => s.replace(/\x1b\[[0-9;]*m/g, "");

function ok(name, cond, detail) {
  if (cond) {
    console.log("ok: " + name);
  } else {
    console.log("FAIL: " + name + (detail ? " — " + detail : ""));
    fail = 1;
  }
}

function has(name, out, needle) {
  ok(
    name,
    out.includes(needle),
    `missing ${JSON.stringify(needle)} in ${JSON.stringify(out)}`,
  );
}

function lacks(name, out, needle) {
  ok(
    name,
    !out.includes(needle),
    `unexpected ${JSON.stringify(needle)} in ${JSON.stringify(out)}`,
  );
}

// A payload with all four token classes non-zero. 2000 + 5000 + 180000 =
// 187,000 tokens of context.
const usage = {
  input_tokens: 2000,
  cache_creation_input_tokens: 5000,
  cache_read_input_tokens: 180000,
  output_tokens: 900,
};

const base = (over = {}) => ({
  model: { id: "claude-opus-5", display_name: "Opus 5" },
  cost: { total_cost_usd: 1.5 },
  context_window: { context_window_size: 1000000, current_usage: usage },
  prompt_cache: {
    caching_observed: true,
    warm: true,
    ttl: "1h",
    hit_ratio: 0.94,
  },
  ...over,
});

// ---- the cache-read multiplier -------------------------------------------
// next, warm, = context/1e6 * input rate * READ_MULT.
// Fable 5 at 0.1x:    187000/1e6 * 10 * 0.1   = 0.187   -> $0.19
// Fable 5.1 at .025x: 187000/1e6 * 10 * 0.025 = 0.04675 -> $0.05
for (const [id, expected] of [
  ["claude-fable-5", "$0.19"],
  ["claude-mythos-5", "$0.19"],
  ["claude-fable-5-1", "$0.05"],
  ["claude-mythos-5-1", "$0.05"],
  ["claude-fable-5[1m]", "$0.19"],
  ["claude-fable-5-1[1m]", "$0.05"],
]) {
  const out = plain(render(base({ model: { id } })));
  has(`${id} prices a cache read at ${expected}`, out, "next " + expected);
}

// Opus 5 reads at the standard 0.1x: 187000/1e6 * 5 * 0.1 = 0.0935 -> $0.09
has("opus 5 reads at 0.1x", plain(render(base())), "next $0.09");

// ---- the measured last request -------------------------------------------
// 1h: (2000*5 + 5000*5*2 + 180000*5*0.1 + 900*25)/1e6
//   = (10000 + 50000 + 90000 + 22500)/1e6 = 0.1725 -> $0.17
has("last, 1h TTL, is $0.17", plain(render(base())), "last $0.17");

// 5m: (10000 + 5000*5*1.25 + 90000 + 22500)/1e6
//   = (10000 + 31250 + 90000 + 22500)/1e6 = 0.15375 -> $0.15
has(
  "last, 5m TTL, is $0.15",
  plain(
    render(
      base({
        prompt_cache: {
          caching_observed: true,
          warm: true,
          ttl: "5m",
          hit_ratio: 0.94,
        },
      }),
    ),
  ),
  "last $0.15",
);

lacks(
  "no last before the first response",
  plain(
    render(
      base({
        context_window: { context_window_size: 1000000, current_usage: null },
      }),
    ),
  ),
  "last ",
);

// ---- caching unobserved, in three spellings ------------------------------
// next at the plain input rate: 187000/1e6 * 5 * 1 = 0.935 -> $0.94, in grey.
for (const [name, pc] of [
  [
    "caching_observed false, warm true",
    { caching_observed: false, warm: true },
  ],
  [
    "caching_observed false, warm false",
    { caching_observed: false, warm: false },
  ],
  ["no prompt_cache key at all", undefined],
]) {
  const payload = base();
  if (pc) payload.prompt_cache = pc;
  else delete payload.prompt_cache;
  const raw = render(payload);
  has(`${name}: next at the base rate`, plain(raw), "next $0.94");
  has(`${name}: next is grey, not red`, raw, GREY + "$0.94" + OFF);
  lacks(`${name}: no cache group`, plain(raw), "cache");
}

// ---- an observed cold cache ----------------------------------------------
// 200000/1e6 * 5 * 2 = 2.00 -> $2.00, in red.
{
  const raw = render(
    base({
      prompt_cache: {
        caching_observed: true,
        warm: false,
        ttl: "1h",
        recache_tokens_if_cold: 200000,
      },
    }),
  );
  has("cold cache prices the recache at $2.00", plain(raw), "next $2.00");
  has("cold cache prints red", raw, RED + "$2.00" + OFF);
  has("cold cache still says cold", plain(raw), "cache cold");
}

// recache_tokens_if_cold is null right after a compaction: unknown, not a guess.
{
  const raw = render(
    base({
      prompt_cache: {
        caching_observed: true,
        warm: false,
        ttl: "1h",
        recache_tokens_if_cold: null,
      },
    }),
  );
  has("an unknown recache prints next ?", plain(raw), "next ?");
  has("the unknown is red", raw, RED + "?" + OFF);
  lacks("the unknown substitutes no figure", plain(raw), "next $");
}

// ---- session spend --------------------------------------------------------
has("session spend is yellow", render(base()), YELLOW + "$1.50" + OFF);

{
  const out = plain(render(base({ model: { id: "claude-unlisted-9" } })));
  has("an unlisted model still shows spend", out, "cost $1.50");
  lacks("an unlisted model projects nothing", out, "next");
  lacks("an unlisted model prices nothing", out, "last");
}

// ---- the worktree mark ----------------------------------------------------
// The payload decides. A current_dir that does not exist proves the filesystem
// no longer does.
ok(
  "git_worktree prints the mark even with a nonexistent current_dir",
  render(
    {
      workspace: {
        current_dir: "/nonexistent/definitely/not/here",
        git_worktree: "feature-x",
      },
    },
    "worktree",
  ) === "🌿",
);
ok(
  "no git_worktree prints nothing",
  render({ workspace: { current_dir: process.cwd() } }, "worktree") === "",
);

// ---- the whole line -------------------------------------------------------
// Every group at once, so the reader can see the width the line reaches.
{
  const raw = render(
    base({
      effort: { level: "high" },
      prompt_cache: {
        caching_observed: true,
        warm: true,
        ttl: "1h",
        hit_ratio: 0.94,
        expires_at: Math.floor(Date.now() / 1000) + 2400,
      },
      rate_limits: {
        five_hour: { used_percentage: 42 },
        seven_day: { used_percentage: 88 },
      },
    }),
  );
  const line = plain(raw);
  for (const group of [
    "Opus 5",
    "high",
    "ctx",
    "cache",
    "cost",
    "last",
    "next",
    "5h",
    "7d",
  ])
    has(`the full line carries ${group}`, line, group);
  console.log("note: the full line is " + [...line].length + " columns wide");
}

process.exit(fail);
