#!/usr/bin/env bash
# usage: judge-pair.sh <claude|codex> <results-dir> <base-arm> <variant-arm> <out.csv> [model]
# example: judge-pair.sh claude thoughts/validation/<exp>/results "AF Base" "AF Orwell" pairs-opus.csv
#
# Pairwise preference judge. For every response of the variant arm that has a
# base-arm response with the same model, cell and repetition, asks one judge
# which of the two is better, once in each order, and appends one row per
# order to <out.csv>: model,cell,rep,variant,order,verdict. `pairs.py` reads
# that file. A row already present is not judged again, so an interrupted pass
# resumes by re-running the same command.
#
# The rubric is the experiment's judge-pair-rubric.txt and the reply is held to
# judge-pair-schema.json, whose only field is the winning letter. Anything
# that is not A or B is recorded as ERROR, never as a loss.
#
# The judge runs from an empty temporary directory, for the reason judge.sh
# gives: judging from a checkout loads that project's writing rules into the
# model deciding whose prose is better.
set -uo pipefail
[ $# -ge 5 ] || { sed -n '2p' "$0" >&2; exit 2; }
FAMILY="$1"; RES="$(cd "$2" && pwd)"; BASE="$(printf '%s' "$3" | tr ' ' '_')"
VAR="$(printf '%s' "$4" | tr ' ' '_')"; OUT="$5"
EXP="$(dirname "$RES")"
RUBRIC="$EXP/judge-pair-rubric.txt"
SCHEMA="$EXP/judge-pair-schema.json"
for f in "$RUBRIC" "$SCHEMA"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

case "$FAMILY" in
claude) MODEL="${6:-opus}" ;;
codex) MODEL="${6:-gpt-5.6-sol}" ;;
*) echo "unknown family: $FAMILY (claude or codex)" >&2; exit 2 ;;
esac

CLEAN="$(mktemp -d)"
trap 'rm -rf "$CLEAN"' EXIT

[ -s "$OUT" ] || echo "model,cell,rep,variant,order,verdict" > "$OUT"

ask() { # <A-file> <B-file> <cell>: prints A, B or ERROR
  local prompt
  prompt="$(printf '%s\n\n<request>\n%s\n</request>\n\n<answer_A>\n%s\n</answer_A>\n\n<answer_B>\n%s\n</answer_B>\n' \
    "$(cat "$RUBRIC")" "$(cat "$EXP/prompts/$3.txt")" "$(cat "$1")" "$(cat "$2")")"
  local reply
  case "$FAMILY" in
  claude)
    reply="$(cd "$CLEAN" && CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 claude -p \
      --model "$MODEL" \
      --setting-sources project \
      --settings '{"claudeMdExcludes":["**/CLAUDE.md","**/CLAUDE.local.md"]}' \
      --json-schema "$(cat "$SCHEMA")" \
      --max-turns 1 \
      --output-format json \
      "$prompt" < /dev/null 2>/dev/null \
      | jq -r '[.[] | select(.type=="result")] | last | .structured_output.winner // empty' 2>/dev/null)"
    ;;
  codex)
    local last="$CLEAN/last.json"
    rm -f "$last"
    codex exec --model "$MODEL" --cd "$CLEAN" --skip-git-repo-check \
      --output-schema "$SCHEMA" -o "$last" "$prompt" >/dev/null 2>&1
    reply="$(jq -r '.winner // empty' "$last" 2>/dev/null)"
    ;;
  esac
  case "$reply" in A | B) echo "$reply" ;; *) echo ERROR ;; esac
}

N=0; N_ERR=0
for vf in "$RES/${VAR}"_*.md; do
  [ -e "$vf" ] || continue
  stem="$(basename "$vf" .md)"
  rest="${stem#"${VAR}"_}"                # <model>_<cell>_<rep>
  model="${rest%%_*}"; rest="${rest#*_}"
  cell="${rest%_*}"; rep="${rest##*_}"
  bf="$RES/${BASE}_${model}_${cell}_${rep}.md"
  [ -s "$bf" ] || { echo "no base response for $stem, skipped" >&2; continue; }
  for order in ab ba; do
    grep -q "^$model,$cell,$rep,$VAR,$order," "$OUT" && continue
    if ! grep -q '[^[:space:]]' "$vf"; then
      v=ERROR
    elif [ "$order" = ab ]; then
      v="$(ask "$bf" "$vf" "$cell")"
    else
      v="$(ask "$vf" "$bf" "$cell")"
    fi
    echo "$model,$cell,$rep,$VAR,$order,$v" >> "$OUT"
    N=$((N + 1)); [ "$v" = ERROR ] && N_ERR=$((N_ERR + 1))
    echo "$stem $order -> $v"
  done
done
echo "$N verdicts appended to $OUT, $N_ERR need re-judging"
