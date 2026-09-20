#!/usr/bin/env python3
"""Read a pairwise-judge CSV and report one variant's wins against the base arm.

    python3 pairs.py <pairs.csv> <variant-arm> [model]

`judge-pair.sh` writes the CSV: one row per (model, cell, rep, variant, order),
where the order is `ab` when the base answer was shown first and `ba` when the
variant was, and the verdict is the letter the judge returned or ERROR.

A repetition counts as a win only when both orders name the variant, a loss only
when both name the base, and a split otherwise. Position bias in a preference
judge is large enough that one order alone is not a reading, so a split is
reported and dropped rather than resolved.

The cell is the unit of analysis, as in `paired.py`: each (model, cell)
contributes wins minus losses over its repetitions, and the sign test runs over
those per-cell differences with the same exact two-sided binomial. The
repetition-level totals are printed too, but they are not independent
observations, because two repetitions of one cell share that cell's difficulty.
"""

import csv
import sys
from collections import defaultdict

from paired import sign_test


def main(argv):
    if len(argv) < 3:
        sys.exit("usage: pairs.py <pairs.csv> <variant-arm> [model]")
    path, variant = argv[1], argv[2].replace(" ", "_")
    only_model = argv[3] if len(argv) > 3 else None

    by = defaultdict(dict)
    errors = 0
    for r in csv.DictReader(open(path, encoding="utf-8")):
        if r["variant"] != variant or (only_model and r["model"] != only_model):
            continue
        if r["verdict"] not in ("A", "B"):
            errors += 1
            continue
        variant_pos = "B" if r["order"] == "ab" else "A"
        by[(r["model"], r["cell"], r["rep"])][r["order"]] = r["verdict"] == variant_pos
    if not by:
        sys.exit(f"no rows for variant {variant!r} in {path}")

    reps = {}
    for key, orders in by.items():
        if "ab" not in orders or "ba" not in orders:
            continue
        a, b = orders["ab"], orders["ba"]
        reps[key] = "win" if a and b else "loss" if not a and not b else "split"

    cells = defaultdict(list)
    for (model, cell, _), outcome in reps.items():
        cells[(model, cell)].append(outcome)
    diffs = []
    tw = tl = 0
    print(f"{variant} against the base arm, {len(cells)} cells\n")
    print(f"{'model':8}{'cell':28}{'reps':>5}{'win':>5}{'loss':>5}{'split':>6}")
    for (model, cell), outs in sorted(cells.items()):
        w, l, s = (outs.count(k) for k in ("win", "loss", "split"))
        diffs.append(w - l)
        tw += w == len(outs)
        tl += l == len(outs)
        print(f"{model:8}{cell:28}{len(outs):>5}{w:>5}{l:>5}{s:>6}")

    n, k, p = sign_test(diffs)
    totals = [sum(1 for o in reps.values() if o == x) for x in ("win", "loss", "split")]
    print(f"\nrepetitions: {totals[0]} win, {totals[1]} loss, {totals[2]} split (not independent)")
    print(f"cells won in every rep {tw}, lost in every rep {tl}")
    print(f"sign test over cells: {k} of {n} non-tied favour {variant}, two-sided p = {p:.3f}")
    if errors:
        print(f"{errors} ERROR rows skipped; re-run judge-pair.sh to fill them")


if __name__ == "__main__":
    main(sys.argv)
