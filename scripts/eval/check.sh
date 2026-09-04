#!/usr/bin/env bash
# usage: check.sh <experiment-dir> <metric> <arm-a> <arm-b> <cell>...
# example: MODELS=opus check.sh thoughts/validation/<exp> words "AF Old" "AF New" 1 2 3
#
# One command for a two-arm comparison: sweep, score, price, compare. It is the
# rung-1 pipeline of the methodology, which is the tier with no judge, so
# nothing here masks or judges anything. A change with no mechanical proxy needs
# mask.py and a judge runner, and those stay separate commands.
#
# Every step already exists and is unchanged; this only fixes their order and
# stops on the first failure. drive.sh exits nonzero when a run produced no
# response, and `set -e` turns that into a stop, so an incomplete sweep cannot
# reach paired.py and print a difference that looks measured.
set -euo pipefail

[ $# -ge 5 ] || { sed -n '2,3p' "$0" >&2; exit 2; }
EXP="$1"; METRIC="$2"; A="$3"; B="$4"; shift 4

HERE="$(cd "$(dirname "$0")" && pwd)"
# Three repetitions: the methodology's sizing section measures that as enough for
# a cell-paired reading and more cells as the better place to spend the
# difference. Parallelism 6 is what the September run was measured at, so
# cost.py's wall-clock projection matches the number in the methodology.
REPS="${REPS:-3}"
PAR="${PAR:-6}"
# Mirrors drive.sh's default, because the Python steps need the directory path
# and there is no other way to learn what the sweep wrote to.
RESULTS="${RESULTS:-results}"
case "$RESULTS" in
"" | . | .. | */*) echo "RESULTS must be a single directory name, got '$RESULTS'" >&2; exit 2 ;;
esac
export RESULTS
# drive.sh reads ARMS from the environment, pipe-separated because arm names
# contain spaces. Two arms, always: the comparison below is a paired test
# between exactly two, and a third arm would be measured and then not read.
export ARMS="$A|$B"

# The results directory is the unit, not the cell list: score.py and paired.py
# read everything in it. Naming a subset of cells here sweeps that subset and
# still compares against every cell already in the directory, which is what a
# resumed sweep wants and what a fresh comparison gets by choosing a new RESULTS.
DIR="$EXP/$RESULTS"
"$HERE/drive.sh" "$EXP" "$PAR" "$REPS" "$@"
python3 "$HERE/score.py" "$DIR"
python3 "$HERE/cost.py" "$DIR" "$PAR"
python3 "$HERE/paired.py" "$DIR" "$METRIC" "$A" "$B"
