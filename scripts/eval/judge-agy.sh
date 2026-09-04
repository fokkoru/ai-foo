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
for f in "$DIR"/*.md; do
  ID="$(basename "$f" .md)"
  P="$(mktemp)"; printf '%s\n\n%s\n' "$(cat "$RUBRIC")" "$(cat "$f")" > "$P"
  agy -p "$(cat "$P")" --model "$MODEL" --output-format json \
      --json-schema "$SCHEMA" 2>/dev/null \
  | python3 -c '
import csv, json, sys
rid, model = sys.argv[1], sys.argv[2]
try:
    out = json.load(sys.stdin).get("structured_output")
except (json.JSONDecodeError, ValueError):
    out = None
w = csv.writer(sys.stdout)
if out is None:
    # No structured output means the schema was not satisfied. Record it as a
    # failure so it is re-judged, never as a zero: a zero would silently pull
    # the arm mean down.
    w.writerow([rid, model, "ERROR", ""])
else:
    w.writerow([rid, model, out["count"], " | ".join(out["phrases"])])
' "$ID" "$MODEL" >> "$OUT"
  rm -f "$P"
done
echo "wrote $OUT"
grep -c ',ERROR,' "$OUT" | xargs -I{} echo "{} rows need re-judging"
