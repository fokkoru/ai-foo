#!/usr/bin/env bash
# Regression tests for plugins/kb/scripts/check-docs.sh.
#
# Every assertion is on the checker's command line contract: its exit code, the
# lines it prints, and the files a subcommand promises to write. Nothing here
# reaches inside the script.
#
# bash 3.2 is the checker's floor, so it is the floor here too.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

CHECKER="$PWD/plugins/kb/scripts/check-docs.sh"

fail=0
pass() { echo "ok: $1"; }
bad() {
  echo "FAIL: $1"
  fail=1
}

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# One TMPDIR for both runs: the point of the test is that two runs sharing a
# temp directory do not share a manifest.
export TMPDIR="$SCRATCH/tmp"
mkdir -p "$TMPDIR"

# Two trees whose raw roots carry the same relative path and different content.
# Same relative path is what makes one run's snapshot look applicable to the
# other's tree; different content is what makes the confusion visible.
mkdir -p "$SCRATCH/repo-a/thoughts" "$SCRATCH/repo-b/thoughts"
echo "alpha" >"$SCRATCH/repo-a/thoughts/note.md"
echo "beta" >"$SCRATCH/repo-b/thoughts/note.md"

# --- two concurrent runs each verify their own raw layer ---------------------

man_a=$(cd "$SCRATCH/repo-a" && "$CHECKER" snapshot thoughts)
man_b=$(cd "$SCRATCH/repo-b" && "$CHECKER" snapshot thoughts)

if [ -n "$man_a" ] && [ -f "$man_a" ]; then
  pass "snapshot prints a manifest path that exists"
else
  bad "snapshot printed '$man_a', which is not a file"
fi

if [ "$man_a" != "$man_b" ]; then
  pass "two runs under one TMPDIR get different manifests"
else
  bad "both runs share the manifest $man_a"
fi

if (cd "$SCRATCH/repo-a" && "$CHECKER" verify-sources "$man_a" thoughts >/dev/null); then
  pass "the first run verifies against its own snapshot"
else
  bad "the first run's verify-sources did not pass"
fi

if (cd "$SCRATCH/repo-b" && "$CHECKER" verify-sources "$man_b" thoughts >/dev/null); then
  pass "the second run verifies against its own snapshot"
else
  bad "the second run's verify-sources did not pass"
fi

# --- verify-sources still catches a real edit --------------------------------

echo "alpha, edited" >"$SCRATCH/repo-a/thoughts/note.md"
out=$(cd "$SCRATCH/repo-a" && "$CHECKER" verify-sources "$man_a" thoughts 2>&1)
if [ $? -ne 0 ] && printf '%s' "$out" | grep -q '^SOURCE-CHANGED'; then
  pass "verify-sources reports a file edited after the snapshot"
else
  bad "an edited raw file did not produce SOURCE-CHANGED: $out"
fi

# --- capture record format -----------------------------------------------

CAPTURES="$PWD/scripts/fixtures/captures"

# Run check-capture over a fixture and report whether it exited as expected and
# printed the rule asked for. The rule name is matched at the start of a line,
# so a report line is identified by its rule rather than by its position.
expect_capture() {
  local want_exit="$1" fixture="$2" rule="$3" out status
  out=$("$CHECKER" check-capture "$CAPTURES/$fixture" 2>&1)
  status=$?
  if [ "$status" -ne "$want_exit" ]; then
    bad "$fixture exited $status, expected $want_exit: $out"
    return
  fi
  if [ -n "$rule" ] && ! printf '%s\n' "$out" | grep -q "^$rule("; then
    bad "$fixture did not report $rule: $out"
    return
  fi
  pass "$fixture ${rule:-conforms}"
}

expect_capture 0 conforming.md ""
expect_capture 1 with-frontmatter.md capture-frontmatter
expect_capture 1 duplicate-decision.md capture-decision-duplicate
expect_capture 1 missing-fields.md capture-field-missing
expect_capture 1 empty-evidence.md capture-evidence-empty
expect_capture 1 no-decisions.md capture-no-decisions
expect_capture 0 fenced-heading.md ""

# The three missing fields are three separate findings, one per decision, not
# one finding for the record.
out=$("$CHECKER" check-capture "$CAPTURES/missing-fields.md" 2>&1)
if [ "$(printf '%s\n' "$out" | grep -c '^capture-field-missing(')" -eq 3 ]; then
  pass "each decision missing a field is reported on its own"
else
  bad "expected three capture-field-missing lines: $out"
fi

# `Evidence: none` is the explicit mark that no durable source exists, and it
# is accepted; an empty field is not.
out=$("$CHECKER" check-capture "$CAPTURES/conforming.md" 2>&1)
if [ $? -eq 0 ] && ! printf '%s\n' "$out" | grep -q 'capture-evidence-empty'; then
  pass "an explicitly marked absence of evidence is accepted"
else
  bad "Evidence: none was reported as empty: $out"
fi

# A ### inside a fenced block is prose about the format, not a decision. The
# fixture holds one real decision and one fenced imposter.
out=$("$CHECKER" check-capture "$CAPTURES/fenced-heading.md" 2>&1)
if printf '%s\n' "$out" | grep -q '1 decision'; then
  pass "a ### inside a fence is not counted as a decision"
else
  bad "fenced ### was counted: $out"
fi

exit "$fail"
