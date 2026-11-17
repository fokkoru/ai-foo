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
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { devNull, tmpdir } from "node:os";
import { delimiter, dirname, join, sep } from "node:path";
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

// Everything the suite writes goes under one directory, removed on exit
// however the run ends.
const TMP = mkdtempSync(join(tmpdir(), "statusline-test-"));
process.on("exit", () => rmSync(TMP, { recursive: true, force: true }));

// The environment every child process starts from. Nothing else is
// inherited, so no result depends on the machine running the suite.
const ENV = { PATH: process.env.PATH };

// The script reads the user's `settings.json` from Claude Code's config
// directory. Each render gets a directory of its own, holding that file only
// when the test passes its text. It reads a project's settings under
// `workspace.project_dir`, which no payload carries unless a test builds the
// project, so nothing is read from the machine running the suite.
function render(payload, mode = "run", { settings, env } = {}) {
  const config = mkdtempSync(join(TMP, "config-"));
  if (settings !== undefined)
    writeFileSync(join(config, "settings.json"), settings);
  const r = spawnSync(process.execPath, [SCRIPT, mode], {
    input: JSON.stringify(payload),
    encoding: "utf8",
    env: { ...ENV, ...env, CLAUDE_CONFIG_DIR: config },
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

// A payload with all four token classes non-zero. 2100 + 5000 + 180000 =
// 187,100 tokens of context. No expected figure below lands on a half cent:
// 0.345 has no exact binary float, so toFixed(2) would print it a cent low.
const usage = {
  input_tokens: 2100,
  cache_creation_input_tokens: 5000,
  cache_read_input_tokens: 180000,
  output_tokens: 1200,
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
// next, warm, = (cached * READ_MULT + fresh * WRITE_MULT) * rate / 1e6, where
// cached = cache_read + cache_creation = 185,000 and fresh = uncached input +
// output = 3,300.
// Fable 5 at 0.1x:    (185000*0.1   + 3300*2) * 10 / 1e6 = 0.251   -> $0.25
// Fable 5.1 at .025x: (185000*0.025 + 3300*2) * 10 / 1e6 = 0.11225 -> $0.11
// Opus 5.5 at 0.05x:  (185000*0.05  + 3300*2) *  4 / 1e6 = 0.0634  -> $0.06
// Fable 5.2 at .025x: (185000*0.025 + 3300*2) *  8 / 1e6 = 0.0898  -> $0.09
// Sonnet 5.5 at .05x: (185000*0.05  + 3300*2) *  2 / 1e6 = 0.0317  -> $0.03
for (const [id, expected] of [
  ["claude-fable-5-2", "$0.09"],
  ["claude-mythos-5-2", "$0.09"],
  ["claude-sonnet-5-5", "$0.03"],
  ["claude-fable-5", "$0.25"],
  ["claude-mythos-5", "$0.25"],
  ["claude-fable-5-1", "$0.11"],
  ["claude-mythos-5-1", "$0.11"],
  ["claude-fable-5[1m]", "$0.25"],
  ["claude-fable-5-1[1m]", "$0.11"],
  ["claude-opus-5-5", "$0.06"],
  ["claude-opus-5-5[1m]", "$0.06"],
]) {
  const out = plain(render(base({ model: { id } })));
  has(`${id} prices a cache read at ${expected}`, out, "next " + expected);
}

// Opus 5 reads at the standard 0.1x:
// (185000*0.1 + 3300*2) * 5 / 1e6 = 0.1255 -> $0.13
has("opus 5 reads at 0.1x", plain(render(base())), "next $0.13");

// ---- fast mode -----------------------------------------------------------
// Opus 5 in fast mode bills $10/$50 with the cache multipliers on that base.
// last, 1h: (2100*10 + 5000*10*2 + 180000*10*0.1 + 1200*50)/1e6
//   = (21000 + 100000 + 180000 + 60000)/1e6 = 0.361 -> $0.36
// next, warm: (185000*0.1 + 3300*2) * 10 / 1e6 = 0.251 -> $0.25
{
  const out = plain(render(base({ fast_mode: true })));
  has("opus 5 fast mode prices last at $0.36", out, "last $0.36");
  has("opus 5 fast mode prices next at $0.25", out, "next $0.25");
}
// Opus 5.5 bills fast mode at $8/$40, and its 0.05x read stacks on that base.
// standard last, 1h: (2100*4 + 5000*4*2 + 180000*4*0.05 + 1200*20)/1e6
//   = (8400 + 40000 + 36000 + 24000)/1e6 = 0.1084 -> $0.11
// fast last, 1h: (2100*8 + 5000*8*2 + 180000*8*0.05 + 1200*40)/1e6
//   = (16800 + 80000 + 72000 + 48000)/1e6 = 0.2168 -> $0.22
// fast next, warm: (185000*0.05 + 3300*2) * 8 / 1e6 = 0.1268 -> $0.13
//
// Fable 5.2 bills fast mode at $16/$80, and its 0.025x read stacks on that
// base. Mythos 5.2 carries the same row.
// standard last, 1h: (2100*8 + 5000*8*2 + 180000*8*0.025 + 1200*40)/1e6
//   = (16800 + 80000 + 36000 + 48000)/1e6 = 0.1808 -> $0.18
// fast last, 1h: (2100*16 + 5000*16*2 + 180000*16*0.025 + 1200*80)/1e6
//   = (33600 + 160000 + 72000 + 96000)/1e6 = 0.3616 -> $0.36
// fast next, warm: (185000*0.025 + 3300*2) * 16 / 1e6 = 0.1796 -> $0.18
for (const [id, standard, fast, next] of [
  ["claude-opus-5-5", "$0.11", "$0.22", "$0.13"],
  ["claude-fable-5-2", "$0.18", "$0.36", "$0.18"],
  ["claude-mythos-5-2", "$0.18", "$0.36", "$0.18"],
]) {
  const model = { id };
  has(
    `${id} standard prices last at ${standard}`,
    plain(render(base({ model, fast_mode: false }))),
    "last " + standard,
  );
  const out = plain(render(base({ model, fast_mode: true })));
  has(`${id} fast mode prices last at ${fast}`, out, "last " + fast);
  has(`${id} fast mode prices next at ${next}`, out, "next " + next);
}
// Sonnet 5 and Sonnet 5.5 have no fast mode, so the toggle changes nothing.
// They differ in the cache read alone: 0.1x on Sonnet 5, 0.05x on Sonnet 5.5.
// Sonnet 5 last, 1h: (2100*2 + 5000*2*2 + 180000*2*0.1 + 1200*10)/1e6
//   = (4200 + 20000 + 36000 + 12000)/1e6 = 0.0722 -> $0.07
// Sonnet 5 next, warm: (185000*0.1 + 3300*2) * 2 / 1e6 = 0.0502 -> $0.05
// Sonnet 5.5 last, 1h: (2100*2 + 5000*2*2 + 180000*2*0.05 + 1200*10)/1e6
//   = (4200 + 20000 + 18000 + 12000)/1e6 = 0.0542 -> $0.05
// Sonnet 5.5 next, warm: (185000*0.05 + 3300*2) * 2 / 1e6 = 0.0317 -> $0.03
for (const [id, last, next] of [
  ["claude-sonnet-5", "$0.07", "$0.05"],
  ["claude-sonnet-5-5", "$0.05", "$0.03"],
])
  for (const fast_mode of [true, false]) {
    const out = plain(render(base({ model: { id }, fast_mode })));
    has(`${id}, fast_mode ${fast_mode}: last is ${last}`, out, "last " + last);
    has(`${id}, fast_mode ${fast_mode}: next is ${next}`, out, "next " + next);
  }
has(
  "opus 5 with fast_mode false bills the standard rate",
  plain(render(base({ fast_mode: false }))),
  "last $0.18",
);

// ---- the measured last request -------------------------------------------
// 1h: (2100*5 + 5000*5*2 + 180000*5*0.1 + 1200*25)/1e6
//   = (10500 + 50000 + 90000 + 30000)/1e6 = 0.1805 -> $0.18
has("last, 1h TTL, is $0.18", plain(render(base())), "last $0.18");

// 5m: (10500 + 5000*5*1.25 + 90000 + 30000)/1e6
//   = (10500 + 31250 + 90000 + 30000)/1e6 = 0.16175 -> $0.16
has(
  "last, 5m TTL, is $0.16",
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
  "last $0.16",
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
// next at the plain input rate, last output included:
// (187100 + 1200)/1e6 * 5 = 0.9415 -> $0.94, in grey.
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
// The cold prefix and the last response's output are both written next time:
// (200000 + 1200)/1e6 * 5 * 2 = 2.012 -> $2.01, in red.
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
  has(
    "cold cache prices the recache and the last output at $2.01",
    plain(raw),
    "next $2.01",
  );
  has("cold cache prints red", raw, RED + "$2.01" + OFF);
  has("cold cache still says cold", plain(raw), "cache cold");
}

// Right after a compaction current_usage is null too, and the cold figures come
// from prompt_cache alone, so they must survive it. No output is known then:
// 200000/1e6 * 5 * 2 = 2.00 -> $2.00.
for (const [name, recache, expected] of [
  ["a known recache", 200000, "next $2.00"],
  ["an unknown recache", null, "next ?"],
]) {
  const raw = render(
    base({
      context_window: { context_window_size: 1000000, current_usage: null },
      prompt_cache: {
        caching_observed: true,
        warm: false,
        ttl: "1h",
        recache_tokens_if_cold: recache,
      },
    }),
  );
  has(`${name} with no current_usage still prints`, plain(raw), expected);
  has(
    `${name} with no current_usage is red`,
    raw,
    RED + expected.slice(5) + OFF,
  );
  lacks(`${name} with no current_usage prices no last`, plain(raw), "last ");
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

// ---- Haiku 5.5, priced by prompt length ---------------------------------
// A request whose prompt is over 100,000 tokens pays $0.50/$2.50 in place of
// $0.10/$0.50, and the prompt is every input token: uncached, cache writes and
// cache reads. Each request is priced on its own, so `last` and `next` can
// land on different sides. The TTL is 5m here, a 1.25x write.
{
  const haiku = (current_usage, prompt_cache = {}) =>
    plain(
      render(
        base({
          model: { id: "claude-haiku-5-5" },
          context_window: { context_window_size: 1000000, current_usage },
          prompt_cache: {
            caching_observed: true,
            warm: true,
            ttl: "5m",
            hit_ratio: 0.9,
            ...prompt_cache,
          },
        }),
      ),
    );
  const tokens = (input_tokens, cache_read_input_tokens) => ({
    input_tokens,
    cache_creation_input_tokens: 0,
    cache_read_input_tokens,
    output_tokens: 20000,
  });

  // A 50,000-token prompt, and 70,000 once the output joins it: both short.
  // last: (10000*0.1 + 40000*0.1*0.1 + 20000*0.5)/1e6 = 0.0114 -> $0.01
  // next: (40000*0.1 + 30000*1.25) * 0.1 / 1e6 = 0.00415 -> <$0.01
  {
    const out = haiku(tokens(10000, 40000));
    has("haiku 5.5 prices a short prompt at the lower rate", out, "last $0.01");
    has("haiku 5.5 prices a short next at the lower rate", out, "next <$0.01");
  }
  // Exactly 100,000 is not over, so `last` stays at the lower rate. The output
  // then makes the next prompt 120,000, which is.
  // last: (10000*0.1 + 90000*0.1*0.1 + 20000*0.5)/1e6 = 0.0119 -> $0.01
  // next: (90000*0.1 + 30000*1.25) * 0.5 / 1e6 = 0.02325 -> $0.02
  {
    const out = haiku(tokens(10000, 90000));
    has(
      "haiku 5.5 at exactly 100,000 stays at the lower rate",
      out,
      "last $0.01",
    );
    has(
      "haiku 5.5 prices a next over 100,000 at the higher rate",
      out,
      "next $0.02",
    );
  }
  // One token more is over.
  // last: (10001*0.5 + 90000*0.5*0.1 + 20000*2.5)/1e6 = 0.0595005 -> $0.06
  has(
    "haiku 5.5 at 100,001 pays the higher rate",
    haiku(tokens(10001, 90000)),
    "last $0.06",
  );
  // A cache write is part of the prompt: 10000 + 30000 + 60001 = 100,001.
  // last: (10000*0.5 + 30000*0.5*1.25 + 60001*0.5*0.1 + 20000*2.5)/1e6
  //   = (5000 + 18750 + 3000.05 + 50000)/1e6 = 0.07675005 -> $0.08
  has(
    "haiku 5.5 counts cache writes in the prompt length",
    haiku({
      input_tokens: 10000,
      cache_creation_input_tokens: 30000,
      cache_read_input_tokens: 60001,
      output_tokens: 20000,
    }),
    "last $0.08",
  );
  // With no cache observed the next prompt is the whole context, 120,000.
  // next: 120000 * 0.5 / 1e6 = 0.06 -> $0.06
  has(
    "haiku 5.5 prices an unobserved next over 100,000 at the higher rate",
    haiku(tokens(10000, 90000), { caching_observed: false }),
    "next $0.06",
  );

  // Cold, `recache_tokens_if_cold` is the last request's input and leaves its
  // output out, so the next prompt is the two together, all of it written.
  // 1h, a 2x write.
  const cold = (current_usage, recache_tokens_if_cold) =>
    haiku(current_usage, { warm: false, ttl: "1h", recache_tokens_if_cold });
  // 100,000 to re-cache and 20,000 of output make a 120,000 prompt.
  // next: 120000 * 2 * 0.5 / 1e6 = 0.12 -> $0.12
  has(
    "haiku 5.5 prices a cold next over 100,000 at the higher rate",
    cold(tokens(10000, 90000), 100000),
    "next $0.12",
  );
  // 90,000 and 20,000 make 110,000, so the output alone carries the prompt
  // over. next: 110000 * 2 * 0.5 / 1e6 = 0.11 -> $0.11
  has(
    "haiku 5.5 picks a cold rate from the recache and the last output",
    cold(tokens(10000, 80000), 90000),
    "next $0.11",
  );
  // 50,000 and 20,000 make 70,000. next: 70000 * 2 * 0.1 / 1e6 = 0.014 -> $0.01
  has(
    "haiku 5.5 prices a short cold next at the lower rate",
    cold(tokens(10000, 40000), 50000),
    "next $0.01",
  );
  // With no current_usage the recache is all there is to measure.
  // 120000 * 2 * 0.5 / 1e6 = 0.12 -> $0.12
  // 100000 * 2 * 0.1 / 1e6 = 0.02 -> $0.02
  has(
    "haiku 5.5 with no usage prices a cold 120,000 at the higher rate",
    cold(null, 120000),
    "next $0.12",
  );
  has(
    "haiku 5.5 with no usage prices a cold 100,000 at the lower rate",
    cold(null, 100000),
    "next $0.02",
  );
}

// ---- the context percentage ----------------------------------------------
// 187,100 tokens of context in a 1,000,000 window. The percentage measures
// against the auto-compact window less the 33,000 reserve, and that window is
// the model's unless the CLAUDE_CODE_AUTO_COMPACT_WINDOW variable or
// `autoCompactWindow` in a settings file names a smaller one.
// 1,000,000 window:  187100 / (1000000 - 33000) =  19.3% ->  19%
// 500,000 window:    187100 / ( 500000 - 33000) =  40.1% ->  40%
// 350,000 window:    187100 / ( 350000 - 33000) =  59.0% ->  59%
// 200,000 window:    187100 / ( 200000 - 33000) = 112.0% -> 112%
// 100,000 window:    187100 / ( 100000 - 33000) = 279.3% -> 279%
{
  const ctx = (settings, env, payload = base()) =>
    plain(render(payload, "run", { settings, env }));
  has("no settings file measures against the model window", ctx(), "ctx 19%");

  // A top-level window of 350,000 beside a per-model entry for the model in
  // `base`. Claude Code takes an integer from 100,000 to 1,000,000 and reads
  // any other number as no setting; 33,000 is the value that would divide by
  // zero.
  const perModel = (window) => ({
    autoCompactWindow: 350000,
    modelSettings: { "claude-opus-5": { autoCompactWindow: window } },
  });
  for (const [name, settings, expected] of [
    [
      "a top-level autoCompactWindow sets the window",
      { autoCompactWindow: 350000 },
      "ctx 59%",
    ],
    [
      "a per-model autoCompactWindow wins over the top-level one",
      perModel(500000),
      "ctx 40%",
    ],
    [
      "another model's autoCompactWindow is not used",
      { modelSettings: { "claude-fable-5-2": { autoCompactWindow: 350000 } } },
      "ctx 19%",
    ],
    [
      'autoCompactWindow "auto" measures against the model window',
      { autoCompactWindow: "auto" },
      "ctx 19%",
    ],
    [
      'a per-model "auto" sets the top-level window aside',
      perModel("auto"),
      "ctx 19%",
    ],
    [
      "a per-model window out of range leaves the top-level one",
      perModel(50000),
      "ctx 59%",
    ],
    ...[33000, 30000, 99999, 350000.5].map((window) => [
      `autoCompactWindow ${window} is no setting`,
      { autoCompactWindow: window },
      "ctx 19%",
    ]),
  ])
    has(name, ctx(JSON.stringify(settings)), expected);
  has(
    "a window above the model's is capped at the model's",
    ctx(
      JSON.stringify({ autoCompactWindow: 350000 }),
      undefined,
      base({
        context_window: { context_window_size: 200000, current_usage: usage },
      }),
    ),
    "ctx 112%",
  );
  has(
    "an unreadable settings file measures against the model window",
    ctx("{ not json"),
    "ctx 19%",
  );

  // The variable wins over the settings file, in every spelling Claude Code
  // reads. A size under 100,000 counts as 100,000 and one over 1,000,000 as
  // 1,000,000; a value that is no size at all leaves the settings file.
  const settings = JSON.stringify({ autoCompactWindow: 350000 });
  for (const [value, expected] of [
    ["200000", "ctx 112%"],
    ["200k", "ctx 112%"],
    [" 200K ", "ctx 112%"],
    ["0.5m", "ctx 40%"],
    ["200,000", "ctx 112%"],
    ["200_000", "ctx 112%"],
    ["2e5", "ctx 112%"],
    ["200000 tokens", "ctx 112%"],
    ["50000", "ctx 279%"],
    ["5m", "ctx 19%"],
    ["nonsense", "ctx 59%"],
    ["0", "ctx 59%"],
    // A no-break space groups thousands as a comma does.
    ["200" + String.fromCharCode(0xa0) + "000", "ctx 112%"],
    // An exponent that does not come to a whole number is no size.
    ["15e-1", "ctx 59%"],
    // Past 32 characters grouping is not read: the leading digits are 000.
    ["000,".repeat(8) + "200,000", "ctx 59%"],
    ["", "ctx 59%"],
  ])
    has(
      `CLAUDE_CODE_AUTO_COMPACT_WINDOW=${JSON.stringify(value)} gives ${expected}`,
      ctx(settings, { CLAUDE_CODE_AUTO_COMPACT_WINDOW: value }),
      expected,
    );
  has(
    "the variable alone sets the window",
    ctx(undefined, { CLAUDE_CODE_AUTO_COMPACT_WINDOW: "500k" }),
    "ctx 40%",
  );

  // A `modelSettings` key matches the model under its own name or with
  // "[1m]" behind it, in either case. The plain name wins wherever it stands;
  // among the others the first one does, and an entry that names no window
  // is passed over.
  const keyed = (...entries) =>
    JSON.stringify({
      autoCompactWindow: 350000,
      modelSettings: Object.fromEntries(
        entries.map(([key, window]) => [key, { autoCompactWindow: window }]),
      ),
    });
  for (const [name, entries, expected] of [
    ["a [1m] key names the model", [["claude-opus-5[1m]", 500000]], "ctx 40%"],
    ["a [1M] key names the model", [["claude-opus-5[1M]", 500000]], "ctx 40%"],
    [
      "the plain key wins over a [1m] key before it",
      [
        ["claude-opus-5[1m]", 200000],
        ["claude-opus-5", 500000],
      ],
      "ctx 40%",
    ],
    [
      "the plain key wins over a [1m] key after it",
      [
        ["claude-opus-5", 500000],
        ["claude-opus-5[1m]", 200000],
      ],
      "ctx 40%",
    ],
    [
      "the first of two [1m] keys wins",
      [
        ["claude-opus-5[1m]", 500000],
        ["claude-opus-5[1M]", 200000],
      ],
      "ctx 40%",
    ],
    [
      "a [1m] key that names no window is passed over",
      [
        ["claude-opus-5[1m]", 50000],
        ["claude-opus-5[1M]", 500000],
      ],
      "ctx 40%",
    ],
    [
      "a plain key that names no window leaves a [1m] key",
      [
        ["claude-opus-5", 50000],
        ["claude-opus-5[1m]", 500000],
      ],
      "ctx 40%",
    ],
    [
      "a key with another model's name in front is not the model",
      [["claude-opus-5-5[1m]", 500000]],
      "ctx 59%",
    ],
  ])
    has(name, ctx(keyed(...entries)), expected);
  has(
    "a model id ending in [1m] is matched by the plain key",
    ctx(
      keyed(["claude-opus-5", 500000]),
      undefined,
      base({ model: { id: "claude-opus-5[1m]", display_name: "Opus 5" } }),
    ),
    "ctx 40%",
  );

  // A project's two settings files rank above the user's, the local one
  // highest. `project` builds the directory and the payload that names it.
  const project = ({ shared, local, payload = base() } = {}) => {
    const dir = mkdtempSync(join(TMP, "project-"));
    mkdirSync(join(dir, ".claude"));
    for (const [file, text] of [
      ["settings.json", shared],
      ["settings.local.json", local],
    ])
      if (text !== undefined)
        writeFileSync(
          join(dir, ".claude", file),
          typeof text === "string" ? text : JSON.stringify(text),
        );
    return { ...payload, workspace: { current_dir: dir, project_dir: dir } };
  };
  const opus5 = (window) => ({
    modelSettings: { "claude-opus-5": { autoCompactWindow: window } },
  });
  for (const [name, user, files, expected] of [
    [
      "a project window wins over the user's",
      { autoCompactWindow: 350000 },
      { shared: { autoCompactWindow: 500000 } },
      "ctx 40%",
    ],
    [
      "a local project window wins over the shared one",
      { autoCompactWindow: 350000 },
      {
        shared: { autoCompactWindow: 500000 },
        local: { autoCompactWindow: 200000 },
      },
      "ctx 112%",
    ],
    [
      "a project with no settings files leaves the user's window",
      { autoCompactWindow: 350000 },
      {},
      "ctx 59%",
    ],
    [
      "an unreadable project file leaves the user's window",
      { autoCompactWindow: 350000 },
      { shared: "{ not json" },
      "ctx 59%",
    ],
    // A file that names a top-level window replaces what the files under it
    // said for the model.
    [
      "a project top-level window replaces the user's per-model one",
      opus5(500000),
      { shared: { autoCompactWindow: 200000 } },
      "ctx 112%",
    ],
    // One that names none adds its per-model entries to theirs.
    [
      "a project per-model window wins over the user's top-level one",
      { autoCompactWindow: 350000 },
      { shared: opus5(500000) },
      "ctx 40%",
    ],
    [
      "a project per-model window wins over the user's per-model one",
      opus5(200000),
      { shared: opus5(500000) },
      "ctx 40%",
    ],
    [
      "a project entry for another model leaves the user's per-model window",
      opus5(500000),
      {
        shared: {
          modelSettings: { "claude-fable-5-2": { autoCompactWindow: 200000 } },
        },
      },
      "ctx 40%",
    ],
    [
      'a project per-model "auto" sets the user\'s top-level window aside',
      { autoCompactWindow: 350000 },
      { shared: opus5("auto") },
      "ctx 19%",
    ],
    // A value out of range is no setting before the files are ranked.
    [
      "a project top-level window out of range replaces nothing",
      opus5(500000),
      { shared: { autoCompactWindow: 50000 } },
      "ctx 40%",
    ],
  ])
    has(
      name,
      plain(render(project(files), "run", { settings: JSON.stringify(user) })),
      expected,
    );
  has(
    "the variable wins over a project window",
    plain(
      render(project({ shared: { autoCompactWindow: 500000 } }), "run", {
        env: { CLAUDE_CODE_AUTO_COMPACT_WINDOW: "200k" },
      }),
    ),
    "ctx 112%",
  );

  // With auto-compact off the percentage measures against the model's window
  // less 23,000, whatever window is configured.
  // 1,000,000 window: 187100 / (1000000 - 23000) =  19.2% ->  19%
  // 200,000 window:   187100 / ( 200000 - 23000) = 105.7% -> 106%
  // and with it on, the 200,000 window gives 112% as above.
  const small = base({
    context_window: { context_window_size: 200000, current_usage: usage },
  });
  const off = (settings, env, payload = small) =>
    plain(
      render(payload, "run", {
        settings: settings && JSON.stringify(settings),
        env,
      }),
    );
  has(
    "autoCompactEnabled false measures against the blocking limit",
    off({ autoCompactEnabled: false }),
    "ctx 106%",
  );
  has(
    "autoCompactEnabled true measures against the auto-compact limit",
    off({ autoCompactEnabled: true }),
    "ctx 112%",
  );
  has(
    "auto-compact off sets a configured window aside",
    off({ autoCompactEnabled: false, autoCompactWindow: 350000 }, {}, base()),
    "ctx 19%",
  );
  has(
    "auto-compact off sets the window variable aside",
    off(
      { autoCompactEnabled: false },
      { CLAUDE_CODE_AUTO_COMPACT_WINDOW: "350k" },
      base(),
    ),
    "ctx 19%",
  );
  for (const [variable, value, expected] of [
    ["DISABLE_AUTO_COMPACT", "1", "ctx 106%"],
    ["DISABLE_AUTO_COMPACT", "true", "ctx 106%"],
    ["DISABLE_AUTO_COMPACT", " ON ", "ctx 106%"],
    ["DISABLE_AUTO_COMPACT", "yes", "ctx 106%"],
    ["DISABLE_AUTO_COMPACT", "0", "ctx 112%"],
    ["DISABLE_AUTO_COMPACT", "false", "ctx 112%"],
    ["DISABLE_AUTO_COMPACT", "", "ctx 112%"],
    ["DISABLE_COMPACT", "1", "ctx 106%"],
    ["DISABLE_COMPACT", "0", "ctx 112%"],
  ])
    has(
      `${variable}=${JSON.stringify(value)} gives ${expected}`,
      off({ autoCompactEnabled: true }, { [variable]: value }),
      expected,
    );
  // The highest-ranking file that names the switch decides.
  for (const [name, user, files, expected] of [
    [
      "a project autoCompactEnabled false wins over the user's true",
      { autoCompactEnabled: true },
      { shared: { autoCompactEnabled: false } },
      "ctx 106%",
    ],
    [
      "a project autoCompactEnabled true wins over the user's false",
      { autoCompactEnabled: false },
      { shared: { autoCompactEnabled: true } },
      "ctx 112%",
    ],
    [
      "a local autoCompactEnabled wins over the shared one",
      { autoCompactEnabled: true },
      {
        shared: { autoCompactEnabled: false },
        local: { autoCompactEnabled: true },
      },
      "ctx 112%",
    ],
    [
      "a project file that does not name the switch leaves the user's",
      { autoCompactEnabled: false },
      { shared: { autoCompactWindow: 500000 } },
      "ctx 106%",
    ],
    [
      "a switch that is neither true nor false leaves the user's",
      { autoCompactEnabled: false },
      { shared: { autoCompactEnabled: "yes" } },
      "ctx 106%",
    ],
  ])
    has(
      name,
      plain(
        render(project({ ...files, payload: small }), "run", {
          settings: JSON.stringify(user),
        }),
      ),
      expected,
    );
}

// ---- the worktree mark ----------------------------------------------------
// git decides, asked about `workspace.current_dir`, and the top-level
// `worktree` object decides for a directory git does not know. `mark` builds
// the payload ccstatusline 2.2.29 forwards to a custom-command widget:
// `workspace` arrives with `current_dir` and `project_dir` and nothing else.
// A test that sets `workspace.git_worktree` passes on a script that marks
// nothing once installed, so each git case below is a real directory git can
// be asked about.
{
  const root = mkdtempSync(join(TMP, "worktree-"));
  // The fixture's git inherits nothing. Under an inherited GIT_DIR, `git
  // init` and `git commit` act on the repository that variable names, which
  // is not the fixture. The user's git config is kept out too, so a signing or
  // hook setting cannot fail the fixture. `protocol.file.allow` lets the
  // submodule clone a path.
  const git = (...args) => {
    const r = spawnSync(
      "git",
      [
        "-c",
        "protocol.file.allow=always",
        "-c",
        "user.name=test",
        "-c",
        "user.email=test@example.invalid",
        ...args,
      ],
      {
        encoding: "utf8",
        env: { ...ENV, GIT_CONFIG_GLOBAL: devNull, GIT_CONFIG_SYSTEM: devNull },
      },
    );
    if (r.status !== 0) throw new Error(`git ${args.join(" ")}: ${r.stderr}`);
  };
  const mark = (dir, { worktree, env } = {}) =>
    render(
      { workspace: { current_dir: dir, project_dir: dir }, worktree },
      "worktree",
      { env },
    );

  const main = join(root, "main");
  const linked = join(root, "linked");
  const library = join(root, "library");
  // A newline is legal in a path, and git prints one path per line.
  const mainOddPath = join(root, "main\nodd");
  const linkedOddPath = join(root, "linked\nodd");
  for (const repo of [main, library, mainOddPath]) {
    git("init", "-q", repo);
    git("-C", repo, "commit", "-q", "--allow-empty", "-m", "init");
  }
  git("-C", main, "worktree", "add", "-q", linked);
  // The branch is named here because git would take it from the path.
  git("-C", main, "worktree", "add", "-q", "-b", "odd", linkedOddPath);
  git("-C", main, "submodule", "add", "-q", library, "module");
  mkdirSync(join(linked, "deep"));
  mkdirSync(join(main, "plain"));
  // A worktree some other version-control system made: no git inside.
  const foreign = join(root, "foreign");
  mkdirSync(join(foreign, "deep"), { recursive: true });
  mkdirSync(join(root, "foreign-sibling"));

  ok("a linked worktree prints the mark", mark(linked) === "🌿");
  ok(
    "a subdirectory of a linked worktree prints the mark",
    mark(join(linked, "deep")) === "🌿",
  );
  ok("the main checkout prints nothing", mark(main) === "");
  ok(
    "a plain directory inside the main checkout prints nothing",
    mark(join(main, "plain")) === "",
  );
  ok("a submodule prints nothing", mark(join(main, "module")) === "");
  ok(
    "a directory that does not exist prints nothing",
    mark(join(root, "absent")) === "",
  );
  ok("a directory outside any repository prints nothing", mark(root) === "");
  ok(
    "a payload with no workspace prints nothing",
    render({}, "worktree") === "",
  );
  ok(
    "a main checkout with a newline in its path prints nothing",
    mark(mainOddPath) === "",
  );
  ok(
    "a linked worktree with a newline in its path prints the mark",
    mark(linkedOddPath) === "🌿",
  );

  // An inherited GIT_DIR names a repository of its own, and the question is
  // about the directory. Each case points the variable at the other kind.
  ok(
    "a linked worktree prints the mark under a GIT_DIR naming the main checkout",
    mark(linked, { env: { GIT_DIR: join(main, ".git") } }) === "🌿",
  );
  ok(
    "the main checkout prints nothing under a GIT_DIR naming a linked worktree",
    mark(main, {
      env: { GIT_DIR: join(main, ".git", "worktrees", "linked") },
    }) === "",
  );

  // A git that does not know `--path-format`. `rev-parse` prints a flag it
  // does not know and exits 0, as git 2.55.0 does with a made-up one, so two
  // equal relative paths arrive behind the flag.
  const oldGit = join(root, "old-git");
  mkdirSync(oldGit);
  writeFileSync(
    join(oldGit, "git"),
    [
      "#!/bin/sh",
      'case "$*" in',
      "*--local-env-vars*) exit 0 ;;",
      "*) printf '%s\\n' --path-format=absolute .git .git ;;",
      "esac",
      "",
    ].join("\n"),
    { mode: 0o755 },
  );
  ok(
    "the main checkout prints nothing under a git that does not know --path-format",
    mark(main, { env: { PATH: oldGit + delimiter + ENV.PATH } }) === "",
  );

  // The session's worktree counts only while the directory is inside its
  // path.
  const session = { name: "foreign", path: foreign };
  ok(
    "a session worktree outside git prints the mark",
    mark(foreign, { worktree: session }) === "🌿",
  );
  ok(
    "a subdirectory of a session worktree prints the mark",
    mark(join(foreign, "deep"), { worktree: session }) === "🌿",
  );
  ok(
    "a directory outside the session worktree prints nothing",
    mark(root, { worktree: session }) === "",
  );
  ok(
    "a sibling whose name starts with the worktree's prints nothing",
    mark(join(root, "foreign-sibling"), { worktree: session }) === "",
  );
  ok(
    "the main checkout prints nothing while a session worktree is elsewhere",
    mark(main, { worktree: session }) === "",
  );

  // The payload may spell one directory two ways: through a symbolic link,
  // or with a separator at its end.
  const alias = join(root, "alias");
  symlinkSync(foreign, alias);
  ok(
    "a session worktree named through a symbolic link prints the mark",
    mark(foreign, { worktree: { name: "foreign", path: alias } }) === "🌿",
  );
  ok(
    "a directory reached through a symbolic link into the session worktree prints the mark",
    mark(join(alias, "deep"), { worktree: session }) === "🌿",
  );
  ok(
    "a session worktree path ending in a separator prints the mark",
    mark(foreign, { worktree: { name: "foreign", path: foreign + sep } }) ===
      "🌿",
  );
  ok(
    "a sibling prints nothing while the session worktree is named through a symbolic link",
    mark(join(root, "foreign-sibling"), {
      worktree: { name: "foreign", path: alias },
    }) === "",
  );
}

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
