#!/usr/bin/env bash
# usage: run.sh <experiment-dir> <arm> <model> <cell> <rep>
# example: run.sh thoughts/validation/2026-09-02_answer-first-harness "AF Old" opus 3 1
#
# One arm, one cell, one repetition. Copies the fixture into an isolated work
# directory, runs `claude -p` with the arm injected, and writes three things
# under the results directory: the raw event stream as <id>.json, the response
# text as <id>.md, and one resource row appended to cost.tsv. Every later step
# takes that directory as its handle, so one experiment can hold several runs
# side by side by setting RESULTS.
#
# Everything specific to an experiment comes from <experiment-dir>/experiment.env.
# README.md in this directory defines that contract.
set -euo pipefail

[ $# -eq 5 ] || { sed -n '2,3p' "$0" >&2; exit 2; }
EXP="$(cd "$1" && pwd)"; shift
ARM="$1"; MODEL="$2"; CELL="$3"; REP="$4"

# Defaults an experiment.env may override.
INJECT=output-style
EFFORT=high
MAX_BUDGET_USD=3
PERMISSION_MODE=acceptEdits
ALLOWED_TOOLS=()
if [ -f "$EXP/experiment.env" ]; then
  # shellcheck source=/dev/null
  . "$EXP/experiment.env"
fi
# Resolved after the source so a sweep can redirect one run's output without
# editing the experiment: RESULTS=results-gate-a drive.sh ...
RESULTS="${RESULTS:-results}"

ID="$(printf '%s' "$ARM" | tr ' ' '_')_${MODEL}_${CELL}_${REP}"
OUT="$EXP/$RESULTS"
WORK="$EXP/work/$ID"
rm -rf "$WORK"
mkdir -p "$EXP/work" "$OUT" "$WORK/.claude"
if [ -d "$EXP/fixture" ]; then cp -R "$EXP/fixture/." "$WORK/"; fi

# INJECT names the substitution point: how one arm reaches the model. This case
# is the whole difference between comparing output styles, agent bodies, plugins
# and raw system prompts, which is why it is a line of config and not a fork of
# this script.
INJECT_FLAGS=()
case "$INJECT" in
output-style)
  # Every arm is copied in, not only the one under test: Claude Code resolves a
  # style by the `name` in its frontmatter, so the directory has to hold the
  # file whose frontmatter carries "$ARM" and there is no cost to carrying all.
  cp -R "$EXP/arms" "$WORK/.claude/output-styles"
  INJECT_FLAGS=(--settings "{\"outputStyle\":\"$ARM\"}" --setting-sources project)
  ;;
append-system-prompt)
  # Passing this turns --system-prompt-snapshot off, so the arm text applies
  # fresh on every launch rather than being reused from a recorded prompt.
  INJECT_FLAGS=(--append-system-prompt "$(cat "$EXP/arms/$ARM.txt")")
  ;;
system-prompt)
  INJECT_FLAGS=(--system-prompt "$(cat "$EXP/arms/$ARM.txt")")
  ;;
agents)
  INJECT_FLAGS=(--agents "$(cat "$EXP/arms/$ARM.json")" --agent "$ARM")
  ;;
plugin-dir)
  INJECT_FLAGS=(--plugin-dir "$EXP/arms/$ARM")
  ;;
*)
  echo "unknown INJECT: $INJECT" >&2
  exit 2
  ;;
esac

# ${arr[@]+"${arr[@]}"} rather than "${arr[@]}": under `set -u` bash 3.2, which
# is the version macOS ships, expanding an empty array is an unbound-variable
# error. An experiment that allows no tools has an empty ALLOWED_TOOLS.
cd "$WORK"
claude -p \
  --model "$MODEL" \
  --effort "$EFFORT" \
  --max-budget-usd "$MAX_BUDGET_USD" \
  "${INJECT_FLAGS[@]+"${INJECT_FLAGS[@]}"}" \
  --permission-mode "$PERMISSION_MODE" \
  ${ALLOWED_TOOLS[@]+--allowedTools "${ALLOWED_TOOLS[@]}"} \
  --output-format json \
  "$(cat "$EXP/prompts/$CELL.txt")" < /dev/null > "$OUT/$ID.json"

# 2.1.259 --output-format json emits an array of stream events; the result is
# the last one.
jq -r '[.[] | select(.type=="result")] | last | .result' "$OUT/$ID.json" > "$OUT/$ID.md"
jq -r --arg id "$ID" '
  ([.[] | select(.type=="system" and .subtype=="init")] | last) as $init
  | ([.[] | select(.type=="result")] | last) as $res
  | ($res.usage // {}) as $u
  | [$id, $res.total_cost_usd, $res.num_turns, $init.model, $init.output_style, $res.subtype,
     $res.duration_ms, $res.duration_api_ms, $res.ttft_ms,
     $u.input_tokens, $u.output_tokens, $u.cache_read_input_tokens, $u.cache_creation_input_tokens]
  | @tsv' \
  "$OUT/$ID.json" >> "$OUT/cost.tsv"
# The init event reports the output style the session actually loaded, which is
# the only confirmation that the arm reached the model rather than being silently
# ignored. It is empty for the INJECT modes that do not use an output style.
echo "$ID: $(wc -w < "$OUT/$ID.md") words, loaded style=$(jq -r '[.[]|select(.subtype=="init")]|last|.output_style' "$OUT/$ID.json")"
