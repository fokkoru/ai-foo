#!/usr/bin/env bash
# usage: judge.sh <claude|codex> <results-dir> <out.csv> [model]
# Scores every masked response under <results-dir>/review/ with one judge
# family, holding it to the experiment's judge-rubric.txt and judge-schema.json.
# judge-agy.sh is the third family and takes the same two arguments.
#
# The judge runs from an empty temporary directory, never the caller's. Both
# runtimes discover instruction files by walking the working directory's
# ancestors, so judging from a checkout loads that project's writing rules into
# the model deciding whether prose is mannered.
set -uo pipefail
[ $# -ge 3 ] || { sed -n '2p' "$0" >&2; exit 2; }
FAMILY="$1"; RES="$(cd "$2" && pwd)"; OUT="$3"
EXP="$(dirname "$RES")"
DIR="$RES/review"
RUBRIC="$EXP/judge-rubric.txt"
SCHEMA="$EXP/judge-schema.json"
ROW="$(cd "$(dirname "$0")" && pwd)/judge_row.py"
for f in "$RUBRIC" "$SCHEMA" "$ROW"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

case "$FAMILY" in
claude) MODEL="${4:-opus}" ;;
codex) MODEL="${4:-gpt-5.6-sol}" ;;
*) echo "unknown family: $FAMILY (claude or codex)" >&2; exit 2 ;;
esac

# An empty directory with no ancestors carrying CLAUDE.md, AGENTS.md or a git
# repository. Removed on exit however this script ends.
CLEAN="$(mktemp -d)"
trap 'rm -rf "$CLEAN"' EXIT

echo "review_id,judge_model,count,phrases" > "$OUT"
# r*.md, not *.md: mask.py writes and prunes exactly that set, and bash 3.2
# hands the loop the literal pattern when nothing matches.
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
  PROMPT="$(printf '%s\n\n%s\n' "$(cat "$RUBRIC")" "$(cat "$f")")"
  case "$FAMILY" in
  claude)
    # --max-turns 1 so a judge that reaches for a tool fails into the ERROR
    # path instead of reading files. --setting-sources project from CLEAN
    # leaves the caller's own output style out of the judge's context, which
    # matters here more than anywhere: the caller's style is the rule the judge
    # is scoring against, worked examples and all.
    (cd "$CLEAN" && CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 claude -p \
      --model "$MODEL" \
      --setting-sources project \
      --settings '{"claudeMdExcludes":["**/CLAUDE.md","**/CLAUDE.local.md"]}' \
      --json-schema "$(cat "$SCHEMA")" \
      --max-turns 1 \
      --output-format json \
      "$PROMPT" < /dev/null 2>/dev/null) \
      | jq -c '[.[] | select(.type=="result")] | last' 2>/dev/null \
      | python3 "$ROW" "$ID" "$MODEL" structured_output >> "$OUT"
    ;;
  codex)
    LAST="$CLEAN/last.json"
    rm -f "$LAST"
    codex exec --model "$MODEL" --cd "$CLEAN" --skip-git-repo-check \
      --output-schema "$SCHEMA" -o "$LAST" "$PROMPT" >/dev/null 2>&1
    python3 "$ROW" "$ID" "$MODEL" < "$LAST" >> "$OUT" 2>/dev/null \
      || printf '%s,%s,ERROR,\n' "$ID" "$MODEL" >> "$OUT"
    ;;
  esac
done
echo "wrote $OUT"
# grep -c exits 1 on zero matches and pipefail is set, so a clean run would
# otherwise leave this script exiting 1. Status 2 is a real failure and stays.
N_ERR="$(grep -c ',ERROR,' "$OUT")"
RC=$?
[ "$RC" -le 1 ] || { echo "grep failed reading $OUT" >&2; exit 1; }
echo "$N_ERR rows need re-judging"
