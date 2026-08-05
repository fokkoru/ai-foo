#!/usr/bin/env bash
# Cap check for the frontmatter descriptions in plugins/df/skills/*/SKILL.md.
#
# 250 is MAX_LISTING_DESC_CHARS in the Claude Code harness
# (src/tools/SkillTool/prompt.ts) — an external number, not a house style
# choice. getCommandDescription() there builds each listing entry from
# `description` alone, or from "<description> - <when_to_use>" when the
# frontmatter carries when_to_use, then slices anything past the cap and
# replaces the tail with an ellipsis. A trigger phrase past the cut is invisible
# to the model, so the skill never fires on it.
#
# The cap only binds a skill the model may invoke on its own. One carrying
# disable-model-invocation: true never reaches that listing — a human picks it
# by name — so it gets the 1024-character frontmatter limit instead
# (CLAUDE.md). Which skills those are is read out of the files themselves,
# never listed here.
#
# Lengths are Unicode code points. Bytes would over-report: an em dash is three
# bytes and one character, and the auto-triggering descriptions use em dashes.
# The harness slices on desc.length, which is UTF-16 code units — the same
# number for everything in the Basic Multilingual Plane, one less here per
# astral character (an emoji), which no description in this repo carries.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

SKILL_DIR="plugins/df/skills"
LISTING_CAP=250     # model-invocable: MAX_LISTING_DESC_CHARS
FRONTMATTER_CAP=1024 # manual-only: the description frontmatter limit
fail=0

# Value of a single-line frontmatter key, empty when the key is absent.
fm_value() {
  awk -v key="$2" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm && index($0, key ":")==1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      # Surrounding quotes are YAML syntax; the harness never sees them.
      first = substr($0, 1, 1)
      if (length($0) >= 2 && first == substr($0, length($0), 1) &&
          (first == "\"" || first == "\047")) {
        $0 = substr($0, 2, length($0) - 2)
      }
      print
      exit
    }' "$1"
}

# A block scalar leaves only its indicator on the key line, so fm_value returns
# '>-' or '|' and an arbitrarily long value would pass the cap unnoticed —
# writing a description as a folded scalar is exactly what someone does when it
# stops fitting on one line. Fail loudly rather than silently pass.
is_block_scalar() {
  case $1 in '|'* | '>'*) return 0 ;; *) return 1 ;; esac
}

# The other way a value outgrows one line: a plain scalar continued onto
# indented lines. fm_value reads only the key's own line, so a description grown
# past one line is measured short and passes a cap it exceeds. Fail loudly, the
# same as a block scalar. The helper prints a marker rather than setting an exit
# status, because awk's END block would override it.
has_continuation() {
  [ "$(awk -v key="$2" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    found && /^[[:space:]]/ && NF {print "yes"; exit}
    found {exit}
    infm && index($0, key ":")==1 {found=1}' "$1")" = yes ]
}

# Code points, not bytes: -CA decodes @ARGV as UTF-8 whatever the locale is.
char_len() {
  perl -CA -e 'print length($ARGV[0])' -- "$1"
}

# What the harness would cut: it keeps cap-1 characters, then appends an ellipsis.
sliced_tail() {
  perl -CAS -e 'print substr($ARGV[0], $ARGV[1] - 1)' -- "$1" "$2"
}

shopt -s nullglob
skills=("$SKILL_DIR"/*/SKILL.md)
if [ ${#skills[@]} -eq 0 ]; then
  echo "NO SKILLS: found no SKILL.md under $SKILL_DIR"
  exit 1
fi

for skill in "${skills[@]}"; do
  name=$(basename "$(dirname "$skill")")

  description=$(fm_value "$skill" description)
  if [ -z "$description" ]; then
    echo "MISSING($name): no single-line description in frontmatter of $skill"
    fail=1
    continue
  fi

  if is_block_scalar "$description"; then
    echo "UNSUPPORTED($name): description is a YAML block scalar in $skill — write it as a single-line scalar"
    fail=1
    continue
  fi

  if has_continuation "$skill" description; then
    echo "UNSUPPORTED($name): description continues past its first line in $skill — write it as a single-line scalar"
    fail=1
    continue
  fi

  listing="$description"
  when_to_use=$(fm_value "$skill" when_to_use)
  if is_block_scalar "$when_to_use"; then
    echo "UNSUPPORTED($name): when_to_use is a YAML block scalar in $skill — write it as a single-line scalar"
    fail=1
    continue
  fi
  if has_continuation "$skill" when_to_use; then
    echo "UNSUPPORTED($name): when_to_use continues past its first line in $skill — write it as a single-line scalar"
    fail=1
    continue
  fi
  if [ -n "$when_to_use" ]; then
    listing="$description - $when_to_use"
  fi

  if [ "$(fm_value "$skill" disable-model-invocation)" = "true" ]; then
    cap="$FRONTMATTER_CAP"
  else
    cap="$LISTING_CAP"
  fi

  len=$(char_len "$listing")
  if [ "$len" -gt "$cap" ]; then
    echo "OVER CAP($name): $len characters, cap is $cap"
    echo "  sliced off: $(sliced_tail "$listing" "$cap")"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "OK: ${#skills[@]} skill descriptions within cap"
fi

exit "$fail"
