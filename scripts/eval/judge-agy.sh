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
# One contract, one place: judge_row.py holds the check every family is held to,
# so a change to what counts as a usable answer cannot reach one runner and miss
# the other.
ROW="$(cd "$(dirname "$0")" && pwd)/judge_row.py"
for f in "$RUBRIC" "$SCHEMA" "$ROW"; do [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }; done
echo "review_id,judge_model,count,phrases" > "$OUT"
# r*.md, not *.md: mask.py writes and prunes exactly that set. And bash 3.2
# hands the loop the literal pattern when nothing matches, so an empty review
# directory would otherwise send "review/*.md" to a paid judge.
for f in "$DIR"/r*.md; do
  [ -e "$f" ] || continue
  ID="$(basename "$f" .md)"
  # A response with no non-whitespace content is not something a judge can
  # score. Measured on 2026-09-03: the Claude family answers `count: 0` on
  # whitespace, which is indistinguishable from a clean response, while the
  # Antigravity family returns nothing at all. Deciding it here rather than in
  # the rubric makes all three families agree by construction, and costs no
  # judge call.
  if ! grep -q '[^[:space:]]' "$f"; then
    printf '%s,%s,ERROR,\n' "$ID" "$MODEL" >> "$OUT"
    continue
  fi
  P="$(mktemp)"; printf '%s\n\n%s\n' "$(cat "$RUBRIC")" "$(cat "$f")" > "$P"
  agy -p "$(cat "$P")" --model "$MODEL" --output-format json \
      --json-schema "$SCHEMA" 2>/dev/null \
  | python3 "$ROW" "$ID" "$MODEL" structured_output >> "$OUT"
  rm -f "$P"
done
echo "wrote $OUT"
# grep -c exits 1 on zero matches and pipefail is set, so a clean run would
# otherwise leave this script exiting 1. Status 2 is a real failure and stays.
N_ERR="$(grep -c ',ERROR,' "$OUT")"
RC=$?
[ "$RC" -le 1 ] || { echo "grep failed reading $OUT" >&2; exit 1; }
echo "$N_ERR rows need re-judging"
