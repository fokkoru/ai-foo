#!/usr/bin/env python3
"""The one rule for reading a results filename.

A response, its raw event stream and its score are all keyed on the same stem,
`<arm>_<model>_<cell>_<rep>`, built by `run.sh` from the arm with spaces turned
into underscores. The arm is the only part allowed to contain an underscore, so
a right split of exactly three separators is the whole rule.

It lives here because the three readers of a results directory each carried
their own copy and drifted: `cost.py` required an underscore inside the arm
name, which silently dropped every single-token arm the other two scored.
"""


def parse_id(stem):
    """(arm, model, cell, rep) for a well-formed stem, or None."""
    parts = stem.rsplit("_", 3)
    if len(parts) != 4 or not parts[3].isdigit():
        return None
    return tuple(parts)
