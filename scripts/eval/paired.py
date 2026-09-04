#!/usr/bin/env python3
"""Cell-paired comparison of two arms on one metric.

    python3 paired.py <results-dir> <metric> <arm-a> <arm-b> [model]

The cell is the unit of analysis, not the response. Each (model, cell) pair
contributes one number: the median of arm A's repetitions minus the median of
arm B's. Pairing removes the between-cell variance, which is the largest source
of spread in a prompt experiment, because a hard cell is hard for both arms.

Reports three things:

  - the per-pair differences, so a single dominating cell is visible rather than
    hidden inside a mean;
  - an exact two-sided sign test over the pairs, which assumes only that a
    difference is as likely to fall either way under the null;
  - a bootstrap 95% interval for the mean difference, resampled over pairs.

For a binary metric the harness also prints `1/sqrt(n·R)`, the half-width of the
paired-difference 95% CI that Anthropic's bundled eval health checklist gives as
the noise floor for a pass-rate (Claude Code 2.1.259,
`claude-api/shared/evals/eval-audit.md`, section 5). It is a reference point for
a proportion and says nothing about a continuous metric, so it is printed only
where it applies.

Arm names are matched against the underscored form in `scores.csv`, so
"AF Old" and "AF_Old" both work.
"""

import csv
import math
import os
import random
import statistics as st
import sys
from collections import defaultdict

BOOTSTRAP_RESAMPLES = 10000  # enough that the interval is stable to the printed digits


def sign_test(diffs):
    """Exact two-sided binomial p for the count of positive differences.

    Ties carry no directional information and are dropped, which is the standard
    treatment and the conservative one: they shrink n rather than pad either side.
    """
    nz = [d for d in diffs if d != 0]
    n = len(nz)
    if n == 0:
        return n, 0, float("nan")
    k = sum(1 for d in nz if d > 0)
    tail = lambda j: math.comb(n, j) * 0.5**n
    obs = tail(k)
    # Sum every outcome no more likely than the observed one. Exact, and it needs
    # no normal approximation at the pair counts a prompt experiment reaches.
    p = sum(tail(j) for j in range(n + 1) if tail(j) <= obs + 1e-12)
    return n, k, min(p, 1.0)


def bootstrap_ci(diffs, seed):
    if len(diffs) < 2:
        return float("nan"), float("nan")
    rng = random.Random(seed)
    means = []
    for _ in range(BOOTSTRAP_RESAMPLES):
        sample = [diffs[rng.randrange(len(diffs))] for _ in diffs]
        means.append(sum(sample) / len(sample))
    means.sort()
    lo = means[int(0.025 * len(means))]
    hi = means[int(0.975 * len(means)) - 1]
    return lo, hi


def main(argv):
    if len(argv) < 5:
        sys.exit("usage: paired.py <results-dir> <metric> <arm-a> <arm-b> [model]")
    path = os.path.join(os.path.abspath(argv[1]), "scores.csv")
    metric, arm_a, arm_b = argv[2], argv[3], argv[4]
    only_model = argv[5] if len(argv) > 5 else None
    norm = lambda s: s.replace(" ", "_")
    arm_a, arm_b = norm(arm_a), norm(arm_b)

    rows = list(csv.DictReader(open(path, encoding="utf-8")))
    if not rows:
        sys.exit(f"no rows in {path}")
    if metric not in rows[0]:
        sys.exit(f"no metric {metric!r} in {path}; have {sorted(set(rows[0]) - {'id'})}")

    by = defaultdict(list)
    for r in rows:
        if only_model and r["model"] != only_model:
            continue
        try:
            by[(r["arm"], r["model"], r["cell"])].append(float(r[metric]))
        except ValueError:
            sys.exit(f"metric {metric!r} is not numeric in row {r['id']}")

    pairs, reps = [], []
    for (arm, model, cell), vals in by.items():
        if arm != arm_a:
            continue
        other = by.get((arm_b, model, cell))
        if not other:
            continue
        pairs.append((model, cell, st.median(vals), st.median(other)))
        reps += [len(vals), len(other)]
    if not pairs:
        sys.exit(f"no (model, cell) is present for both {arm_a} and {arm_b}")
    pairs.sort(key=lambda p: (p[0], len(p[1]), p[1]))

    diffs = [a - b for _, _, a, b in pairs]
    print(f"{metric}: {arm_a} minus {arm_b}, {len(pairs)} cell pairs\n")
    print(f"{'model':8}{'cell':>6}{arm_a:>16}{arm_b:>16}{'diff':>10}")
    for (model, cell, a, b), d in zip(pairs, diffs):
        print(f"{model:8}{cell:>6}{a:>16.2f}{b:>16.2f}{d:>10.2f}")

    n, k, p = sign_test(diffs)
    lo, hi = bootstrap_ci(diffs, seed=len(pairs))
    print(f"\nmean difference {sum(diffs) / len(diffs):+.3f}, bootstrap 95% [{lo:+.3f}, {hi:+.3f}]")
    print(f"sign test: {k} of {n} non-tied pairs favour {arm_a}, two-sided p = {p:.2e}")
    if len(diffs) != n:
        print(f"{len(diffs) - n} tied pairs dropped")

    values = {v for vals in by.values() for v in vals}
    if values <= {0.0, 1.0}:
        R = min(reps)
        floor = 1 / math.sqrt(len(pairs) * R)
        print(
            f"\nbinary metric: reference noise floor 1/sqrt(n*R) at n={len(pairs)} cells, "
            f"R={R} reps is +-{floor * 100:.0f} points"
        )


if __name__ == "__main__":
    main(sys.argv)
