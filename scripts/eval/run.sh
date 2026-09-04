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
# One path component. score.py, mask.py and judge-agy.sh all recover the
# experiment directory as the parent of the results directory, so a nested value
# breaks them silently, and `..` would let the rm -rf below escape the
# experiment altogether.
case "$RESULTS" in
"" | . | .. | */*) echo "RESULTS must be a single directory name, got '$RESULTS'" >&2; exit 2 ;;
esac

# Called as a statement, never inside a command substitution: an exit there ends
# only the subshell. `set -e` already stops the array assignments below, whose
# status is the substitution's, but not a substitution used as an argument, and
# not a bare `cat` message anyone would have to guess at.
require() {
  if [ "${2:-file}" = dir ]; then
    [ -d "$1" ] && [ -r "$1" ] && [ -x "$1" ] || { echo "missing or unusable directory: $1" >&2; exit 1; }
  else
    [ -f "$1" ] && [ -r "$1" ] || { echo "missing or unreadable file: $1" >&2; exit 1; }
  fi
}

ID="$(printf '%s' "$ARM" | tr ' ' '_')_${MODEL}_${CELL}_${REP}"
OUT="$EXP/$RESULTS"
# Keyed on RESULTS as well as the id: two sweeps of the same experiment under
# different results directories would otherwise share one work directory, and
# the rm -rf below would delete the other one mid-run.
WORK="$EXP/work/$RESULTS/$ID"
rm -rf "$WORK"
mkdir -p "$EXP/work/$RESULTS" "$OUT" "$WORK/.claude"
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
  require "$EXP/arms" dir
  cp -R "$EXP/arms" "$WORK/.claude/output-styles"
  INJECT_FLAGS=(--settings "{\"outputStyle\":\"$ARM\"}" --setting-sources project)
  ;;
append-system-prompt)
  # Passing this turns --system-prompt-snapshot off, so the arm text applies
  # fresh on every launch rather than being reused from a recorded prompt.
  require "$EXP/arms/$ARM.txt"
  INJECT_FLAGS=(--append-system-prompt "$(cat "$EXP/arms/$ARM.txt")")
  ;;
system-prompt)
  require "$EXP/arms/$ARM.txt"
  INJECT_FLAGS=(--system-prompt "$(cat "$EXP/arms/$ARM.txt")")
  ;;
agents)
  require "$EXP/arms/$ARM.json"
  INJECT_FLAGS=(--agents "$(cat "$EXP/arms/$ARM.json")" --agent "$ARM")
  ;;
plugin-dir)
  require "$EXP/arms/$ARM" dir
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
# The one command substitution `set -e` cannot catch, because it is an argument
# rather than an assignment: without this a misnamed cell runs `claude -p ""` at
# full budget and the empty response is scored like any other.
require "$EXP/prompts/$CELL.txt"

cd "$WORK"
RC=0
claude -p \
  --model "$MODEL" \
  --effort "$EFFORT" \
  --max-budget-usd "$MAX_BUDGET_USD" \
  "${INJECT_FLAGS[@]+"${INJECT_FLAGS[@]}"}" \
  --permission-mode "$PERMISSION_MODE" \
  ${ALLOWED_TOOLS[@]+--allowedTools "${ALLOWED_TOOLS[@]}"} \
  --output-format json \
  "$(cat "$EXP/prompts/$CELL.txt")" < /dev/null > "$OUT/$ID.json" || RC=$?

# 2.1.259 --output-format json emits an array of stream events; the result is
# the last one.
#
# The cost row is written whatever happened. A run that failed still cost money,
# and this file is the only place that price is recorded.
jq -r --arg id "$ID" '
  ([.[] | select(.type=="system" and .subtype=="init")] | last) as $init
  | ([.[] | select(.type=="result")] | last) as $res
  | ($res.usage // {}) as $u
  | [$id, $res.total_cost_usd, $res.num_turns, $init.model, $init.output_style, $res.subtype,
     $res.duration_ms, $res.duration_api_ms, $res.ttft_ms,
     $u.input_tokens, $u.output_tokens, $u.cache_read_input_tokens, $u.cache_creation_input_tokens]
  | @tsv' \
  "$OUT/$ID.json" >> "$OUT/cost.tsv" || echo "$ID: no cost row, result JSON unreadable" >&2

# Three gates, and none of them writes a response. drive.sh queues on the
# absence of "$ID.md", so a run that fails any of them is retried by re-running
# the same sweep, while its raw JSON and its price stay on disk as the record.
#
# claude exits 0 on error_max_budget_usd, error_max_turns and
# error_during_execution, so the exit status alone decides nothing. With no
# result event at all the expression below prints the string "null", which is
# not "success" either.
SUBTYPE="$(jq -r '[.[] | select(.type=="result")] | last | .subtype' "$OUT/$ID.json" 2>/dev/null || echo unreadable)"
if [ "$RC" -ne 0 ] || [ "$SUBTYPE" != "success" ]; then
  echo "$ID: no response written (claude rc=$RC, subtype=$SUBTYPE)" >&2
  exit 1
fi

# A success carrying no result text would otherwise be written as the four
# characters "null" and counted as a short answer.
jq -e '[.[] | select(.type=="result")] | last | .result | type == "string"' "$OUT/$ID.json" >/dev/null || {
  echo "$ID: no response written (result event carries no text)" >&2
  exit 1
}

# The init event reports the output style the session actually loaded, which is
# the only confirmation that the arm reached the model rather than being silently
# ignored — a typo in an arm name is otherwise a full sweep of unstyled runs. It
# is empty for the INJECT modes that do not use an output style, so only this one
# can check it.
LOADED="$(jq -r '[.[]|select(.subtype=="init")]|last|.output_style' "$OUT/$ID.json")"
if [ "$INJECT" = output-style ] && [ "$LOADED" != "$ARM" ]; then
  echo "$ID: no response written (arm '$ARM' did not load, session ran with '$LOADED')" >&2
  exit 1
fi

# Written aside and renamed: a half-written response is a non-empty file, and
# non-empty is exactly what drive.sh reads as "already done".
jq -r '[.[] | select(.type=="result")] | last | .result' "$OUT/$ID.json" > "$OUT/.$ID.md.part"
mv "$OUT/.$ID.md.part" "$OUT/$ID.md"
echo "$ID: $(wc -w < "$OUT/$ID.md") words, loaded style=$LOADED"
