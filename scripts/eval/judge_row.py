#!/usr/bin/env python3
"""Turn one judge reply into one CSV row, or into an ERROR row.

usage: judge_row.py <review-id> <model> [envelope-key]

Reads the judge's reply as JSON on stdin and writes one CSV row on stdout. With
an envelope key, the payload is read from that key of the reply; without one,
the reply is the payload. Every judge family is held to the same contract, so
this check lives in one place rather than once per family's runner.

Anything that is not a usable answer becomes ERROR, never a zero. A zero is
indistinguishable from a clean response and pulls that arm's mean down.
"""
import csv
import json
import sys


def row(payload, rid, model):
    count, phrases = payload["count"], payload["phrases"]
    # The runtime enforces the schema, but a reply can satisfy it and still be
    # unusable: a count that is not a number, or one that disagrees with the
    # list it claims to count. A rubric asking for that agreement with nothing
    # checking it is a suggestion, so it is checked here.
    if isinstance(count, bool) or not isinstance(count, int):
        raise ValueError("count is not an integer")
    if not isinstance(phrases, list) or count != len(phrases):
        raise ValueError("count does not match phrases")
    return [rid, model, count, " | ".join(phrases)]


def main(argv):
    if not 3 <= len(argv) <= 4:
        sys.exit(__doc__.splitlines()[2])
    rid, model = argv[1], argv[2]
    key = argv[3] if len(argv) == 4 else None
    try:
        reply = json.load(sys.stdin)
        out = reply[key] if key else reply
        record = row(out, rid, model)
    except Exception:
        record = [rid, model, "ERROR", ""]
    csv.writer(sys.stdout).writerow(record)


if __name__ == "__main__":
    main(sys.argv)
