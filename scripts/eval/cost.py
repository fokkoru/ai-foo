#!/usr/bin/env python3
"""Resource use per (arm, model, cell) from the raw result JSONs.

Reads every `<arm>_<model>_<cell>_<rep>.json` in a results directory and reports
cost, wall clock, turns and token counts. `run.sh` writes a subset of these to
`results/cost.tsv`, but the raw JSON carries all of it, so this script also works
on a run whose `cost.tsv` predates that extraction.

    python3 cost.py <results-dir> [parallelism]

Parallelism is only used to divide the serial wall time into a projection. With
no argument the projection is left out rather than guessed.
"""

import glob
import json
import os
import statistics as st
import sys
from collections import defaultdict

from ids import parse_id

if not 2 <= len(sys.argv) <= 3:
    sys.exit("usage: cost.py <results-dir> [parallelism]")
D = os.path.abspath(sys.argv[1])
PAR = None
if len(sys.argv) == 3:
    if not sys.argv[2].isdigit() or int(sys.argv[2]) < 1:
        sys.exit(f"parallelism must be a positive integer, got {sys.argv[2]!r}")
    PAR = int(sys.argv[2])

FIELDS = [
    ("cost", "cost $", "{:.3f}"),
    ("dur_s", "wall s", "{:.1f}"),
    ("turns", "turns", "{:.0f}"),
    ("out_tok", "output tok", "{:,.0f}"),
    ("cache_read", "cache read", "{:,.0f}"),
]

rows = []
skipped = []
for path in sorted(glob.glob(os.path.join(D, "*.json"))):
    name = os.path.basename(path)[:-5]
    parts = parse_id(name)
    if parts is None:
        skipped.append(name)
        continue
    try:
        events = json.load(open(path, encoding="utf-8"))
        res = [e for e in events if isinstance(e, dict) and e.get("type") == "result"]
        if not res:
            skipped.append(name + " (no result event)")
            continue
        res = res[-1]
    except (json.JSONDecodeError, OSError) as exc:
        skipped.append(f"{name} ({exc})")
        continue
    usage = res.get("usage") or {}
    rows.append(
        {
            "arm": parts[0],
            "model": parts[1],
            "cell": parts[2],
            "cost": res.get("total_cost_usd", 0.0),
            "dur_s": res.get("duration_ms", 0) / 1000,
            "turns": res.get("num_turns", 0),
            "out_tok": usage.get("output_tokens", 0),
            "cache_read": usage.get("cache_read_input_tokens", 0),
            "cache_write": usage.get("cache_creation_input_tokens", 0),
            "input": usage.get("input_tokens", 0),
        }
    )

if not rows:
    sys.exit(f"no result JSONs under {D}")

print(f"{len(rows)} runs under {D}")
if skipped:
    print("skipped: " + ", ".join(skipped))


def block(title, key):
    groups = defaultdict(list)
    for r in rows:
        groups[r[key]].append(r)
    head = f"\n{title:<14}{'n':>5}" + "".join(f"{lab:>13}" for _, lab, _ in FIELDS)
    print(head)
    for name in sorted(groups):
        g = groups[name]
        cells = "".join(
            fmt.format(st.median([r[f] for r in g])).rjust(13) for f, _, fmt in FIELDS
        )
        print(f"{name:<14}{len(g):>5}{cells}")


block("model", "model")
block("arm", "arm")

per_cell = defaultdict(list)
for r in rows:
    per_cell[(r["model"], r["cell"])].append(r)
print(f"\n{'model/cell':<14}{'n':>5}{'cost $':>13}{'wall s':>13}{'turns':>13}")
def cell_order(key):
    """Numeric cells sort numerically; named cells such as `smoke` sort after them."""
    model, cell = key
    return (model, 0, int(cell)) if cell.isdigit() else (model, 1, 0)


for (m, c) in sorted(per_cell, key=cell_order):
    g = per_cell[(m, c)]
    print(
        f"{m + '/' + c:<14}{len(g):>5}"
        f"{st.median([r['cost'] for r in g]):>13.3f}"
        f"{st.median([r['dur_s'] for r in g]):>13.1f}"
        f"{st.median([r['turns'] for r in g]):>13.0f}"
    )

serial_h = sum(r["dur_s"] for r in rows) / 3600
cr = sum(r["cache_read"] for r in rows)
cw = sum(r["cache_write"] for r in rows)
un = sum(r["input"] for r in rows)
print(f"\ntotal cost: ${sum(r['cost'] for r in rows):.2f}")
proj = f"  (at parallelism {PAR}: {serial_h / PAR:.2f} h)" if PAR else ""
print(f"serial wall time: {serial_h:.2f} h{proj}")
print(
    f"input tokens: {cr:,} cache read | {cw:,} cache write | {un:,} uncached"
    f"  -> cache read share {cr / max(cr + cw + un, 1):.1%}"
)
