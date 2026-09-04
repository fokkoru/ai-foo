#!/usr/bin/env bash
# usage: drive.sh <experiment-dir> <parallelism> <reps> <cell>...
# example: ARMS="AF Old|AF New" MODELS="opus fable" drive.sh <exp> 6 3 1 2 3
#
# Runs every (arm, model, cell, rep) combination that has no result yet, so an
# interrupted sweep resumes by re-running the same command.
#
# ARMS is pipe-separated because arm names contain spaces; MODELS is
# space-separated. Both default to the values in <experiment-dir>/experiment.env
# and are overridable from the environment, which is how one sweep runs a subset
# of the arms without editing the experiment.
set -uo pipefail

[ $# -ge 4 ] || { sed -n '2,3p' "$0" >&2; exit 2; }
EXP="$(cd "$1" && pwd)"; shift
P="$1"; shift
N="$1"; shift
HERE="$(cd "$(dirname "$0")" && pwd)"

ARMS_DEFAULT=""
MODELS_DEFAULT=""
if [ -f "$EXP/experiment.env" ]; then
  # shellcheck source=/dev/null
  . "$EXP/experiment.env"
fi
# Exported, not just set: run.sh reads it from the environment.
export RESULTS="${RESULTS:-results}"
# One path component, for the reason run.sh gives.
case "$RESULTS" in
"" | . | .. | */*) echo "RESULTS must be a single directory name, got '$RESULTS'" >&2; exit 2 ;;
esac
IFS='|' read -r -a ARM_ARR <<< "${ARMS:-$ARMS_DEFAULT}"
read -r -a MODEL_ARR <<< "${MODELS:-$MODELS_DEFAULT}"
[ "${#ARM_ARR[@]}" -gt 0 ] || { echo "no arms: set ARMS or ARMS_DEFAULT in $EXP/experiment.env" >&2; exit 2; }
[ "${#MODEL_ARR[@]}" -gt 0 ] || { echo "no models: set MODELS or MODELS_DEFAULT in $EXP/experiment.env" >&2; exit 2; }

# Both live inside the results directory rather than beside it, so two sweeps of
# one experiment under different RESULTS do not truncate each other's queue while
# the other loop is still reading it.
OUT="$EXP/$RESULTS"
QUEUE="$OUT/queue.tsv"
FAILLOG="$OUT/failed.log"
mkdir -p "$OUT"
: > "$QUEUE"
: > "$FAILLOG"
for A in "${ARM_ARR[@]}"; do for M in "${MODEL_ARR[@]}"; do for C in "$@"; do for R in $(seq 1 "$N"); do
  ID="$(printf '%s' "$A" | tr ' ' '_')_${M}_${C}_${R}"
  [ -s "$OUT/$ID.md" ] || printf '%s\t%s\t%s\t%s\n' "$A" "$M" "$C" "$R" >> "$QUEUE"
done; done; done; done
echo "queued $(wc -l < "$QUEUE") runs, parallelism $P"

while IFS=$'\t' read -r a m c r; do
  while [ "$(jobs -rp | wc -l)" -ge "$P" ]; do wait -n 2>/dev/null || sleep 1; done
  ( "$HERE/run.sh" "$EXP" "$a" "$m" "$c" "$r" || echo "FAILED: $a $m $c $r" | tee -a "$FAILLOG" >&2 ) &
done < "$QUEUE"
wait

# Each child's failure was swallowed by the `||` that keeps the sweep going, so
# the count comes back off the log. Without this the sweep reports DRIVE DONE and
# exits 0 however many runs never produced a response.
N_FAIL="$(wc -l < "$FAILLOG" | tr -d ' ')"
if [ "$N_FAIL" -gt 0 ]; then
  echo "DRIVE INCOMPLETE: $N_FAIL of $(wc -l < "$QUEUE" | tr -d ' ') runs failed, listed in $FAILLOG" >&2
  echo "re-run the same command to retry them" >&2
  exit 1
fi
echo "DRIVE DONE"
