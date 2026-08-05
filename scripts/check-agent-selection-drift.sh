#!/usr/bin/env bash
# Drift check for the <agent_selection> table, duplicated verbatim in:
#   plugins/df/skills/{research,planning,iterate}/SKILL.md
#
# The three copies must be identical after de-indentation and blank-line
# removal (iterate nests its copy inside a numbered list). Both are normalized
# because Prettier renders the same block differently depending on nesting: at
# top level it puts a blank line after '**Guidelines:**', nested in a numbered
# list it does not. Content drift is what matters. Anything else -> exit 1.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

FILES="plugins/df/skills/research/SKILL.md
plugins/df/skills/planning/SKILL.md
plugins/df/skills/iterate/SKILL.md"

extract() {
  awk '/^[[:space:]]*\| Agent /{inb=1}
       inb {sub(/^[[:space:]]+/, ""); if (NF) print}
       /cross-check against the actual codebase/{if (inb) exit}' "$1"
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

ref=""
ref_file=""
fail=0
while IFS= read -r f; do
  out="$tmpdir/$(echo "$f" | tr / _)"
  extract "$f" >"$out"
  if [ ! -s "$out" ]; then
    echo "DRIFT: could not extract <agent_selection> block from $f"
    fail=1
    continue
  fi
  if [ -z "$ref" ]; then
    ref="$out"
    ref_file="$f"
    continue
  fi
  if ! cmp -s "$ref" "$out"; then
    echo "DRIFT: $f differs from $ref_file"
    diff "$ref" "$out" | head -20 || true
    fail=1
  fi
done <<<"$FILES"

exit "$fail"
