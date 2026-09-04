#!/usr/bin/env python3
"""Mechanical per-response metrics for one experiment.

    python3 score.py <results-dir>

Reads every `<arm>_<model>_<cell>_<rep>.md` in a results directory, calls
the experiment's own `metrics.score(text)` on each, and writes `scores.csv`
into that same results directory, so a run's responses and its scores stay
together and a second results directory does not overwrite the first. What counts as a metric belongs to the experiment, not to
the harness: a style experiment measures words and closing labels, an agent
experiment would measure something else entirely.

The experiment is the results directory's parent. Its `metrics.py` must define:

    def score(text: str) -> dict    # metric name -> value, same keys every call

and may define:

    LABELS: list[str]               # strings mask.py blinds before judging
    EXCLUDE_CELLS: list[str]        # cells that are harness self-checks, not
                                    # comparison cells, e.g. a smoke prompt

The printed summary is derived from the values themselves, so it needs no
knowledge of what the metrics mean: a 0/1 column gets its mean, because the
median of a mostly-zero indicator is zero and says nothing; any other number
gets its median, which is what survives one runaway response; a string column
gets the share that are non-empty.
"""

import csv
import glob
import importlib.util
import os
import statistics as st
import sys
from collections import defaultdict


def load_metrics(exp):
    path = os.path.join(exp, "metrics.py")
    if not os.path.exists(path):
        sys.exit(f"no metrics.py in {exp} — see scripts/eval/README.md")
    spec = importlib.util.spec_from_file_location("metrics", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if not hasattr(mod, "score"):
        sys.exit(f"{path} defines no score(text) function")
    return mod


def rows_for(exp, results):
    metrics = load_metrics(exp)
    exclude = set(getattr(metrics, "EXCLUDE_CELLS", []))
    rows = []
    for path in sorted(glob.glob(os.path.join(results, "*.md"))):
        stem = os.path.basename(path)[:-3]
        parts = stem.rsplit("_", 3)
        if len(parts) != 4:
            continue
        arm, model, cell, rep = parts
        if not rep.isdigit() or cell in exclude:
            continue
        text = open(path, encoding="utf-8").read().strip()
        row = dict(id=stem, arm=arm, model=model, cell=cell, rep=int(rep))
        row.update(metrics.score(text))
        rows.append(row)
    return rows


def summarise(rows):
    """One line per (arm, model). Medians for numbers, non-empty share for text."""
    keys = [k for k in rows[0] if k not in ("id", "arm", "model", "cell", "rep")]
    groups = defaultdict(list)
    for r in rows:
        groups[(r["arm"], r["model"])].append(r)
    head = f"{'arm':22}{'model':8}{'n':>4}" + "".join(f"{k:>16}" for k in keys)
    print(head)
    for key in sorted(groups):
        g = groups[key]
        cells = ""
        for k in keys:
            vals = [r[k] for r in g]
            numeric = all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in vals)
            if numeric and set(vals) <= {0, 1}:
                cells += f"{sum(vals) / len(vals):>16.2f}"
            elif numeric:
                cells += f"{st.median(vals):>16.2f}"
            else:
                cells += f"{sum(1 for v in vals if v) / len(vals):>16.2f}"
        print(f"{key[0]:22}{key[1]:8}{len(g):>4}" + cells)


def main(argv):
    if len(argv) < 2:
        sys.exit("usage: score.py <results-dir>")
    results = os.path.abspath(argv[1])
    exp = os.path.dirname(results)
    rows = rows_for(exp, results)
    if not rows:
        sys.exit(f"no scorable responses under {results}")
    out = os.path.join(results, "scores.csv")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} responses scored into {out}\n")
    summarise(rows)


if __name__ == "__main__":
    main(sys.argv)
