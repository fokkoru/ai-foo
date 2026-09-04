#!/usr/bin/env python3
"""Blind responses for judging.

    python3 mask.py <results-dir> <seed>

Writes one `review/rNNN.md` per response inside the results directory, holding the prompt and the response
with every arm-identifying token from `metrics.LABELS` replaced by
`[LABEL MASKED]`, and `mapping.csv` recording which response each review id is.
Shuffling is seeded so a re-mask of the same responses reproduces the same map.

Blinding is never complete. Response length, punctuation habits and vocabulary
still identify an arm to a judge that is looking, so a run reports what the
masking removed rather than claiming the judge was blind. `mapping.csv` carries
a `labels_masked` count per response so that leak is at least measured.

Refuses to overwrite an existing `mapping.csv`: judgements are keyed by review
id, so remapping silently invalidates every judgement already recorded. Delete
it deliberately to re-mask.
"""

import csv
import glob
import importlib.util
import os
import random
import re
import sys


def load_metrics(exp):
    """LABELS and EXCLUDE_CELLS from the experiment, or empty when it defines none.

    EXCLUDE_CELLS has to be honoured here as well as in score.py: a harness
    self-check is not a comparison response, and sending it to a judge both
    wastes a judging call and shifts every review id after it.
    """
    path = os.path.join(exp, "metrics.py")
    if not os.path.exists(path):
        return [], set()
    spec = importlib.util.spec_from_file_location("metrics", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return list(getattr(mod, "LABELS", [])), set(getattr(mod, "EXCLUDE_CELLS", []))


def main(argv):
    if len(argv) < 3:
        sys.exit("usage: mask.py <results-dir> <seed>")
    results = os.path.abspath(argv[1])
    exp = os.path.dirname(results)
    seed = int(argv[2])
    review = os.path.join(results, "review")
    mapping = os.path.join(results, "mapping.csv")
    if os.path.exists(mapping):
        sys.exit(f"{mapping} exists — delete it deliberately to re-mask, see the docstring")

    labels, exclude = load_metrics(exp)
    token = None
    if labels:
        alt = "|".join(re.escape(x) for x in labels)
        token = re.compile(
            rf"\*\*({alt})\*\*\s*(?:—|-|:)?\s*|\*\*({alt})\.\*\*\s*", re.I
        )

    stems = []
    for path in sorted(glob.glob(os.path.join(results, "*.md"))):
        stem = os.path.basename(path)[:-3]
        parts = stem.rsplit("_", 3)
        if len(parts) == 4 and parts[3].isdigit() and parts[2] not in exclude:
            stems.append(stem)
    if not stems:
        sys.exit(f"no responses under {results}")

    os.makedirs(review, exist_ok=True)
    order = list(range(len(stems)))
    random.Random(seed).shuffle(order)

    rows = []
    for n, i in enumerate(order, start=1):
        stem = stems[i]
        _arm, _model, cell, _rep = stem.rsplit("_", 3)
        text = open(os.path.join(results, stem + ".md"), encoding="utf-8").read().rstrip()
        masked, hits = token.subn("[LABEL MASKED] ", text) if token else (text, 0)
        prompt = open(os.path.join(exp, "prompts", f"{cell}.txt"), encoding="utf-8").read().strip()
        rid = f"r{n:03d}"
        with open(os.path.join(review, f"{rid}.md"), "w", encoding="utf-8") as f:
            f.write(f"# {rid}\n\n## Prompt\n\n{prompt}\n\n## Response\n\n{masked}\n")
        rows.append((rid, stem, hits))

    with open(mapping, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["review_id", "id", "labels_masked"])
        w.writerows(rows)
    print(f"{len(rows)} review files under {review}, seed {seed}; mapping in {mapping}")
    print(f"{sum(1 for _, _, h in rows if h)} of {len(rows)} responses had a label masked")


if __name__ == "__main__":
    main(sys.argv)
