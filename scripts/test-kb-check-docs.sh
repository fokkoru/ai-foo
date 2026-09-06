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

# --- decision identifiers -------------------------------------------------

FIX="$PWD/scripts/fixtures"

# The fixture bundles carry hand-written identifiers rather than assigned ones.
# An assertion against a value the checker would recompute the same way could
# never disagree with it; a stored opaque string can.

if "$CHECKER" check "$FIX/docs-decisions" >/dev/null 2>&1; then
  pass "a bundle whose decision pages carry distinct identifiers conforms"
else
  bad "the conforming fixture bundle did not pass: $("$CHECKER" check "$FIX/docs-decisions" 2>&1)"
fi

out=$("$CHECKER" check "$FIX/docs-missing-id" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^decision-id-missing('; then
  pass "a decision page with no identifier is reported"
else
  bad "missing identifier not reported: $out"
fi

out=$("$CHECKER" check "$FIX/docs-duplicate-id" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^decision-id-duplicate('; then
  pass "two pages sharing an identifier are reported"
else
  bad "duplicate identifier not reported: $out"
fi

out=$("$CHECKER" resolve-decision "$FIX/docs-decisions" a1a1a1a1a1a1 2>&1)
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q 'decisions/0001-alpha.md'; then
  pass "a reference resolves by identifier"
else
  bad "identifier a1a1a1a1a1a1 did not resolve: $out"
fi

out=$("$CHECKER" resolve-decision "$FIX/docs-decisions" zzzzzzzzzzzz 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^decision-ref-dangling('; then
  pass "a reference whose identifier matches nothing is reported dangling"
else
  bad "dangling reference not reported: $out"
fi

# The page moved; the reference still carries the path it had. Resolution is by
# identifier, so it succeeds, and the stale path is worth saying out loud
# without failing the run.
out=$("$CHECKER" resolve-decision "$FIX/docs-decisions" a1a1a1a1a1a1 decisions/0001-old-name.md 2>&1)
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q '^stale-path-hint(' &&
  printf '%s\n' "$out" | grep -q 'decisions/0001-alpha.md'; then
  pass "a renamed page resolves and its stale path hint is reported as a hint"
else
  bad "stale path hint not handled: $out"
fi

# The path is still occupied, by a different decision. Resolving by path would
# succeed and be wrong; resolving by identifier reports the truth.
out=$("$CHECKER" resolve-decision "$FIX/docs-reused-path" a1a1a1a1a1a1 decisions/0001-alpha.md 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^decision-ref-dangling('; then
  pass "a reused path holding a different decision does not resolve the old one"
else
  bad "a reused path resolved to the wrong decision: $out"
fi

# --- identifier assignment ------------------------------------------------

ASSIGN="$SCRATCH/assign"
mkdir -p "$ASSIGN"
cp "$FIX/docs-decisions/decisions/0001-alpha.md" "$ASSIGN/page.md"

id_one=$("$CHECKER" assign-id "$ASSIGN/page.md")
id_again=$("$CHECKER" assign-id "$ASSIGN/page.md")
if [ -n "$id_one" ] && [ "$id_one" = "$id_again" ]; then
  pass "assign-id returns the same identifier for the same page"
else
  bad "assign-id returned '$id_one' then '$id_again'"
fi

# An editorial rename is a new filename and a new title. Neither is the
# decision, so neither may change its name.
sed 's/title: "Alpha"/title: "Alpha, restated"/' "$ASSIGN/page.md" >"$ASSIGN/renamed-page.md"
id_renamed=$("$CHECKER" assign-id "$ASSIGN/renamed-page.md")
if [ "$id_one" = "$id_renamed" ]; then
  pass "an editorial rename does not change the identifier"
else
  bad "rename changed the identifier: $id_one vs $id_renamed"
fi

id_other=$("$CHECKER" assign-id "$FIX/docs-decisions/decisions/0002-beta.md")
if [ "$id_one" != "$id_other" ]; then
  pass "a different decision gets a different identifier"
else
  bad "two different decisions were assigned $id_one"
fi

# --- the whole-run claim ---------------------------------------------------

# A real repository, because the claim is repository-local and lives beside the
# git directory.
REPO="$SCRATCH/claim-repo"
mkdir -p "$REPO"
git -C "$REPO" init -q

# A live contender. Every refusal below is followed by the acquisition attempt
# it should still be refusing: a test that only reads the refusal line would
# pass an implementation that reports the refusal and drops the claim anyway.
tail -f /dev/null &
owner_pid=$!

run_id=$(cd "$REPO" && "$CHECKER" claim-acquire session-one "$owner_pid" 2>/dev/null)
if [ -n "$run_id" ]; then
  pass "claim-acquire returns a run id"
else
  bad "claim-acquire returned nothing"
fi

out=$(cd "$REPO" && "$CHECKER" claim-acquire session-two "$owner_pid" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^claim-held('; then
  pass "a second run is refused while the owner is alive"
else
  bad "the second acquisition was not refused: $out"
fi

out=$(cd "$REPO" && "$CHECKER" claim-inspect 2>&1)
if printf '%s\n' "$out" | grep -q "$run_id"; then
  pass "the claim still stands after the refusal"
else
  bad "the claim did not survive the refused acquisition: $out"
fi

out=$(cd "$REPO" && "$CHECKER" claim-release deadbeef0000 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^claim-not-owner('; then
  pass "a release by a run that does not own the claim is refused"
else
  bad "a foreign release was not refused: $out"
fi

out=$(cd "$REPO" && "$CHECKER" claim-inspect 2>&1)
if printf '%s\n' "$out" | grep -q "$run_id"; then
  pass "the claim still stands after the refused release"
else
  bad "the claim did not survive the refused release: $out"
fi

if (cd "$REPO" && "$CHECKER" claim-release "$run_id" >/dev/null 2>&1); then
  pass "the owner releases its own claim"
else
  bad "the owner could not release its claim"
fi

next_id=$(cd "$REPO" && "$CHECKER" claim-acquire session-three "$owner_pid" 2>/dev/null)
if [ -n "$next_id" ] && [ "$next_id" != "$run_id" ]; then
  pass "a legitimate release permits the next acquisition"
else
  bad "the next acquisition returned '$next_id'"
fi

# --- an owner that died ----------------------------------------------------

kill "$owner_pid" 2>/dev/null
wait "$owner_pid" 2>/dev/null

out=$(cd "$REPO" && "$CHECKER" claim-inspect 2>&1)
if printf '%s\n' "$out" | grep -q '^claim-abandoned('; then
  pass "a terminated owner leaves the claim reported as abandoned"
else
  bad "a dead owner was not reported: $out"
fi

tail -f /dev/null &
second_pid=$!

out=$(cd "$REPO" && "$CHECKER" claim-acquire session-four "$second_pid" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^claim-abandoned('; then
  pass "an abandoned claim is not taken over automatically"
else
  bad "an abandoned claim was taken over: $out"
fi

# Recovery is the operator reading the run id out of claim-inspect and
# releasing it by hand, after looking at what the dead run left behind.
(cd "$REPO" && "$CHECKER" claim-release "$next_id" >/dev/null 2>&1)
recovered=$(cd "$REPO" && "$CHECKER" claim-acquire session-five "$second_pid" 2>/dev/null)
if [ -n "$recovered" ]; then
  pass "an explicitly released abandoned claim permits the next acquisition"
else
  bad "the abandoned claim could not be recovered by an explicit release"
fi

(cd "$REPO" && "$CHECKER" claim-release "$recovered" >/dev/null 2>&1)
kill "$second_pid" 2>/dev/null
wait "$second_pid" 2>/dev/null

# Nothing about the claim waits, counts down, or gives up after a while. There
# is no measurement that would ground such a number, so none exists.
if grep -nE 'sleep|timeout|stale.after|poll|interval|attempts' "$CHECKER" >/dev/null; then
  bad "the checker names a duration or a repeat count: $(grep -nE 'sleep|timeout|stale.after|poll|interval|attempts' "$CHECKER")"
else
  pass "no duration, interval or repeat count appears in the checker"
fi

# --- supersession scan -----------------------------------------------------

DOCS_OK="$FIX/docs-decisions"

scan() {
  "$CHECKER" supersession-scan "$FIX/$1" "$DOCS_OK" "$2" 2>&1
}

out=$(scan records-chain "record r1.md ### The manifest lives at a fixed path")
if [ $? -eq 0 ] &&
  printf '%s\n' "$out" | grep -q 'r2.md ### The manifest is named per run' &&
  printf '%s\n' "$out" | grep -q 'r3.md ### The manifest is passed explicitly'; then
  pass "the scan expands transitively rather than stopping at one hop"
else
  bad "transitive expansion missing: $out"
fi

# The first decision in a three-record chain stays superseded. Re-adopting it
# would take a new record asserting it, not the disappearance of an edge.
out=$(scan records-chain "record r2.md ### The manifest is named per run")
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q 'r3.md'; then
  pass "a later displacement does not revive what the middle record displaced"
else
  bad "the chain's middle target resolved wrongly: $out"
fi

# r1.md carries a line that looks exactly like the field, in its narration
# section rather than on a decision. Only a field on a decision is an edge.
out=$(scan records-chain "record r3.md ### The manifest is passed explicitly from snapshot to verify")
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q '^supersession-scan: nothing supersedes'; then
  pass "a Supersedes line outside a decision is not an edge"
else
  bad "a line outside a decision was read as an edge: $out"
fi

out=$(scan records-two "record r1.md ### The checker lives under the skill")
if [ $? -eq 0 ] &&
  printf '%s\n' "$out" | grep -q 'r2.md' && printf '%s\n' "$out" | grep -q 'r3.md'; then
  pass "two records superseding one target both appear"
else
  bad "a second superseder was dropped: $out"
fi

out=$(scan records-dangling "record r1.md ### A decision displacing something absent")
if printf '%s\n' "$out" | grep -q '^supersession-dangling('; then
  pass "a reference to a target that does not exist is reported dangling"
else
  bad "dangling reference not reported: $out"
fi

out=$(scan records-cycle "record r1.md ### Alpha displaces Beta")
if printf '%s\n' "$out" | grep -q '^supersession-cycle('; then
  pass "a cycle among references is reported rather than looping"
else
  bad "cycle not reported: $out"
fi

# A malformed record makes the scan incomplete, which is a different outcome
# from finding nothing. An incomplete scan is never reported as "no
# supersession".
out=$(scan records-malformed "record r1.md ### A sound decision")
status=$?
if [ "$status" -eq 3 ] && printf '%s\n' "$out" | grep -q '^scan-incomplete('; then
  pass "a malformed record makes the scan report itself incomplete"
else
  bad "malformed record produced exit $status: $out"
fi

out=$(scan records-two "record r2.md ### The checker lives in the plugin's scripts")
status=$?
if [ "$status" -eq 0 ] && ! printf '%s\n' "$out" | grep -q '^scan-incomplete('; then
  pass "finding no supersession exits differently from an incomplete scan"
else
  bad "a clean scan with no result exited $status: $out"
fi

out=$(scan records-page "decision a1a1a1a1a1a1")
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q 'r1.md ### Alpha no longer holds'; then
  pass "a compiled decision page is a valid supersession target"
else
  bad "a record superseding a compiled page was not found: $out"
fi

# --- deprecation -----------------------------------------------------------

# The three rows of the deprecation table, as page shapes. Whether a rule still
# holds and whether its replacement is implemented are judgements the run makes;
# what the checker can settle is that each verdict produced a page the schema
# allows.
if "$CHECKER" check "$FIX/docs-deprecation" >/dev/null 2>&1; then
  pass "stable, deprecated-with-successor and deprecated-without all conform"
else
  bad "the deprecation bundle failed: $("$CHECKER" check "$FIX/docs-deprecation" 2>&1)"
fi

out=$("$CHECKER" check "$FIX/docs-deprecation-dangling" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^superseded-by-dangling('; then
  pass "a superseded_by naming no page is reported"
else
  bad "a dangling successor was not reported: $out"
fi

# A deprecated page is kept for links and history, so the checker grants it no
# reachability exemption.
out=$("$CHECKER" check "$FIX/docs-deprecation-unreachable" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^unreachable(.*0002-orphan'; then
  pass "a deprecated page still has to be reachable from the index"
else
  bad "an unlinked deprecated page was not reported: $out"
fi

out=$("$CHECKER" check "$FIX/docs-deprecation-drift" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^source-drift('; then
  pass "a deprecated page's sources are still provenance-checked"
else
  bad "a deprecated page escaped provenance checking: $out"
fi

# --- what a page may cite --------------------------------------------------

RAW="$PWD/scripts/fixtures/raw"

out=$("$CHECKER" check "$FIX/docs-source-raw" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^source-in-raw-root('; then
  pass "a sources entry naming a path inside the raw root is reported"
else
  bad "a citation into the raw layer was not reported: $out"
fi

out=$("$CHECKER" check "$FIX/docs-source-capture" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^source-is-capture('; then
  pass "a sources entry naming a capture record is reported"
else
  bad "a citation of a capture record was not reported: $out"
fi

if "$CHECKER" check "$FIX/docs-external" "$RAW" >/dev/null 2>&1; then
  pass "an external rationale with a URL and a retrieval date conforms"
else
  bad "a complete external rationale failed: $("$CHECKER" check "$FIX/docs-external" "$RAW" 2>&1)"
fi

out=$("$CHECKER" check "$FIX/docs-external-incomplete" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^external-claim-incomplete('; then
  pass "an external claim missing its URL and date is reported"
else
  bad "an unsourced external claim was not reported: $out"
fi

# The schema page displays the marker inside backticks to describe it. A page
# writing about the vocabulary is not making the claim.
if "$CHECKER" check docs thoughts >/dev/null 2>&1; then
  pass "this repository's own pages still pass under the new rules"
else
  bad "the repository's docs failed: $("$CHECKER" check docs thoughts 2>&1)"
fi

# --- the log ---------------------------------------------------------------

# Compiling twice in a day is the ordinary case once capture starts offering a
# run after each published record. Two entries under one date is what that
# looks like, and it passes.
if "$CHECKER" check "$FIX/docs-log-ok" "$RAW" >/dev/null 2>&1; then
  pass "a log with two entries under one date passes"
else
  bad "a same-day append failed: $("$CHECKER" check "$FIX/docs-log-ok" "$RAW" 2>&1)"
fi

out=$("$CHECKER" check "$FIX/docs-log-duplicate-date" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^log-date-order('; then
  pass "a log with two sections for one date is reported"
else
  bad "a duplicated date section was not reported: $out"
fi

out=$("$CHECKER" check "$FIX/docs-log-malformed" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^log-date-format('; then
  pass "a malformed log heading is reported"
else
  bad "a malformed log heading was not reported: $out"
fi

exit "$fail"
