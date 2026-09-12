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

# check now reads .kb/schema.md, .kb/pages.tsv and .kb/provenance.tsv from the
# working directory, while every fixture bundle below is read-only content
# under scripts/fixtures/. schema_root builds a small scratch directory
# carrying only a .kb/schema.md whose map: and decisions: point at a fixture
# bundle by absolute path, so the state check reads and the content it
# inspects live in two different places and a run never writes into a tracked
# fixture.
schema_root() {
  local name="$1" map="$2" decisions="$3" dir
  dir="$SCRATCH/schema-$name"
  mkdir -p "$dir/.kb"
  {
    echo "---"
    echo "map: $map"
    echo "decisions: $decisions"
    echo "---"
  } >"$dir/.kb/schema.md"
  printf '%s\n' "$dir"
}

# Registers one or more pages in a schema_root's .kb/pages.tsv via pages-commit,
# so decision-id and fingerprint checks — both gated on registration — have
# something to fire on.
register_pages() {
  local root="$1" stage
  shift
  stage="$root/.pages-stage"
  printf '%s\n' "$@" >"$stage"
  (cd "$root" && "$CHECKER" pages-commit "$stage" >/dev/null)
}

# The fixture bundles carry hand-written identifiers rather than assigned ones.
# An assertion against a value the checker would recompute the same way could
# never disagree with it; a stored opaque string can.

DECROOT=$(schema_root decisions "$FIX/docs-decisions/index.md" "$FIX/docs-decisions/decisions")
register_pages "$DECROOT" \
  "$FIX/docs-decisions/decisions/0001-alpha.md" "$FIX/docs-decisions/decisions/0002-beta.md"
if (cd "$DECROOT" && "$CHECKER" check "$FIX/docs-decisions" >/dev/null 2>&1); then
  pass "a bundle whose decision pages carry distinct identifiers conforms"
else
  bad "the conforming fixture bundle did not pass: $(cd "$DECROOT" && "$CHECKER" check "$FIX/docs-decisions" 2>&1)"
fi

