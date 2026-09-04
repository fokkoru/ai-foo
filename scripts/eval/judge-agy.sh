#!/usr/bin/env bash
# usage: judge-agy.sh <results-dir> <out.csv> [model]
# Scores every masked response under <results-dir>/review/ with the Antigravity
# CLI, holding it to the experiment's judge-schema.json.
#
# Read-only: no permission flags are passed, so the agent cannot edit or run
# shell. Latency was measured at 5 to 66 seconds per response and one probe
# exceeded two minutes, so this is a gate-sized judge, not a sweep-sized one.
set -uo pipefail
[ $# -ge 2 ] || { sed -n '2p' "$0" >&2; exit 2; }
RES="$(cd "$1" && pwd)"; OUT="$2"; MODEL="${3:-gemini-3.1-pro-high}"
EXP="$(dirname "$RES")"
DIR="$RES/review"
RUBRIC="$EXP/judge-rubric.txt"
SCHEMA="$EXP/judge-schema.json"
for f in "$RUBRIC" "$SCHEMA"; do [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }; done
echo "review_id,judge_model,count,phrases" > "$OUT"
# r*.md, not *.md: mask.py writes and prunes exactly that set. And bash 3.2
# hands the loop the literal pattern when nothing matches, so an empty review
# directory would otherwise send "review/*.md" to a paid judge.
for f in "$DIR"/r*.md; do
  [ -e "$f" ] || continue
  ID="$(basename "$f" .md)"
  P="$(mktemp)"; printf '%s\n\n%s\n' "$(cat "$RUBRIC")" "$(cat "$f")" > "$P"
  agy -p "$(cat "$P")" --model "$MODEL" --output-format json \
      --json-schema "$SCHEMA" 2>/dev/null \
  | python3 -c '
import csv, json, sys
rid, model = sys.argv[1], sys.argv[2]
try:
    out = json.load(sys.stdin)["structured_output"]
    count, phrases = out["count"], out["phrases"]
    # The runtime enforces the schema, but a reply can satisfy it and still be
    # unusable: a count that is not a number, or one that disagrees with the
    # list it claims to count. A rubric asking for that agreement with nothing
    # checking it is a suggestion, so it is checked here.
    if isinstance(count, bool) or not isinstance(count, int):
        raise ValueError("count is not an integer")
    if not isinstance(phrases, list) or count != len(phrases):
        raise ValueError("count does not match phrases")
    row = [rid, model, count, " | ".join(phrases)]
except Exception:
    # Anything the judge returns that is not a usable answer is one outcome:
    # record it as a failure so it is re-judged, never as a zero. A zero is
    # indistinguishable from a clean response and pulls the arm mean down.
    row = [rid, model, "ERROR", ""]
csv.writer(sys.stdout).writerow(row)
' "$ID" "$MODEL" >> "$OUT"
  rm -f "$P"
done
echo "wrote $OUT"
# grep -c exits 1 on zero matches and pipefail is set, so a clean run would
# otherwise leave this script exiting 1. Status 2 is a real failure and stays.
N_ERR="$(grep -c ',ERROR,' "$OUT")"
RC=$?
[ "$RC" -le 1 ] || { echo "grep failed reading $OUT" >&2; exit 1; }
echo "$N_ERR rows need re-judging"
