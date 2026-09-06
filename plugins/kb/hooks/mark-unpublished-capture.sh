#!/usr/bin/env sh
# SessionEnd hook. Leaves a marker pointing at a capture record that was
# prepared and never published, so a later session can find it.
#
# It finishes an interrupted capture and never starts a new one. It writes no
# record and calls no model: the budget here is under two seconds, which is
# enough to append a line and nowhere near enough to reach a model. That is the
# whole reason the record is written by the skill and only pointed at here.
#
# The marker lives under the git directory, outside every snapshot, so it never
# registers as a source change. It is keyed by session id, so a second fire for
# one session overwrites rather than appends.
set -eu

gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
staged="$gitdir/kb-staged"
[ -d "$staged" ] || exit 0

# No staged record means nothing was interrupted.
set -- "$staged"/*.md
[ -e "$1" ] || exit 0

session=$(sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null || true)
[ -n "$session" ] || session=${CLAUDE_SESSION_ID:-unknown}

markers="$gitdir/kb-capture-markers"
mkdir -p "$markers"
: >"$markers/$session"
for staged_record in "$@"; do
  printf '%s\n' "$staged_record" >>"$markers/$session"
done