MISSROOT=$(schema_root missing-id "$FIX/docs-missing-id/index.md" "$FIX/docs-missing-id/decisions")
register_pages "$MISSROOT" "$FIX/docs-missing-id/decisions/0001-gamma.md"
out=$(cd "$MISSROOT" && "$CHECKER" check "$FIX/docs-missing-id" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^decision-id-missing('; then
  pass "a decision page with no identifier is reported"
else
  bad "missing identifier not reported: $out"
fi

DUPROOT=$(schema_root duplicate-id "$FIX/docs-duplicate-id/index.md" "$FIX/docs-duplicate-id/decisions")
register_pages "$DUPROOT" \
  "$FIX/docs-duplicate-id/decisions/0001-delta.md" "$FIX/docs-duplicate-id/decisions/0002-epsilon.md"
out=$(cd "$DUPROOT" && "$CHECKER" check "$FIX/docs-duplicate-id" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^decision-id-duplicate('; then
  pass "two pages sharing an identifier are reported"
else
  bad "duplicate identifier not reported: $out"
fi

# A row is committed against a resource that exists, then the resource is
# deleted: source-missing fires regardless of anything the row carries — the
# old `retired: true` escape hatch has no successor in provenance.tsv.
RETROOT=$(schema_root retired-gone "$FIX/docs-retired-gone/index.md" "$FIX/docs-retired-gone/decisions")
retres="$RETROOT/gone.md"
printf 'the resource\n' >"$retres"
printf '%s\tgone\t%s\t(whole)\n' "$FIX/docs-retired-gone/decisions/0001-retired.md" "$retres" >"$RETROOT/stage"
(cd "$RETROOT" && "$CHECKER" provenance-commit stage >/dev/null)
rm "$retres"
out=$(cd "$RETROOT" && "$CHECKER" check "$FIX/docs-retired-gone" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^source-missing('; then
  pass "a vanished source is reported once it is gone, whatever the row once carried"
else
  bad "a vanished source was not reported: $out"
fi

ANCROOT=$(schema_root anchor "$FIX/docs-anchor/index.md" "$FIX/docs-anchor/decisions")
out=$(cd "$ANCROOT" && "$CHECKER" check "$FIX/docs-anchor" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^dead-anchor(.*no-such-heading'; then
  pass "an anchor matching no heading is reported"
else
  bad "a dead anchor was not reported: $out"
fi

out=$(cd "$ANCROOT" && "$CHECKER" check "$FIX/docs-anchor" 2>&1)
if ! printf '%s\n' "$out" | grep -qE 'dead-anchor\(.*(the-rule|okf-v02-pinned|never-checked)'; then
  pass "live, duplicate-suffixed, punctuated and fenced anchors are not reported"
else
  bad "the slug rule produced a false failure: $out"
fi

OPENROOT=$(schema_root open-marker "$FIX/docs-open-marker/index.md" "$FIX/docs-open-marker/decisions")
out=$(cd "$OPENROOT" && "$CHECKER" check "$FIX/docs-open-marker" 2>&1)
if printf '%s\n' "$out" | grep -q '^open-marker(' &&
  ! printf '%s\n' "$out" | grep -q 'inferred'; then
  pass "an [unknown] marker is noted and [inferred] is left alone"
else
  bad "the open-marker rule did not behave: $out"
fi

if (cd "$OPENROOT" && "$CHECKER" check "$FIX/docs-open-marker" >/dev/null 2>&1); then
  pass "an [unknown] marker does not fail the run"
else
  bad "an advisory finding set a non-zero exit: $(cd "$OPENROOT" && "$CHECKER" check "$FIX/docs-open-marker" 2>&1)"
fi

# check_footnote_join now joins a provenance row against a [^label]:
# definition rather than a sources[] entry against a [^label] citation. A
# citation naming a label with neither a row nor a definition is prose, and
# nothing reports on it any more — hid's dedicated fixture covers unjoined-
# footnote and unregistered-citation; this fixture keeps unused-source, the
# fenced exclusion and the joined-and-cited case that produces nothing.
FNROOT=$(schema_root footnote "$FIX/docs-footnote/index.md" "$FIX/docs-footnote/decisions")
printf '%s\tjoined\t%s\t(whole)\n%s\tspare\t%s\t(whole)\n' \
  "$FIX/docs-footnote/decisions/0001-join.md" "$FIX/docs-decisions/decisions/0001-alpha.md" \
  "$FIX/docs-footnote/decisions/0001-join.md" "$FIX/docs-decisions/decisions/0002-beta.md" \
  >"$FNROOT/stage"
(cd "$FNROOT" && "$CHECKER" provenance-commit stage >/dev/null)

out=$(cd "$FNROOT" && "$CHECKER" check "$FIX/docs-footnote" 2>&1)
if printf '%s\n' "$out" | grep -q '^unused-source(.*spare'; then
  pass "a provenance row nothing cites is noted"
else
  bad "an uncited row was not noted: $out"
fi

out=$(cd "$FNROOT" && "$CHECKER" check "$FIX/docs-footnote" 2>&1)
if ! printf '%s\n' "$out" | grep -qE '(unjoined-footnote|unused-source)\(.*joined' &&
  ! printf '%s\n' "$out" | grep -q 'example'; then
  pass "a joined-and-cited row and a fenced example are left alone"
else
  bad "the footnote join produced a false failure: $out"
fi

# fragment-missing: a row committed while the resource had enough lines, then
# the resource shrinks. provenance-commit itself would refuse an out-of-range
# fragment at commit time, so drift is the only way this state arises.
FRAGROOT="$SCRATCH/fragment-missing"
mkdir -p "$FRAGROOT/.kb" "$FRAGROOT/docs/decisions"
{
  echo "---"
  echo "map: docs/index.md"
  echo "decisions: docs/decisions"
  echo "---"
} >"$FRAGROOT/.kb/schema.md"
printf '# Index\n\n- [Page](decisions/page.md)\n' >"$FRAGROOT/docs/index.md"
cat >"$FRAGROOT/docs/decisions/page.md" <<'EOF'
# Page

A claim.[^r]

[^r]: `res.md`, lines 1-2.
EOF
printf 'one\ntwo\n' >"$FRAGROOT/res.md"
printf 'docs/decisions/page.md\tr\tres.md\tL1-L2\n' >"$FRAGROOT/stage"
(cd "$FRAGROOT" && "$CHECKER" provenance-commit stage >/dev/null)
printf 'one\n' >"$FRAGROOT/res.md"
out=$(cd "$FRAGROOT" && "$CHECKER" check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^fragment-missing('; then
  pass "a cited range that no longer fits the resource is reported"
else
  bad "an out-of-range fragment was not reported: $out"
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
# Comment lines are stripped: the claim is about what the implementation does,
# and the comments are where the absence is explained.
code_of_checker() { grep -vE '^[[:space:]]*#' "$CHECKER"; }

if code_of_checker | grep -nE 'sleep|timeout|stale.after|poll|interval|attempts' >/dev/null; then
  bad "the checker names a duration or a repeat count: $(code_of_checker | grep -nE 'sleep|timeout|stale.after|poll|interval|attempts')"
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
DEPROOT=$(schema_root deprecation "$FIX/docs-deprecation/index.md" "$FIX/docs-deprecation/decisions")
register_pages "$DEPROOT" \
  "$FIX/docs-deprecation/decisions/0001-stable.md" \
  "$FIX/docs-deprecation/decisions/0002-deprecated-with-successor.md" \
  "$FIX/docs-deprecation/decisions/0003-successor.md" \
  "$FIX/docs-deprecation/decisions/0004-deprecated-no-successor.md"
if (cd "$DEPROOT" && "$CHECKER" check "$FIX/docs-deprecation" >/dev/null 2>&1); then
  pass "stable, deprecated-with-successor and deprecated-without all conform"
else
  bad "the deprecation bundle failed: $(cd "$DEPROOT" && "$CHECKER" check "$FIX/docs-deprecation" 2>&1)"
fi

DANGROOT=$(schema_root deprecation-dangling "$FIX/docs-deprecation-dangling/index.md" "$FIX/docs-deprecation-dangling/decisions")
out=$(cd "$DANGROOT" && "$CHECKER" check "$FIX/docs-deprecation-dangling" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^superseded-by-dangling('; then
  pass "a superseded_by naming no page is reported"
else
  bad "a dangling successor was not reported: $out"
fi

# A deprecated page is kept for links and history, so the checker grants it no
# reachability exemption.
UNREACHROOT=$(schema_root deprecation-unreachable "$FIX/docs-deprecation-unreachable/index.md" "$FIX/docs-deprecation-unreachable/decisions")
out=$(cd "$UNREACHROOT" && "$CHECKER" check "$FIX/docs-deprecation-unreachable" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^unreachable(.*0002-orphan'; then
  pass "a deprecated page still has to be reachable from the index"
else
  bad "an unlinked deprecated page was not reported: $out"
fi

# The resource lives in $SCRATCH rather than under the tracked fixture, so it
# can be edited after the row is committed without leaving the fixture dirty.
DRIFTROOT=$(schema_root deprecation-drift "$FIX/docs-deprecation-drift/index.md" "$FIX/docs-deprecation-drift/decisions")
driftres="$DRIFTROOT/resource.md"
printf 'the rule as it stood\n' >"$driftres"
printf '%s\tfixture-page\t%s\t(whole)\n' "$FIX/docs-deprecation-drift/decisions/0001-drifted.md" "$driftres" \
  >"$DRIFTROOT/stage"
(cd "$DRIFTROOT" && "$CHECKER" provenance-commit stage >/dev/null)
printf 'the rule as it stood, edited\n' >"$driftres"
out=$(cd "$DRIFTROOT" && "$CHECKER" check "$FIX/docs-deprecation-drift" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^source-drift('; then
  pass "a deprecated page's sources are still provenance-checked"
else
  bad "a deprecated page escaped provenance checking: $out"
fi

# --- what a page may cite --------------------------------------------------

RAW="$PWD/scripts/fixtures/raw"

# provenance-commit itself refuses a row inside the raw root or naming a
# capture record — that is the whole point of the two checks below — so these
# two rows are written straight into .kb/provenance.tsv rather than staged
# through it, the way a hand-edited or migrated ledger would arrive.
SRAWROOT=$(schema_root source-raw "$FIX/docs-source-raw/index.md" "$FIX/docs-source-raw/decisions")
printf '%s\tthe-note\t%s\t(whole)\t000000000000\n' \
  "$FIX/docs-source-raw/decisions/0001-cites-a-note.md" "$RAW/note.md" >"$SRAWROOT/.kb/provenance.tsv"
out=$(cd "$SRAWROOT" && "$CHECKER" check "$FIX/docs-source-raw" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^source-in-raw-root('; then
  pass "a provenance row naming a path inside the raw root is reported"
else
  bad "a citation into the raw layer was not reported: $out"
fi

SCAPROOT=$(schema_root source-capture "$FIX/docs-source-capture/index.md" "$FIX/docs-source-capture/decisions")
printf '%s\tthe-record\t%s\t(whole)\t000000000000\n' \
  "$FIX/docs-source-capture/decisions/0001-cites-a-record.md" "$RAW/captures/rec.md" >"$SCAPROOT/.kb/provenance.tsv"
out=$(cd "$SCAPROOT" && "$CHECKER" check "$FIX/docs-source-capture" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^source-is-capture('; then
  pass "a provenance row naming a capture record is reported"
else
  bad "a citation of a capture record was not reported: $out"
fi

EXTROOT=$(schema_root external "$FIX/docs-external/index.md" "$FIX/docs-external/decisions")
if (cd "$EXTROOT" && "$CHECKER" check "$FIX/docs-external" "$RAW" >/dev/null 2>&1); then
  pass "an external rationale with a URL and a retrieval date conforms"
else
  bad "a complete external rationale failed: $(cd "$EXTROOT" && "$CHECKER" check "$FIX/docs-external" "$RAW" 2>&1)"
fi

EXTBADROOT=$(schema_root external-incomplete "$FIX/docs-external-incomplete/index.md" "$FIX/docs-external-incomplete/decisions")
out=$(cd "$EXTBADROOT" && "$CHECKER" check "$FIX/docs-external-incomplete" "$RAW" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^external-claim-incomplete('; then
  pass "an external claim missing its URL and date is reported"
else
  bad "an unsourced external claim was not reported: $out"
fi

# The schema page displays the marker inside backticks to describe it. A page
# writing about the vocabulary is not making the claim.
#
# This repository has no .kb/schema.md of its own yet — that migration is the
# next task — so this case is expected to go red with schema-missing until
# then, exactly as the brief for this task says it should.
if "$CHECKER" check docs thoughts >/dev/null 2>&1; then
  pass "this repository's own pages still pass under the new rules"
else
  bad "the repository's docs failed: $("$CHECKER" check docs thoughts 2>&1)"
fi

# --- what capture writes ---------------------------------------------------

expect_capture 0 as-capture-writes.md ""

# Capture never writes the compiled layer, and it proves that after the write
# rather than by reading `git status` — a project may hide a directory from git,
# and a write into it then shows up nowhere.
SCOPE="$SCRATCH/scope"
mkdir -p "$SCOPE/docs" "$SCOPE/thoughts/captures" "$SCOPE/staged"
echo "a page" >"$SCOPE/docs/page.md"

scope_manifest=$(cd "$SCOPE" && "$CHECKER" snapshot docs)
echo "a staged record" >"$SCOPE/staged/rec.md"
mv "$SCOPE/staged/rec.md" "$SCOPE/thoughts/captures/rec.md"
if (cd "$SCOPE" && "$CHECKER" verify-sources "$scope_manifest" docs >/dev/null 2>&1); then
  pass "publishing a record leaves the compiled layer untouched"
else
  bad "publishing was seen as a write to the compiled layer"
fi

echo "an errant write" >>"$SCOPE/docs/page.md"
out=$(cd "$SCOPE" && "$CHECKER" verify-sources "$scope_manifest" docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^SOURCE-CHANGED'; then
  pass "a write into the compiled layer is caught by the scope check"
else
  bad "an errant write to the compiled layer went unreported: $out"
fi

# --- which captures a run may take in --------------------------------------

ELIG="$FIX/records-eligible"
ELIG_LEDGER="$SCRATCH/eligible-root"
NOLEDGER="$SCRATCH/no-ledger"
rm -rf "$ELIG_LEDGER" "$NOLEDGER"; mkdir -p "$ELIG_LEDGER/.kb" "$NOLEDGER"
elig_id=$("$CHECKER" assign-id "$ELIG/r1.md" 2>/dev/null)
printf 'capture\tr1.md\tThe first decision, already compiled\t%s\tconsumed\n' "$elig_id" \
  >"$ELIG_LEDGER/.kb/consumed.tsv"
printf 'capture\tr1.md\tThe second decision, routed nowhere yet\t%s\tdeferred\n' "$elig_id" \
  >>"$ELIG_LEDGER/.kb/consumed.tsv"

out=$(cd "$ELIG_LEDGER" && "$CHECKER" captures-eligible "$ELIG" 2>&1)
if [ $? -eq 0 ] &&
  ! printf '%s\n' "$out" | grep -q 'The first decision' &&
  printf '%s\n' "$out" | grep -q 'The second decision' &&
  printf '%s\n' "$out" | grep -q 'A decision nobody has seen'; then
  pass "eligibility is the decisions no run has consumed, computed rather than chosen"
else
  bad "eligibility was wrong: $out"
fi

out=$(cd "$NOLEDGER" && "$CHECKER" captures-eligible "$ELIG" 2>&1)
if [ "$(printf '%s\n' "$out" | grep -c '###\|decision')" -ge 3 ]; then
  pass "with no ledger every decision is eligible"
else
  bad "an absent ledger did not make everything eligible: $out"
fi

out=$(cd "$ELIG_LEDGER" && "$CHECKER" captures-deferred "$ELIG" 2>&1)
if [ $? -eq 0 ] &&
  printf '%s\n' "$out" | grep -q 'The second decision' &&
  ! printf '%s\n' "$out" | grep -q 'A decision nobody has seen'; then
  pass "the deferred set is what a run looked at and left, not what it never saw"
else
  bad "the deferred set was wrong: $out"
fi

# --- the session-end marker ------------------------------------------------

HOOK="$PWD/plugins/kb/hooks/mark-unpublished-capture.sh"
HREPO="$SCRATCH/hook-repo"
mkdir -p "$HREPO/thoughts/captures" "$HREPO/docs"
git -C "$HREPO" init -q
hgit=$(git -C "$HREPO" rev-parse --absolute-git-dir)
mkdir -p "$hgit/kb-staged"
echo "# Capture: prepared and never published" >"$hgit/kb-staged/s1-1.md"

(cd "$HREPO" && printf '{"session_id":"s1"}' | "$HOOK")
marker="$hgit/kb-capture-markers/s1"
if [ -f "$marker" ] && grep -q 'kb-staged/s1-1.md' "$marker"; then
  pass "the hook leaves a marker pointing at the staged record"
else
  bad "no marker was written"
fi

before=$(cat "$marker")
(cd "$HREPO" && printf '{"session_id":"s1"}' | "$HOOK")
if [ "$(cat "$marker")" = "$before" ]; then
  pass "a second fire for one session overwrites the marker rather than appending"
else
  bad "the marker grew on the second fire: $(cat "$marker")"
fi

# The marker lives under the git directory, so neither a snapshot of the raw
# layer nor git status can see it.
hook_manifest=$(cd "$HREPO" && "$CHECKER" snapshot thoughts)
(cd "$HREPO" && printf '{"session_id":"s2"}' | "$HOOK")
if (cd "$HREPO" && "$CHECKER" verify-sources "$hook_manifest" thoughts >/dev/null 2>&1) &&
  [ -z "$(git -C "$HREPO" status --porcelain)" ]; then
  pass "the marker appears in no snapshot and in no git status"
else
  bad "the marker leaked into the working tree"
fi

# The hook writes no record: it points at one the skill already wrote.
if [ -z "$(find "$HREPO/thoughts" "$HREPO/docs" -type f)" ]; then
  pass "the hook writes no record and touches neither layer"
else
  bad "the hook wrote into a layer: $(find "$HREPO/thoughts" "$HREPO/docs" -type f)"
fi

# Nothing retries on its own. Two stuck items are two files, with no ordering
# between them and no count anywhere.
echo "# Capture: a second prepared record" >"$hgit/kb-staged/s3-1.md"
(cd "$HREPO" && printf '{"session_id":"s3"}' | "$HOOK")
if [ -f "$hgit/kb-capture-markers/s1" ] && [ -f "$hgit/kb-capture-markers/s3" ]; then
  pass "two stuck items neither order nor block each other"
else
  bad "one stuck item displaced the other"
fi

# The two runtimes name the plugin root differently — Claude Code substitutes
# ${CLAUDE_PLUGIN_ROOT} and Codex substitutes ${PLUGIN_ROOT} — so the command
# tries both spellings and runs whichever one resolves to a real script. The
# other resolves to nothing, whether the runtime substitutes it textually or
# exports it, and the -x test skips it.
hook_command=$(sed -n 's/.*"command": "\(.*\)"$/\1/p' "$PWD/plugins/kb/hooks/hooks.json" |
  sed -e 's/\\"/"/g')
run_hook_command() {
  out=$(CLAUDE_PLUGIN_ROOT="$1" PLUGIN_ROOT="$2" \
    sh -c "cd '$HREPO' && printf '{\"session_id\":\"$3\"}' | $hook_command" 2>&1)
  [ $? -eq 0 ] || bad "the hook command exited non-zero for $3: $out"
}
run_hook_command "$PWD/plugins/kb" "" s4
run_hook_command "" "$PWD/plugins/kb" s5
run_hook_command "" "" s6
if [ -f "$hgit/kb-capture-markers/s4" ] && [ -f "$hgit/kb-capture-markers/s5" ]; then
  pass "the hook command resolves the plugin root under either runtime's spelling"
else
  bad "one spelling of the plugin root did not run the hook"
fi
if [ ! -f "$hgit/kb-capture-markers/s6" ]; then
  pass "with neither spelling set the hook does nothing and still exits clean"
else
  bad "the hook ran with no plugin root"
fi

if grep -vE '^[[:space:]]*#' "$HOOK" | grep -nEi 'sleep|retry|attempt|expir|timeout' >/dev/null; then
  bad "the hook schedules or counts something: $(grep -vE '^[[:space:]]*#' "$HOOK" | grep -nEi 'sleep|retry|attempt|expir|timeout')"
else
  pass "nothing in the hook retries, counts down or expires"
fi

# --- what a fence encloses is quotation, not record --------------------------

# A record quotes the shape it follows, and the quotation opens with a fence
# marker of the other character. A fence closes only on the character it opened
# with, so everything after that marker is still inside the block.
out=$(cd "$NOLEDGER" && "$CHECKER" captures-eligible "$FIX/records-fenced" 2>&1)
if [ "$out" = "$(printf 'a.md\tAlpha\nb.md\tBeta\nb.md\tGamma')" ]; then
  pass "a quoted heading is not a decision, and the real one after it still is"
else
  bad "the fenced record enumerated the wrong decisions: $out"
fi

out=$("$CHECKER" supersession-scan "$FIX/records-fenced" "$FIX/docs-decisions" \
  "record a.md ### Alpha" 2>&1)
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q '^supersession-scan: nothing supersedes'; then
  pass "a quoted Supersedes: line declares nothing"
else
  bad "a quoted reference was read as an edge: $out"
fi

# Two records superseded by one later record is an order, not a loop: the walk
# reaches the last one twice and must still call the family terminal.
out=$("$CHECKER" supersession-scan "$FIX/records-diamond" "$FIX/docs-decisions" \
  "record t.md ### T" 2>&1)
if [ $? -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c '^record ')" -eq 3 ]; then
  pass "two paths meeting at one superseder is a family, not a circle"
else
  bad "a converging family was rejected: $out"
fi

# The circle here never returns to the target, so a check that compares each
# superseder against the target alone hands weave a loop to deprecate from.
out=$("$CHECKER" supersession-scan "$FIX/records-cycle-reachable" "$FIX/docs-decisions" \
  "record a.md ### A" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^supersession-cycle('; then
  pass "a circle past the target is still a circle"
else
  bad "a circle beyond the target was reported as a chain: $out"
fi

# --- a value on stdout, everything else on stderr ----------------------------

# Two consecutive spaces in a path is the case a whitespace-split manifest
# cannot tell apart, and catching a write git cannot see is the whole point of
# the manifest.
SPACED="$SCRATCH/spaced"
mkdir -p "$SPACED/raw"
printf 'one\n' >"$SPACED/raw/a  one"
printf 'two\n' >"$SPACED/raw/a  two"
spaced_manifest=$(cd "$SPACED" && "$CHECKER" snapshot raw 2>/dev/null)
printf 'edited\n' >"$SPACED/raw/a  one"
out=$(cd "$SPACED" && "$CHECKER" verify-sources "$spaced_manifest" raw 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^SOURCE-CHANGED'; then
  pass "two paths differing only past a double space are two files"
else
  bad "a double-space path collapsed onto its neighbour: $out"
fi

# assign-id, claim-acquire and snapshot are read in a command substitution, so
# a finding on stdout is read as the value.
out=$("$CHECKER" assign-id "$SCRATCH/no-such-page.md" 2>/dev/null)
if [ $? -ne 0 ] && [ -z "$out" ]; then
  pass "a mode whose stdout is a value prints no finding on it"
else
  bad "a finding reached the stream a caller reads the value from: $out"
fi

# --- which raw sources a run may still take in ------------------------------

INTK="$SCRATCH/intake"
mkdir -p "$INTK/thoughts/research" "$INTK/thoughts/captures" "$INTK/.kb"
echo "a note nobody compiled" >"$INTK/thoughts/research/new.md"
echo "a note compiled as is" >"$INTK/thoughts/research/same.md"
echo "a note compiled, then edited" >"$INTK/thoughts/research/edited.md"
echo "a note read and found homeless" >"$INTK/thoughts/research/homeless.md"
echo "a capture record" >"$INTK/thoughts/captures/rec.md"
consumed_ledger="$INTK/.kb/consumed.tsv"
same_hash=$(shasum -a 256 "$INTK/thoughts/research/same.md" | awk '{print $1}')
homeless_hash=$(shasum -a 256 "$INTK/thoughts/research/homeless.md" | awk '{print $1}')
printf 'note\tresearch/same.md\t\t%s\tconsumed\n' "$same_hash" >"$consumed_ledger"
printf 'note\tresearch/edited.md\t\t%s\tconsumed\n' "0000000000000000000000000000000000000000000000000000000000000000" >>"$consumed_ledger"
printf 'note\tresearch/homeless.md\t\t%s\tno-home\n' "$homeless_hash" >>"$consumed_ledger"

out=$(cd "$INTK" && "$CHECKER" sources-pending thoughts 2>&1)
if [ $? -eq 0 ] &&
  printf '%s\n' "$out" | awk -F'\t' '$1 == "research/new.md" && $2 == "new" {f = 1} END {exit f ? 0 : 1}' &&
  printf '%s\n' "$out" | awk -F'\t' '$1 == "research/edited.md" && $2 == "changed" {f = 1} END {exit f ? 0 : 1}' &&
  ! printf '%s\n' "$out" | grep -q 'same.md' &&
  ! printf '%s\n' "$out" | grep -q 'homeless.md' &&
  ! printf '%s\n' "$out" | grep -q 'captures/'; then
  pass "pending is new plus changed, minus consumed, homeless and captures"
else
  bad "pending was wrong: $out"
fi

rm -rf "$INTK/.kb"
out=$(cd "$INTK" && "$CHECKER" sources-pending thoughts 2>&1)
if [ "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "new"' | wc -l | tr -d ' ')" -eq 4 ] &&
  ! printf '%s\n' "$out" | grep -q 'captures/'; then
  pass "with no ledger every non-capture source is new"
else
  bad "an absent ledger did not make everything new: $out"
fi
out=$(cd "$INTK" && "$CHECKER" sources-pending nowhere 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^NO-RAW-ROOT(sources-pending)'; then
  pass "a missing raw root is reported"
else
  bad "a missing raw root was not reported: $out"
fi

# Skipped by a root user, whom sha256_file can still read; the harness runs unprivileged.
echo "unreadable" >"$INTK/thoughts/research/locked.md"
chmod 000 "$INTK/thoughts/research/locked.md"
out=$(cd "$INTK" && "$CHECKER" sources-pending thoughts 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^HASH-FAILED(sources-pending)'; then
  pass "a file that cannot be hashed fails the run rather than recording an empty hash"
else
  bad "an unhashable file was swallowed: $out"
fi
chmod 644 "$INTK/thoughts/research/locked.md"
rm "$INTK/thoughts/research/locked.md"

# --- consumed.tsv -----------------------------------------------------------

# One ledger for both kinds. A capture row hashes the normalized body the way
# the receipt did; a note row hashes the whole file the way the intake did.
CONS="$SCRATCH/cons"
rm -rf "$CONS"; mkdir -p "$CONS/thoughts/captures" "$CONS/thoughts/research" "$CONS/.kb"
cat >"$CONS/thoughts/captures/r1.md" <<'EOF'
---
session: s1
---
## Decisions

### Use one ledger

Because two disagree.
EOF
printf 'a note\n' >"$CONS/thoughts/research/n1.md"
printf 'capture\tr1.md\tUse one ledger\tconsumed\nnote\tresearch/n1.md\t\tconsumed\n' >"$CONS/stage"

out=$(cd "$CONS" && "$CHECKER" consumed-commit thoughts "$CONS/stage" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(wc -l <"$CONS/.kb/consumed.tsv")" -eq 2 ] \
  && grep -q "^capture	r1.md	Use one ledger	[0-9a-f]\{12\}	consumed$" "$CONS/.kb/consumed.tsv" \
  && grep -q "^note	research/n1.md		[0-9a-f]\{64\}	consumed$" "$CONS/.kb/consumed.tsv"; then
  pass "consumed-commit writes one row per staged line, hash computed per kind"
else
  bad "consumed-commit: rc=$rc $out $(cat "$CONS/.kb/consumed.tsv" 2>&1)"
fi

# A capture row with the wrong heading is refused before anything is written.
printf 'capture\tr1.md\tNo such heading\tconsumed\n' >"$CONS/stage2"
before=$(cat "$CONS/.kb/consumed.tsv")
out=$(cd "$CONS" && "$CHECKER" consumed-commit thoughts "$CONS/stage2" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -q 'consumed-heading-missing' && [ "$(cat "$CONS/.kb/consumed.tsv")" = "$before" ]; then
  pass "consumed-commit refuses a capture heading the record lacks and writes nothing"
else
  bad "consumed-commit heading: rc=$rc $out"
fi

# An unchanged note stays green and produces no consumed-note-changed finding.
out=$(cd "$CONS" && "$CHECKER" consumed-check thoughts 2>&1); rc=$?
if [ "$rc" -eq 0 ] && ! echo "$out" | grep -q 'consumed-note-changed'; then
  pass "consumed-check stays quiet on a note that has not changed"
else
  bad "consumed-check unchanged note: rc=$rc $out"
fi

# An edited note is a note; an edited capture is a report.
printf 'a note, edited\n' >"$CONS/thoughts/research/n1.md"
out=$(cd "$CONS" && "$CHECKER" consumed-check thoughts 2>&1); rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'consumed-note-changed(research/n1.md)'; then
  pass "consumed-check notes a changed note and stays green"
else
  bad "consumed-check note: rc=$rc $out"
fi
printf '\nedited\n' >>"$CONS/thoughts/captures/r1.md"
out=$(cd "$CONS" && "$CHECKER" consumed-check thoughts 2>&1); rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -q 'consumed-capture-changed(r1.md)'; then
  pass "consumed-check reports an edited capture record"
else
  bad "consumed-check capture: rc=$rc $out"
fi

# sources-pending reads note rows only; the edited note is back in the queue.
out=$(cd "$CONS" && "$CHECKER" sources-pending thoughts 2>/dev/null)
if [ "$out" = "$(printf 'research/n1.md\tchanged')" ]; then
  pass "sources-pending lists the edited note as changed from the one ledger"
else
  bad "sources-pending: [$out]"
fi

# captures-eligible reads capture rows only.
cat >"$CONS/thoughts/captures/r2.md" <<'EOF'
---
session: s2
---
## Decisions

### Second decision

Text.
EOF
out=$(cd "$CONS" && "$CHECKER" captures-eligible thoughts/captures 2>/dev/null)
if [ "$out" = "$(printf 'r2.md\tSecond decision')" ]; then
  pass "captures-eligible skips the consumed decision and lists the new one"
else
  bad "captures-eligible: [$out]"
fi

# The old files are not read: a docs/kb-receipt.tsv is ignored.
mkdir -p "$CONS/docs"
printf 'r2.md\tdeadbeef0000\tconsumed\tSecond decision\n' >"$CONS/docs/kb-receipt.tsv"
out=$(cd "$CONS" && "$CHECKER" captures-eligible thoughts/captures 2>/dev/null)
if [ "$out" = "$(printf 'r2.md\tSecond decision')" ]; then
  pass "no mode reads a receipt file"
else
  bad "receipt still read: [$out]"
fi

# No .kb/ directory: every read mode treats the ledger as empty, the commit mode creates it.
rm -rf "$CONS/.kb"
out=$(cd "$CONS" && "$CHECKER" sources-pending thoughts 2>/dev/null | wc -l | tr -d ' ')
if [ "$out" = "1" ]; then
  pass "sources-pending with no .kb/ lists the one note as new"
else
  bad "sources-pending no .kb: $out"
fi
out=$(cd "$CONS" && "$CHECKER" consumed-commit thoughts "$CONS/stage" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$CONS/.kb/consumed.tsv" ]; then
  pass "consumed-commit creates .kb/ when absent"
else
  bad "consumed-commit mkdir: rc=$rc $out"
fi

if code_of_checker | grep -nEi 'expir|deadline' >/dev/null; then
  bad "the checker names an expiry: $(code_of_checker | grep -nEi 'expir|deadline')"
else
  pass "a deferred decision carries no expiry, and none exists in the checker"
fi

# --- consumed-commit shape checks --------------------------------------------

CSHAPE="$SCRATCH/cshape"
rm -rf "$CSHAPE"; mkdir -p "$CSHAPE/captures" "$CSHAPE/research"
cat >"$CSHAPE/captures/r1.md" <<'EOF'
---
session: s1
---
## Decisions

### A decision

Because.
EOF
printf 'a note\n' >"$CSHAPE/research/n1.md"

printf 'capture\tr1.md\t\tconsumed\n' >"$CSHAPE/stage-no-unit"
out=$("$CHECKER" consumed-commit "$CSHAPE" "$CSHAPE/stage-no-unit" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-unit('; then
  pass "consumed-commit refuses a capture row with no heading"
else
  bad "an empty capture unit was accepted: $out"
fi

printf 'note\tresearch/n1.md\tsomething\tconsumed\n' >"$CSHAPE/stage-note-unit"
out=$("$CHECKER" consumed-commit "$CSHAPE" "$CSHAPE/stage-note-unit" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-unit('; then
  pass "consumed-commit refuses a note row carrying a unit"
else
  bad "a note row with a unit was accepted: $out"
fi

printf 'note\tcaptures/r1.md\t\tconsumed\n' >"$CSHAPE/stage-note-captures"
out=$("$CHECKER" consumed-commit "$CSHAPE" "$CSHAPE/stage-note-captures" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-in-captures('; then
  pass "consumed-commit refuses a note row naming a path under captures/"
else
  bad "a note row under captures/ was accepted: $out"
fi

printf 'sideways\tr1.md\t\tconsumed\n' >"$CSHAPE/stage-bad-kind"
out=$("$CHECKER" consumed-commit "$CSHAPE" "$CSHAPE/stage-bad-kind" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-kind('; then
  pass "consumed-commit refuses an unknown kind"
else
  bad "an unknown kind was accepted: $out"
fi

printf 'capture\tr1.md\tA decision\tmaybe\n' >"$CSHAPE/stage-bad-state"
out=$("$CHECKER" consumed-commit "$CSHAPE" "$CSHAPE/stage-bad-state" 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-state('; then
  pass "consumed-commit refuses a state that is not valid for the row's kind"
else
  bad "an invalid state was accepted: $out"
fi

# --- consumed-check catches what consumed-commit would have refused ---------

# A hand-edited ledger, or a migration script's direct write, never passes
# through consumed-commit's validation — consumed-check must still catch a
# malformed row, not just the raw layer having moved on.
CCHECK="$SCRATCH/ccheck"
rm -rf "$CCHECK"; mkdir -p "$CCHECK/captures" "$CCHECK/research" "$CCHECK/.kb"
cp "$CSHAPE/captures/r1.md" "$CCHECK/captures/r1.md"
printf 'a note\n' >"$CCHECK/research/n2.md"
n2_hash=$(shasum -a 256 "$CCHECK/research/n2.md" | awk '{print $1}')
r1_id=$("$CHECKER" assign-id "$CCHECK/captures/r1.md" 2>/dev/null)

printf 'note\tresearch/n2.md\tX\t%s\tconsumed\n' "$n2_hash" >"$CCHECK/.kb/consumed.tsv"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-unit('; then
  pass "consumed-check reports a note row that carries a unit"
else
  bad "a note row with a unit passed consumed-check: $out"
fi

printf 'note\tcaptures/r1.md\t\t%s\tconsumed\n' "$n2_hash" >"$CCHECK/.kb/consumed.tsv"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-in-captures('; then
  pass "consumed-check reports a note row naming a path under captures/"
else
  bad "a note row under captures/ passed consumed-check: $out"
fi

printf 'capture\tr1.md\t\t%s\tconsumed\n' "$r1_id" >"$CCHECK/.kb/consumed.tsv"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-unit(' &&
  ! printf '%s\n' "$out" | grep -q '^consumed-capture-changed('; then
  pass "consumed-check names a capture row with no heading as a shape defect, not a changed record"
else
  bad "an empty capture unit was misreported: $out"
fi

printf 'not-a-line\n' >"$CCHECK/.kb/consumed.tsv"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-malformed('; then
  pass "consumed-check reports a line with the wrong field count"
else
  bad "a malformed ledger line passed consumed-check: $out"
fi

printf 'note\tresearch/n2.md\t\tnothex\tconsumed\n' >"$CCHECK/.kb/consumed.tsv"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-hash('; then
  pass "consumed-check reports a hash that is not well-formed for its kind"
else
  bad "a malformed hash passed consumed-check: $out"
fi

printf 'note\t../outside.md\t\t%s\tconsumed\n' "$n2_hash" >"$CCHECK/.kb/consumed.tsv"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^consumed-path('; then
  pass "consumed-check reports a path that is not canonical"
else
  bad "a non-canonical path passed consumed-check: $out"
fi

printf 'note\tresearch/n2.md\t\t%s\tconsumed\n' "$n2_hash" >"$CCHECK/.kb/consumed.tsv"
rm "$CCHECK/research/n2.md"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^consumed-note-gone(research/n2.md)'; then
  pass "consumed-check notes a consumed source that is gone, and stays green"
else
  bad "a gone note was not noted, or failed the run: rc=$rc $out"
fi
printf 'a note\n' >"$CCHECK/research/n2.md"

# --- what a re-consumed and a re-appended ledger both do --------------------

# consume, edit, consume again: only the last line for the identity is compared.
printf 'a note, edited\n' >"$CCHECK/research/n2.md"
n2_edited_hash=$(shasum -a 256 "$CCHECK/research/n2.md" | awk '{print $1}')
{
  printf 'note\tresearch/n2.md\t\t%s\tconsumed\n' "$n2_hash"
  printf 'note\tresearch/n2.md\t\t%s\tconsumed\n' "$n2_edited_hash"
} >"$CCHECK/.kb/consumed.tsv"
out=$(cd "$CCHECK" && "$CHECKER" consumed-check . 2>&1)
if [ $? -eq 0 ] && ! printf '%s\n' "$out" | grep -q 'consumed-note-changed'; then
  pass "a source consumed again at its new hash is no longer noted as changed"
else
  bad "an older ledger line for a re-consumed source was compared: $out"
fi

# A ledger edited by hand may lose its final newline; the next append must not
# join two records into one line. This exercises the exact idiom
# cmd_consumed_commit uses to detect it (command substitution strips a
# trailing newline, so an unterminated last line reads as non-empty). `wc -l`
# undercounts a file whose last line has no trailing newline, so — as the
# deleted intake test did — logical rows are counted with awk's NR instead,
# which still counts a final unterminated line.
printf '%s' "$(cat "$CCHECK/.kb/consumed.tsv")" >"$CCHECK/.kb/consumed.tsv"
lines_before=$(awk 'END {print NR}' "$CCHECK/.kb/consumed.tsv")
printf 'capture\tr1.md\tA decision\tconsumed\n' >"$CCHECK/stage-append"
out=$(cd "$CCHECK" && "$CHECKER" consumed-commit . "$CCHECK/stage-append" 2>&1)
if [ $? -eq 0 ] && [ "$(awk 'END {print NR}' "$CCHECK/.kb/consumed.tsv")" -eq $((lines_before + 1)) ] &&
  (cd "$CCHECK" && "$CHECKER" consumed-check . >/dev/null 2>&1); then
  pass "an append after an unterminated last line starts a new record"
else
  bad "an unterminated ledger was corrupted by the next append: rc=$? $out $(cat "$CCHECK/.kb/consumed.tsv")"
fi

# --- .kb/schema.md, .kb/pages.tsv and .kb/provenance.tsv --------------------

# One fixture built fresh per run rather than tracked under scripts/fixtures/:
# every case below either commits or edits state, and a tracked directory
# would either accumulate that state as untracked drift or have to be reset
# by hand between cases.
HID="$SCRATCH/hid"
mkdir -p "$HID/.kb" "$HID/docs/decisions" "$HID/docs/guides" "$HID/src"
{
  echo "---"
  echo "map: docs/README.md"
  echo "decisions: docs/decisions"
  echo "---"
} >"$HID/.kb/schema.md"
cat >"$HID/docs/README.md" <<'EOF'
# Fixture Knowledge Base

- [Alpha](decisions/0001-x.md)
- [Guide](guides/g.md)
EOF
cat >"$HID/docs/guides/g.md" <<'EOF'
# A guide

An ordinary footnote raises nothing.[^note]

[^note]: just a remark.
EOF
cat >"$HID/docs/decisions/0001-x.md" <<'EOF'
---
decision_id: "aaaaaaaaaaaa"
---

# X

A claim.[^a]

[^a]: `src/a.txt`, lines 1-2.
EOF
printf 'one\ntwo\nthree\n' >"$HID/src/a.txt"

hid() { (cd "$HID" && "$CHECKER" "$@"); }
# Stages the one-row provenance line the rest of this section resets to
# between cases, so re-establishing the baseline is one call rather than a
# repeated heredoc.
stage_a() { printf 'docs/decisions/0001-x.md\ta\tsrc/a.txt\tL1-L2\n' >"$HID/prov-stage"; }

# 1. provenance-commit writes one row with a 12-hex hash; a second commit for
# the same page with a different label replaces the row rather than appending.
stage_a
out=$(hid provenance-commit prov-stage)
if [ $? -eq 0 ] && [ "$(awk -F'\t' 'END{print NR}' "$HID/.kb/provenance.tsv")" -eq 1 ] &&
  grep -Eq "^docs/decisions/0001-x\.md	a	src/a\.txt	L1-L2	[0-9a-f]{12}$" "$HID/.kb/provenance.tsv"; then
  pass "provenance-commit writes one row with a 12-hex hash"
else
  bad "provenance-commit's first write was wrong: $out $(cat "$HID/.kb/provenance.tsv")"
fi

printf 'docs/decisions/0001-x.md\tb\tsrc/a.txt\tL1-L2\n' >"$HID/prov-stage"
out=$(hid provenance-commit prov-stage)
if [ $? -eq 0 ] && [ "$(awk -F'\t' 'END{print NR}' "$HID/.kb/provenance.tsv")" -eq 1 ] &&
  grep -q "	b	" "$HID/.kb/provenance.tsv" && ! grep -q "	a	" "$HID/.kb/provenance.tsv"; then
  pass "a second commit for the same page replaces its row rather than appending"
else
  bad "provenance-commit did not replace the page's row: $(cat "$HID/.kb/provenance.tsv")"
fi

# Restore the "a" row that the rest of this section's cases build on.
stage_a
hid provenance-commit prov-stage >/dev/null

# 2. pages-commit writes page<TAB>fingerprint; committing again with no edit
# leaves the file byte-identical.
printf 'docs/decisions/0001-x.md\n' >"$HID/pstage"
hid pages-commit pstage >/dev/null
before=$(cat "$HID/.kb/pages.tsv")
hid pages-commit pstage >/dev/null
after=$(cat "$HID/.kb/pages.tsv")
if [ -n "$before" ] && [ "$before" = "$after" ]; then
  pass "pages-commit is byte-identical on a second commit with no edit"
else
  bad "a no-op pages-commit changed the file: [$before] vs [$after]"
fi

# 3. check docs is green on the fixture; README counts as a page.
out=$(hid check docs 2>&1)
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q '^OK: 3 pages under docs conform$'; then
  pass "check is green on a freshly registered fixture and counts the map as a page"
else
  bad "the fixture did not conform: $out"
fi

# 4. editing src/a.txt's first line prints source-drift with the new hash.
cp "$HID/src/a.txt" "$HID/src/a.txt.bak"
printf 'ONE\ntwo\nthree\n' >"$HID/src/a.txt"
out=$(hid check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -Eq '^source-drift\(docs/decisions/0001-x\.md\): \[\^a\] records [0-9a-f]{12} for L1-L2 of src/a\.txt, which now hashes to [0-9a-f]{12}$'; then
  pass "editing a cited resource reports source-drift with the new hash"
else
  bad "the edited resource did not drift as expected: $out"
fi
mv "$HID/src/a.txt.bak" "$HID/src/a.txt"

# 5. removing the [^a]: definition raises unjoined-footnote.
cp "$HID/docs/decisions/0001-x.md" "$HID/docs/decisions/0001-x.md.bak"
cat >"$HID/docs/decisions/0001-x.md" <<'EOF'
---
decision_id: "aaaaaaaaaaaa"
---

# X

A claim.[^a]
EOF
out=$(hid check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^unjoined-footnote(docs/decisions/0001-x.md)'; then
  pass "a provenance row with no matching definition is unjoined-footnote"
else
  bad "the missing definition was not reported: $out"
fi
mv "$HID/docs/decisions/0001-x.md.bak" "$HID/docs/decisions/0001-x.md"

# 6. the unregistered g.md's ordinary footnote raises nothing.
out=$(hid check docs 2>&1)
if ! printf '%s\n' "$out" | grep -q 'docs/guides/g.md'; then
  pass "an ordinary footnote on an unregistered page raises nothing"
else
  bad "the unregistered page's plain footnote was reported: $out"
fi

# 7. adding a definition naming a real file with no row is unregistered-citation.
cp "$HID/docs/decisions/0001-x.md" "$HID/docs/decisions/0001-x.md.bak"
cat >>"$HID/docs/decisions/0001-x.md" <<'EOF'

[^b]: `src/a.txt`, line 3.
EOF
out=$(hid check docs 2>&1)
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q '^unregistered-citation(docs/decisions/0001-x.md)'; then
  pass "a definition naming a real file with no row is unregistered-citation, and does not fail the run"
else
  bad "the unregistered citation was not noted, or it failed the run: $out"
fi
mv "$HID/docs/decisions/0001-x.md.bak" "$HID/docs/decisions/0001-x.md"

# 8. editing the registered page's prose is page-edited; pages-commit again
# clears it.
cp "$HID/docs/decisions/0001-x.md" "$HID/docs/decisions/0001-x.md.bak"
printf '\nAn edit kb:weave has not seen yet.\n' >>"$HID/docs/decisions/0001-x.md"
out=$(hid check docs 2>&1)
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q '^page-edited(docs/decisions/0001-x.md)'; then
  pass "an edit after registration is page-edited, and does not fail the run"
else
  bad "the edited page was not noted: $out"
fi
hid pages-commit pstage >/dev/null
out=$(hid check docs 2>&1)
if ! printf '%s\n' "$out" | grep -q 'page-edited'; then
  pass "re-registering the edited page clears page-edited"
else
  bad "page-edited persisted after re-registration: $out"
fi

# 9. deleting the registered page is page-gone; pages-forget removes both rows.
mv "$HID/docs/decisions/0001-x.md" "$HID/docs/decisions/0001-x.md.deleted"
out=$(hid check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^page-gone(docs/decisions/0001-x.md)'; then
  pass "a registered page missing from disk is page-gone"
else
  bad "the missing page was not reported: $out"
fi
if hid pages-forget docs/decisions/0001-x.md >/dev/null &&
  ! grep -q 'docs/decisions/0001-x.md' "$HID/.kb/pages.tsv" 2>/dev/null &&
  ! grep -q 'docs/decisions/0001-x.md' "$HID/.kb/provenance.tsv" 2>/dev/null; then
  pass "pages-forget removes the page's rows from both state files"
else
  bad "pages-forget left a row behind: $(cat "$HID/.kb/pages.tsv" 2>&1) $(cat "$HID/.kb/provenance.tsv" 2>&1)"
fi
mv "$HID/docs/decisions/0001-x.md.deleted" "$HID/docs/decisions/0001-x.md"
hid pages-commit pstage >/dev/null
stage_a
hid provenance-commit prov-stage >/dev/null

# 10. removing decision_id from the registered page is decision-id-missing;
# the same on an unregistered page under docs/decisions/ raises nothing.
cp "$HID/docs/decisions/0001-x.md" "$HID/docs/decisions/0001-x.md.bak"
cat >"$HID/docs/decisions/0001-x.md" <<'EOF'
# X

A claim.[^a]

[^a]: `src/a.txt`, lines 1-2.
EOF
out=$(hid check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^decision-id-missing(docs/decisions/0001-x.md)'; then
  pass "a registered decision page with no identifier is reported"
else
  bad "the missing identifier was not reported: $out"
fi
hid pages-forget docs/decisions/0001-x.md >/dev/null
out=$(hid check docs 2>&1)
if ! printf '%s\n' "$out" | grep -q 'decision-id-missing'; then
  pass "the same page, unregistered, raises no decision-id-missing"
else
  bad "an unregistered page was held to the decision-id rule: $out"
fi
mv "$HID/docs/decisions/0001-x.md.bak" "$HID/docs/decisions/0001-x.md"
hid pages-commit pstage >/dev/null
stage_a
hid provenance-commit prov-stage >/dev/null

# 11. a missing schema is schema-missing; a map naming a missing file is
# map-missing.
mv "$HID/.kb/schema.md" "$HID/.kb/schema.md.bak"
out=$(hid check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^schema-missing(.kb/schema.md)'; then
  pass "no .kb/schema.md is schema-missing"
else
  bad "a missing schema was not reported: $out"
fi
{
  echo "---"
  echo "map: docs/nonexistent.md"
  echo "decisions: docs/decisions"
  echo "---"
} >"$HID/.kb/schema.md"
out=$(hid check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^map-missing(.kb/schema.md)'; then
  pass "a map naming a file that does not exist is map-missing"
else
  bad "a dangling map was not reported: $out"
fi
mv "$HID/.kb/schema.md.bak" "$HID/.kb/schema.md"

# 12. a page not linked from the map is unreachable; the map itself is not.
out=$(hid check docs 2>&1)
if ! printf '%s\n' "$out" | grep -q 'unreachable(docs/README.md)'; then
  pass "the map is never reported unreachable"
else
  bad "the map itself was reported unreachable: $out"
fi
printf '# Orphan\n\nLinked from nothing the map reaches.\n' >"$HID/docs/guides/orphan.md"
out=$(hid check docs 2>&1)
if [ $? -ne 0 ] && printf '%s\n' "$out" | grep -q '^unreachable(docs/guides/orphan.md)'; then
  pass "a page the map's traversal never reaches is unreachable"
else
  bad "the orphan page was not reported: $out"
fi
rm "$HID/docs/guides/orphan.md"

# 13. with no .kb/pages.tsv and no .kb/provenance.tsv but a schema, check is
# green: a freshly adopted tree registers nothing yet and reports nothing.
FRESH="$SCRATCH/hid-fresh"
mkdir -p "$FRESH/.kb" "$FRESH/docs"
{
  echo "---"
  echo "map: docs/index.md"
  echo "decisions: docs/decisions"
  echo "---"
} >"$FRESH/.kb/schema.md"
printf '# Index\n' >"$FRESH/docs/index.md"
out=$(cd "$FRESH" && "$CHECKER" check docs 2>&1)
if [ $? -eq 0 ] && printf '%s\n' "$out" | grep -q '^OK: 1 pages under docs conform$'; then
  pass "a schema with no pages.tsv or provenance.tsv yet is a clean, freshly adopted tree"
else
  bad "a freshly adopted tree was not green: $out"
fi

exit "$fail"
