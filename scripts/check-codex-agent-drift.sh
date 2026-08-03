#!/usr/bin/env bash
# Drift check for the df plugin's mirrored agent prompts:
#   plugins/df/agents/<name>.md         — Claude Code (body after frontmatter)
#   plugins/df/codex/agents/<name>.toml — Codex CLI (developer_instructions body)
#
# Pairing rule: the two directories name the same set of agents — every .md
# has a same-named .toml and every .toml a same-named .md. A name on one side
# only is drift -> exit 1.
#
# Body rule: the .toml body must equal the .md body byte-for-byte, OR equal
# the .md body followed by a literal '<!-- codex-only -->' marker line and a
# Codex-only suffix. Anything else is drift -> exit 1, as is a .toml whose
# developer_instructions body cannot be extracted or comes out empty.
#
# Effort rule: every agent declares an effort level on both sides, the .md
# frontmatter's 'effort:' equals the .toml's 'model_reasoning_effort', and the
# value is one of low|medium|high. Differing values, a value on exactly one
# side, neither side declaring one, and an out-of-set value are each drift ->
# exit 1. The valid set is the intersection of what both runtimes honour:
# Claude Code also accepts 'max' and integers, Codex also accepts 'none',
# 'minimal' and 'xhigh', and a value outside the set is dropped with only a
# debug log.
#
# Body extraction is anchored on the exact line 'developer_instructions = """'
# (NOT the first triple quote in the file — several .toml files carry a
# multi-line description = """...""" field above it). Effort extraction is
# anchored at column 0 and stops at the body, because two agents quote
# 'model_reasoning_effort' again inside their prose as a Codex call example.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

MD_DIR="plugins/df/agents"
TOML_DIR="plugins/df/codex/agents"
MARKER='<!-- codex-only -->'
fail=0

trim_blank_edges() {
  awk 'NF || started {started=1; lines[++n]=$0}
       END {while (n && lines[n] ~ /^[[:space:]]*$/) n--
            for (i = 1; i <= n; i++) print lines[i]}'
}

md_body() {
  awk 'NR==1 && $0=="---" {infm=1; next}
       infm==1 && $0=="---" {infm=2; next}
       infm==2' "$1" | trim_blank_edges
}

toml_body() {
  awk '$0=="developer_instructions = \"\"\"" {inb=1; next}
       inb && $0=="\"\"\"" {exit}
       inb' "$1" | trim_blank_edges
}

md_effort() {
  awk 'NR==1 && $0=="---" {infm=1; next}
       infm && $0=="---" {exit}
       infm && sub(/^effort:[[:space:]]*/, "") {gsub(/^"|"$/, ""); print; exit}' "$1"
}

toml_effort() {
  awk '$0=="developer_instructions = \"\"\"" {exit}
       sub(/^model_reasoning_effort[[:space:]]*=[[:space:]]*/, "") {gsub(/^"|"$/, ""); print; exit}' "$1"
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

md_names=$(cd "$MD_DIR" && printf '%s\n' *.md | sed 's/\.md$//' | sort)
toml_names=$(cd "$TOML_DIR" && printf '%s\n' *.toml | sed 's/\.toml$//' | sort)

if [ "$md_names" != "$toml_names" ]; then
  echo "DRIFT: agent name sets differ between $MD_DIR and $TOML_DIR"
  diff <(printf '%s\n' "$md_names") <(printf '%s\n' "$toml_names") || true
  fail=1
fi

while IFS= read -r name; do
  toml="$TOML_DIR/$name.toml"
  [ -f "$toml" ] || continue # missing pair already reported above

  md_effort_val=$(md_effort "$MD_DIR/$name.md")
  toml_effort_val=$(toml_effort "$toml")
  # One message per pair: an unequal pair is already reported, so the value is
  # validated only once both sides agree on it.
  if [ -z "$md_effort_val" ] && [ -z "$toml_effort_val" ]; then
    echo "DRIFT($name): neither side declares an effort level"
    fail=1
  elif [ "$md_effort_val" != "$toml_effort_val" ]; then
    echo "DRIFT($name): effort '${md_effort_val:-<none>}' in $MD_DIR/$name.md != model_reasoning_effort '${toml_effort_val:-<none>}' in $toml"
    fail=1
  else
    case "$md_effort_val" in
      low | medium | high) ;;
      *)
        echo "DRIFT($name): '$md_effort_val' is not a valid effort level (expected low, medium, or high)"
        fail=1
        ;;
    esac
  fi

  md_body "$MD_DIR/$name.md" >"$tmpdir/md"
  toml_body "$toml" >"$tmpdir/toml"

  if [ ! -s "$tmpdir/toml" ]; then
    echo "DRIFT($name): could not extract developer_instructions body from $toml"
    fail=1
    continue
  fi

  if cmp -s "$tmpdir/md" "$tmpdir/toml"; then
    continue
  fi

  if grep -qxF "$MARKER" "$tmpdir/toml"; then
    awk -v m="$MARKER" '$0==m {exit} {print}' "$tmpdir/toml" | trim_blank_edges >"$tmpdir/prefix"
    if cmp -s "$tmpdir/md" "$tmpdir/prefix"; then
      continue
    fi
    echo "DRIFT($name): body before '$MARKER' in $toml differs from $MD_DIR/$name.md"
    diff "$tmpdir/md" "$tmpdir/prefix" | head -20 || true
  else
    echo "DRIFT($name): $toml body differs from $MD_DIR/$name.md (no '$MARKER' marker)"
    diff "$tmpdir/md" "$tmpdir/toml" | head -20 || true
  fi
  fail=1
done <<<"$md_names"

exit "$fail"
