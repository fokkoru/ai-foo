#!/usr/bin/env bash
# Conformance, reachability, provenance, and raw-source immutability checks for
# a knowledge base compiled by kb:weave, reading .kb/schema.md, .kb/pages.tsv,
# .kb/provenance.tsv and .kb/consumed.tsv.
#
#   snapshot [raw-root]                    hash every raw source, print the manifest path
#   verify-sources <manifest> [raw-root]   prove the raw layer did not change during a run
#   check [docs-root] [raw-root]           every conformance rule over the compiled tree,
#                                          read from .kb/schema.md, .kb/pages.tsv and
#                                          .kb/provenance.tsv
#   check-capture <record>                 the format rules for one capture record
#   assign-id <page>                       an identifier for a new decision page
#   resolve-decision <docs-root> <id> [path-hint]
#                                          the page an identifier names
#   claim-acquire <session-id> <pid>       take the whole-run claim, print its run id
#   claim-release <run-id>                 give it back
#   claim-inspect                          say who holds it and whether they are alive
#   supersession-scan <records-root> <docs-root> <target>
#                                          every record decision that supersedes a target
#   consumed-commit <raw-root> <staging>   record what a validated run consumed, capture or note
#   consumed-check <raw-root>              the consumed ledger's own format; notes sources that moved on
#   captures-eligible <records-root>       decisions no run has consumed yet
#   captures-deferred <records-root>       decisions a run looked at and left
#   sources-pending <raw-root>             raw sources no run consumed at their current bytes
#   provenance-commit <staging> [raw-root] record a page's cited fragments, hash computed
#   pages-commit <staging>                 record a page's compiled fingerprint
#   pages-forget <page>                    remove a page's rows from both state files
#
# Each mode exits 0 on success and 1 on any failure, printing one
# RULE(subject): detail line per failure.
#
# The manifest is created fresh per snapshot and named by the caller from then
# on. Two compile runs — two repositories, or two sessions on one repository —
# can share a TMPDIR, and a manifest at a fixed path would let one run's
# snapshot stand in for the other's. That produces a false failure when the two
# trees differ and a false pass when they happen to share relative paths.
# snapshot writes the path to stdout so the caller can hold it; everything else
# it prints goes to stderr.
#
# The script derives no path from its own location. A plugin-bundled script is
# invoked by absolute path from whatever project is being compiled, so both
# roots come from arguments and resolve against the current directory. That is
# the one place this departs from the repository's cd "$(dirname "$0")/.."
# idiom, and the reason is that this file ships to other people's checkouts.
#
# bash 3.2 is the floor — a clean macOS carries no newer one and the plugin
# installs without a package manager. So no associative arrays and no mapfile;
# sets are files and queues are line-indexed.
set -euo pipefail

fail=0

# One scratch directory for the whole run, cleaned on exit. Per-function temp
# files with a RETURN trap do not work here: bash leaves a RETURN trap installed
# after the function returns, so it fires again in a scope where the `local` it
# names is gone and `set -u` aborts the script.
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

usage() {
  cat >&2 <<EOF
usage: $self snapshot [raw-root]
       $self verify-sources <manifest> [raw-root]
       $self check [docs-root] [raw-root]
       $self check-capture <record>
       $self assign-id <page>
       $self resolve-decision <docs-root> <id> [path-hint]
       $self claim-acquire <session-id> <pid>
       $self claim-release <run-id>
       $self claim-inspect
       $self supersession-scan <records-root> <docs-root> <target>
       $self consumed-commit <raw-root> <staging>
       $self consumed-check <raw-root>
       $self captures-eligible <records-root>
       $self captures-deferred <records-root>
       $self sources-pending <raw-root>
       $self provenance-commit <staging> [raw-root]
       $self pages-commit <staging>
       $self pages-forget <page>
EOF
  exit 2
}

report() {
  echo "$1($2): $3" >&2
  fail=1
}

# The same shape as report, for something the reader should see that does not
# make the run wrong. Both go to stderr, so a mode whose stdout is a value —
# assign-id, claim-acquire, snapshot, resolve-decision — hands a caller the
# value alone even when it also has something to say.
note() {
  echo "$1($2): $3" >&2
}

# One place decides what opens and closes a fenced block, because four scans ask
# the same question. A fence closes only on the character it opened with, at
# least as many of them, so a ~~~ line inside a ``` block is content. Toggling
# on any marker instead inverts the state: the quoted text is read as page and
# the page after it as quotation.
AWK_FENCE='
function fence_line(line,   s, ch, n) {
  s = line
  sub(/^[ \t]*/, "", s)
  ch = substr(s, 1, 1)
  if (ch != "`" && ch != "~") return 0
  n = 0
  while (substr(s, n + 1, 1) == ch) n++
  if (n < 3) return 0
  if (!infence) { infence = 1; fence_ch = ch; fence_n = n; return 1 }
  if (ch == fence_ch && n >= fence_n) { infence = 0; return 1 }
  return 0
}
'

if command -v shasum >/dev/null 2>&1; then
  SHA_TOOL=shasum
elif command -v sha256sum >/dev/null 2>&1; then
  SHA_TOOL=sha256sum
else
  echo "NO-SHA-TOOL(check-docs): neither shasum nor sha256sum is on PATH"
  exit 1
fi

sha256_stream() {
  if [ "$SHA_TOOL" = shasum ]; then
    shasum -a 256
  else
    sha256sum
  fi
}

sha256_file() {
  sha256_stream <"$1" | awk '{print $1}'
}

line_count() {
  awk 'END {print NR}' "$1"
}

# An absolute, symlink-resolved path, so two spellings of one page compare
# equal in the reachability set. Empty when the directory does not exist.
abspath() {
  local d b
  d=$(dirname "$1")
  b=$(basename "$1")
  (cd "$d" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$b") || true
}

# Whether a resource sits inside the raw root or its captures subtree, given
# the raw root already resolved to an absolute path (empty when there is none
# to be inside — an empty prefix would otherwise match any absolute path).
# Prints "capture", "raw", or nothing, so a caller decides which rule to fire:
# provenance-commit refuses the row before it is ever written, check_sources
# reports it on every row already on disk, however it got there. One helper
# for both, so a hand-edited or migrated .kb/provenance.tsv is held to the
# same exclusion a committed row was.
provenance_resource_zone() {
  local raw="$1" resource="$2" resolved
  [ -n "$raw" ] || return 0
  # Both sides are resolved before comparing, so a relative citation and an
  # absolute raw root are still recognised as the same tree.
  resolved=$(abspath "$resource")
  case "$resolved" in
  "$raw"/captures/*) printf 'capture\n' ;;
  "$raw"/*) printf 'raw\n' ;;
  esac
  return 0
}

# ---------------------------------------------------------------- frontmatter

# Line number of the closing --- of a leading frontmatter block, 0 when the file
# opens no block or never closes the one it opened.
fm_end() {
  # awk runs END even after `exit`, so the answer is latched in a variable and
  # printed once, rather than printed twice by the rule and the END block.
  awk '
    NR==1 && $0!="---" {done=1; exit}
    NR==1 {next}
    $0=="---" {n=NR; done=1; exit}
    END {print (done && n) ? n : 0}
  ' "$1"
}

# Value of a single-line frontmatter key, empty when the key is absent. The awk
# shape is check-skill-description-length.sh:32-52, unchanged.
fm_value() {
  awk -v key="$2" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm && index($0, key ":")==1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      first = substr($0, 1, 1)
      if (length($0) >= 2 && first == substr($0, length($0), 1) &&
          (first == "\"" || first == "\047")) {
        $0 = substr($0, 2, length($0) - 2)
      }
      print
      exit
    }' "$1"
}

# Top-level frontmatter key names, one per line.
fm_keys() {
  awk '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm && /^[A-Za-z_][A-Za-z0-9_]*:/ {
      k = $0
      sub(/:.*$/, "", k)
      print k
    }' "$1"
}

# ------------------------------------------------------------------- fragments

# The cited span of a resource, before normalization. Three forms: the whole
# file minus any leading frontmatter, an exact heading line through the line
# before the next heading at the same or a shallower level, or an inclusive
# L<start>-L<end> range for a resource with no headings to anchor on.
fragment_text() {
  local file="$1" frag="$2" start end level
  case "$frag" in
  "(whole)")
    awk '
      NR==1 && $0!="---" {print; plain=1; next}
      plain {print; next}
      NR==1 {infm=1; next}
      infm && $0=="---" {infm=0; next}
      infm {next}
      {print}' "$file"
    ;;
  L[0-9]*-L[0-9]*)
    start=${frag%%-*}
    start=${start#L}
    end=${frag##*-}
    end=${end#L}
    awk -v s="$start" -v e="$end" 'NR>=s && NR<=e' "$file"
    ;;
  *)
    level=$(printf '%s' "$frag" | awk '{n=0; while (substr($0,n+1,1)=="#") n++; print n}')
    # Fence state, tracked from line 1 and toggled the way strip_code does it. A
    # `# comment` inside a fenced block is not a heading, and without this the
    # first one ends the fragment: the cited span then hashes a few lines of a
    # long section and every later edit below that point reads as no drift at
    # all. The fence line itself belongs to the fragment, so it prints.
    awk -v h="$frag" -v lvl="$level" "$AWK_FENCE"'
      fence_line($0) {if (on) print; next}
      !on && !infence && $0==h {on=1; print; next}
      on {
        if (!infence && $0 ~ /^#+[[:space:]]/) {
          n=0; while (substr($0,n+1,1)=="#") n++
          if (n <= lvl) exit
        }
        print
      }' "$file"
    ;;
  esac
}

# Trailing whitespace off every line, leading and trailing blank lines dropped,
# then the first 12 hex characters of the sha256. Normalizing before hashing is
# what keeps a reformat that changed nothing a reader can see from reading as
# drift.
normalize_and_hash() {
  sed -e 's/[[:space:]]*$//' |
    awk '
      {lines[NR] = $0}
      END {
        first = 1; last = NR
        while (first <= NR && lines[first] == "") first++
        while (last >= first && lines[last] == "") last--
        for (i = first; i <= last; i++) print lines[i]
      }' |
    sha256_stream | awk '{print substr($1, 1, 12)}'
}

# --------------------------------------------------------------------- linking

# A code example is prose about markdown, not bundle structure. docs/WIKI.md
# exists to display worked link and frontmatter syntax, so reading its examples
# as real links produces false valid-links failures and marks a page reachable
# that nothing outside a fence links to. Fenced blocks and inline spans go before
# any structural scan of a page.
#
# Two forms are deliberately left in: a four-space-indented code block, and an
# inline span whose line carries an odd number of backticks. Both are rare in a
# compiled page, and covering them costs a real markdown parser.
strip_code() {
  awk "$AWK_FENCE"'
    fence_line($0) {next}
    infence {next}
    {gsub(/`[^`]*`/, ""); print}' "$1"
}

# Resolved targets of every relative .md link on a page, one per line, relative
# to the page's own directory. Absolute URLs and bundle-absolute paths are not
# relative links and are skipped; an anchor is not part of the target.
page_link_targets() {
  { strip_code "$1" | grep -oE '\]\([^)]*\)' || true; } |
    sed -e 's/^](//' -e 's/)$//' -e 's/#.*$//' |
    awk '
      $0 == "" {next}
      /^[a-zA-Z][a-zA-Z0-9+.-]*:/ {next}
      /^\// {next}
      /\.md$/ {print}'
}

# Every link on a page that carries an anchor, as anchor<TAB>target. The target
# is empty for a same-page link, and the anchor leads for that reason: a tab is
# IFS whitespace, so `read` strips a leading empty field and a same-page link
# read as target<TAB>anchor arrives with the anchor in the target variable and
# nothing in the anchor — which silently skips every same-page link, the only
# kind this repository's pages actually use.
#
# page_link_targets deliberately drops the anchor because reachability does not
# need it, so this is a second extractor rather than a change to that one.
page_anchor_links() {
  { strip_code "$1" | grep -oE '\]\([^)]*\)' || true; } |
    sed -e 's/^](//' -e 's/)$//' |
    awk -F'#' '
      NF < 2 {next}
      $2 == "" {next}
      $1 ~ /^[a-zA-Z][a-zA-Z0-9+.-]*:/ {next}
      $1 ~ /^\// {next}
      $1 != "" && $1 !~ /\.md$/ {next}
      {print $2 "\t" $1}'
}

# GitHub's heading slugs for a file, in document order. Inline markup loses its
# marker characters and keeps its text, then the text is lowercased, spaces
# become hyphens, and everything that is not alphanumeric, hyphen or underscore
# is dropped — so "OKF v0.2, pinned" is okf-v02-pinned rather than
# okf-v0-2-pinned, and check_sources keeps its underscore. A slug already seen
# takes the -1, -2 suffix GitHub appends to a repeated heading. Without all
# three the rule reports a false failure on a correct link, and it is a gate.
#
# This skips fences with AWK_FENCE directly rather than piping through
# strip_code, because strip_code deletes an inline span along with its text:
# "## The `sources[]` block" would arrive as "## The  block" and slug to
# the-block, where GitHub drops only the backticks and slugs the-sources-block.
#
# Frontmatter is skipped: a YAML comment is a # followed by a space, which is
# also the heading pattern.
heading_slugs() {
  awk "$AWK_FENCE"'
    fence_line($0) {next}
    infence {next}
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {infm=0; next}
    infm {next}
    /^#+[[:space:]]/ {
      s = $0
      sub(/^#+[[:space:]]*/, "", s)
      sub(/[[:space:]]+$/, "", s)
      gsub(/[`*~]/, "", s)
      while (match(s, /\[[^]]*\]\([^)]*\)/)) {
        pre = substr(s, 1, RSTART - 1)
        inner = substr(s, RSTART + 1, RLENGTH - 1)
        sub(/\].*$/, "", inner)
        s = pre inner substr(s, RSTART + RLENGTH)
      }
      s = tolower(s)
      gsub(/[[:space:]]/, "-", s)
      gsub(/[^a-z0-9_-]/, "", s)
      if (s == "") next
      if (s in seen) { n = seen[s]++; print s "-" n }
      else { seen[s] = 1; print s }
    }' "$1"
}

# ------------------------------------------------------------------- snapshot

hash_tree() {
  local h
  find "$1" -type f -print | LC_ALL=C sort | while IFS= read -r f; do
    # An unhashable file must abort the tree rather than record an empty hash:
    # a file that fails to hash on both the snapshot and the verify pass would
    # otherwise compare equal to itself and be reported unchanged. Exiting the
    # subshell that runs this loop makes the pipeline non-zero under pipefail,
    # which the callers' guards catch.
    h=$(sha256_file "$f") || exit 1
    [ -n "$h" ] || exit 1
    printf '%s\t%s\n' "$h" "$f"
  done
}

cmd_snapshot() {
  local raw="${1:-thoughts}" manifest
  if [ ! -d "$raw" ]; then
    report NO-RAW-ROOT snapshot "$raw is not a directory"
    return 1
  fi
  # The template ends in X's with no suffix after them: BSD mktemp, which is the
  # one a clean macOS carries, accepts no trailing characters.
  manifest=$(mktemp "${TMPDIR:-/tmp}/kb-weave-sources.XXXXXXXX") || {
    report SNAPSHOT-FAILED snapshot "could not create a manifest under ${TMPDIR:-/tmp}"
    return 1
  }
  # Every I/O failure below is reported rather than left to set -e. A function
  # invoked as the left operand of || runs with errexit ignored for its whole
  # body, so a failed redirect here would otherwise fall through to the success
  # line and the script would exit 0 having recorded nothing.
  hash_tree "$raw" >"$manifest" || {
    rm -f "$manifest"
    report SNAPSHOT-FAILED snapshot "could not hash every file under $raw, or could not write the manifest to $manifest"
    return 1
  }
  echo "snapshot: $(line_count "$manifest") files under $raw recorded in $manifest" >&2
  echo "$manifest"
}

cmd_verify_sources() {
  local manifest="${1:-}" raw="${2:-thoughts}" now findings
  [ -n "$manifest" ] || usage
  if [ ! -d "$raw" ]; then
    report NO-RAW-ROOT verify-sources "$raw is not a directory"
    return 1
  fi
  if [ ! -f "$manifest" ]; then
    report NO-SNAPSHOT verify-sources \
      "no manifest at $manifest — a run that never snapshotted cannot claim it left the raw layer alone"
    return 1
  fi

  now="$WORKDIR/now"
  findings="$WORKDIR/findings"
  hash_tree "$raw" >"$now" || {
    report VERIFY-FAILED verify-sources "could not hash the tree under $raw"
    return 1
  }

  awk -F'\t' '
    NR==FNR {old[$2] = $1; next}
    {new[$2] = $1}
    END {
      for (p in new) {
        if (!(p in old)) print "SOURCE-ADDED(" p "): not present when the run started"
        else if (old[p] != new[p]) print "SOURCE-CHANGED(" p "): content differs from the snapshot"
      }
      for (p in old) if (!(p in new)) print "SOURCE-REMOVED(" p "): present when the run started, gone now"
    }' "$manifest" "$now" | LC_ALL=C sort >"$findings" || {
    report VERIFY-FAILED verify-sources "could not compare the manifest against the current tree"
    return 1
  }

  if [ -s "$findings" ]; then
    cat "$findings"
    fail=1
    return 1
  fi
  echo "verify-sources: $(line_count "$now") files under $raw unchanged since the snapshot"
}

# -------------------------------------------------------------- capture record

# The decisions in a capture record, one DEC<TAB>line<TAB>heading per decision,
# followed by END<TAB>line for the last line of the ## Decisions section.
#
# Only the immediate ### headings inside ## Decisions are decisions. A #### is
# not one, and neither is a ### inside a fenced block: a record quotes the shape
# it follows, and reading that quotation as a decision would enumerate an
# imposter that no session ever decided. Fence state is tracked from line 1, the
# way strip_code does it.
capture_decision_index() {
  awk "$AWK_FENCE"'
    fence_line($0) {next}
    infence {next}
    /^## / {
      if (ind) {print "END\t" NR - 1; ind = 0}
      if ($0 == "## Decisions") ind = 1
      next
    }
    ind && /^### / {print "DEC\t" NR "\t" substr($0, 5)}
    END {if (ind) print "END\t" NR}
  ' "$1"
}

# Whether a record holds a decision under exactly this heading. A reference and
# a receipt entry both name one, and both are wrong in the same way when the
# heading was retyped rather than copied.
record_has_heading() {
  capture_decision_index "$1" |
    awk -F'\t' -v h="$2" '$1 == "DEC" && $3 == h {found = 1} END {exit found ? 0 : 1}'
}

# The value of a decision field, empty when the line is absent or carries
# nothing after the colon.
capture_field() {
  awk -v key="$2" '
    index($0, key ":") == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }' "$1"
}

cmd_check_capture() {
  local rec="${1:-}" index body start end nxt heading total n secend value dupe
  [ -n "$rec" ] || usage
  if [ ! -f "$rec" ]; then
    report NO-CAPTURE check-capture "$rec is not a file"
    return 1
  fi

  # A record carries no frontmatter. The one key an earlier shape kept moved
  # onto the decision itself, so a block here holds nothing anything reads.
  if [ "$(head -1 "$rec")" = "---" ]; then
    report capture-frontmatter "$rec" "a capture record carries no frontmatter, and this one opens with ---"
  fi

  index="$WORKDIR/capture-index"
  capture_decision_index "$rec" >"$index" || {
    report CAPTURE-FAILED "$rec" "could not scan the record for decisions"
    return 1
  }

  total=$(awk -F'\t' '$1 == "DEC" {n++} END {print n + 0}' "$index")
  secend=$(awk -F'\t' '$1 == "END" {print $2; exit}' "$index")

  if [ "$total" -eq 0 ]; then
    report capture-no-decisions "$rec" \
      "no ### decision under a ## Decisions section — a session that reached no decision writes no record"
    return 1
  fi

  # Every loop that reports reads from a heredoc rather than a pipe: a report
  # inside a pipeline runs in a subshell, where fail=1 is set and then thrown
  # away, and the script would exit 0 while printing failures.
  while IFS= read -r dupe; do
    [ -n "$dupe" ] || continue
    report capture-decision-duplicate "$rec" \
      "the decision heading '$dupe' appears more than once, so a reference to it names two decisions"
  done <<EOF
$(awk -F'\t' '$1 == "DEC" {print $3}' "$index" | LC_ALL=C sort | uniq -d)
EOF

  body="$WORKDIR/capture-body"
  n=0
  while [ "$n" -lt "$total" ]; do
    n=$((n + 1))
    start=$(awk -F'\t' -v i="$n" '$1 == "DEC" {c++; if (c == i) {print $2; exit}}' "$index")
    heading=$(awk -F'\t' -v i="$n" '$1 == "DEC" {c++; if (c == i) {print $3; exit}}' "$index")
    nxt=$(awk -F'\t' -v i="$n" '$1 == "DEC" {c++; if (c == i + 1) {print $2; exit}}' "$index")
    if [ -n "$nxt" ]; then
      end=$((nxt - 1))
    else
      end="$secend"
    fi
    awk -v s="$start" -v e="$end" 'NR > s && NR <= e' "$rec" >"$body" || {
      report CAPTURE-FAILED "$rec" "could not read the body of decision '$heading'"
      return 1
    }

    for field in Rejected Because Evidence; do
      if ! grep -q "^$field:" "$body"; then
        report capture-field-missing "$rec" "decision '$heading' carries no $field: line"
      fi
    done

    # An absent Evidence: line is already reported above. A present one that
    # says nothing is the case this catches: the writer meant to fill it in and
    # did not, which is different from writing `none` to mark that no durable
    # source exists.
    if grep -q '^Evidence:' "$body"; then
      value=$(capture_field "$body" Evidence)
      if [ -z "$value" ]; then
        report capture-evidence-empty "$rec" \
          "decision '$heading' has an empty Evidence: — write 'none' to mark that no durable source exists"
      fi
    fi
  done

  if [ "$fail" -eq 0 ]; then
    echo "check-capture: $total decisions in $rec conform"
  fi
}

# ---------------------------------------------------------------------- check

check_page_frontmatter() {
  local page="$1"
  if [ "$(head -1 "$page")" = "---" ] && [ "$(fm_end "$page")" -eq 0 ]; then
    report frontmatter-parseable "$page" "the opening --- has no closing ---"
  fi
  return 0
}

check_links() {
  local page="$1" dir t
  dir=$(dirname "$page")
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if [ ! -f "$dir/$t" ]; then
      report valid-links "$page" "relative link target $t does not resolve to a file"
    fi
  done <<EOF
$(page_link_targets "$page")
EOF
}

# A link into a heading that no longer exists. A target file that does not exist
# is valid-links' finding, not this one, so a missing file is skipped rather
# than reported twice.
check_anchors() {
  local page="$1" dir target anchor file
  dir=$(dirname "$page")
  while IFS="$(printf '\t')" read -r anchor target; do
    [ -n "$anchor" ] || continue
    if [ -z "$target" ]; then
      file="$page"
    else
      file="$dir/$target"
      [ -f "$file" ] || continue
    fi
    if ! heading_slugs "$file" | grep -Fxq -- "$anchor"; then
      report dead-anchor "$page" \
        "link target #$anchor matches no heading in ${target:-this page}"
    fi
  done <<EOF
$(page_anchor_links "$page")
EOF
  return 0
}

# A marker the schema sanctions as a literal TODO. Advisory: a page that admits
# it does not know something is not malformed, and failing the gate on it would
# make a legitimate state break the build. [inferred] is not included — it marks
# a deduction the schema allows, not a gap.
check_open_markers() {
  local page="$1" n
  n=$(strip_code "$page" | { grep -c '\[unknown\]' || true; })
  if [ "$n" -gt 0 ]; then
    note open-marker "$page" "$n line(s) carry [unknown], an answer the page is still missing"
  fi
  return 0
}

# The page-local join between .kb/provenance.tsv rows and the [^label]:
# definitions and [^label] citations in a body. ids are the labels a
# provenance row declares for this page; defs are the [^label]: lines; cites
# are [^label] references outside a definition line. A row with no matching
# definition is unjoined — a report, since nothing on the page attributes it.
# A row nobody cites is merely unused — a note, since the join still holds. A
# citation naming a label with no row and no definition is neither: it is
# prose, and nothing here has an opinion about it.
#
# A registered page additionally gets unregistered-citation: a [^label]:
# definition whose text names a real file in backticks, but whose label
# carries no provenance row, is a citation the compiler never recorded.
check_footnote_join() {
  local page="$1" recs line ids deflines defs cites slug defline label rest path
  recs=$(provenance_rows "$page")
  ids=""
  if [ -n "$recs" ]; then
    # Built by validating each row's label rather than by cutting the column
    # straight into a sort -u: an empty or whitespace-carrying label word-
    # splits or vanishes from the `for slug in $ids` loop below with no
    # report at all, the same defect provenance-commit already refuses on the
    # write path.
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      label=$(printf '%s' "$line" | cut -f2)
      if provenance_label_valid "$label"; then
        ids="$ids
$label"
      else
        report provenance-label "$page" "a provenance row's label is empty or contains whitespace: $line"
      fi
    done <<EOF
$recs
EOF
    ids=$(printf '%s\n' "$ids" | sed '/^$/d' | LC_ALL=C sort -u)
  fi
  # Fences only, not strip_code: a definition's backtick-quoted path is the
  # very thing unregistered-citation reads, and strip_code deletes an inline
  # span along with its text, the same reason heading_slugs gives.
  deflines=$(awk "$AWK_FENCE"'
    fence_line($0) {next}
    infence {next}
    {print}' "$page" | { grep -oE '^\[\^[^]]+\]:.*$' || true; })
  defs=$(printf '%s\n' "$deflines" | sed -e 's/^\[\^//' -e 's/\]:.*$//' | LC_ALL=C sort -u)
  cites=$(strip_code "$page" |
    grep -v '^\[\^[^]]*\]:' |
    { grep -oE '\[\^[^]]+\]' || true; } |
    sed -e 's/^\[\^//' -e 's/\]$//' | LC_ALL=C sort -u)

  for slug in $ids; do
    if ! printf '%s\n' "$defs" | grep -Fxq -- "$slug"; then
      report unjoined-footnote "$page" \
        "provenance declares $slug, which no [^$slug]: definition on this page joins"
    fi
    if ! printf '%s\n' "$cites" | grep -Fxq -- "$slug"; then
      note unused-source "$page" \
        "provenance declares $slug, which no [^$slug] in the body cites"
    fi
  done

  page_registered "$page" || return 0
  while IFS= read -r defline; do
    [ -n "$defline" ] || continue
    label=$(printf '%s' "$defline" | sed -e 's/^\[\^//' -e 's/\]:.*$//')
    printf '%s\n' "$ids" | grep -Fxq -- "$label" && continue
    rest=$(printf '%s' "$defline" | sed -e 's/^\[\^[^]]*\]:[[:space:]]*//')
    path=$(printf '%s' "$rest" | sed -n 's/^`\([^`]*\)`.*/\1/p')
    if [ -n "$path" ] && [ -f "$path" ]; then
      note unregistered-citation "$page" \
        "[^$label]: names $path, which no provenance row backs"
    fi
  done <<EOF
$deflines
EOF
  return 0
}

check_sources() {
  local page="$1" raw="$2" recs line label resource fragment recorded text actual total end
  recs=$(provenance_rows "$page")
  [ -n "$recs" ] || return 0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # A row with fewer than 5 fields is malformed, not drifted: without this,
    # a row missing its hash reads as an empty $recorded and reports as
    # source-drift with a blank recorded value rather than as the shape
    # defect it is. provenance-commit always writes 5 fields, so this only
    # arises from a hand-edited or migrated ledger.
    if [ "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" -ne 5 ]; then
      report provenance-malformed "$page" "expected 5 tab-separated fields: $line"
      continue
    fi
    label=$(printf '%s' "$line" | cut -f2)
    resource=$(printf '%s' "$line" | cut -f3)
    fragment=$(provenance_fragment_default "$(printf '%s' "$line" | cut -f4)")
    recorded=$(printf '%s' "$line" | cut -f5)

    if [ ! -f "$resource" ]; then
      report source-missing "$page" "[^$label] names $resource, which does not exist"
      continue
    fi

    # Every citation must name a file the reader's clone holds. A path inside
    # the raw root is an internal note: a fresh clone does not have it, so the
    # claim it supports cannot be checked by anyone but the author. A capture
    # record is called out separately because it is not merely untracked — it
    # sits outside the source trust order entirely, never competing for a page
    # and never cited by one. The same zone check runs on the write path, in
    # provenance-commit, so a row that reached .kb/provenance.tsv without going
    # through it — a hand edit, a migration script — is held to it here too.
    case "$(provenance_resource_zone "$raw" "$resource")" in
    capture)
      report source-is-capture "$page" "[^$label] names the capture record $resource; a record is never cited by a page"
      continue
      ;;
    raw)
      report source-in-raw-root "$page" "[^$label] names $resource, inside the raw root, which a fresh clone does not have"
      continue
      ;;
    esac

    case "$fragment" in
    "(whole)") ;;
    L[0-9]*-L[0-9]*)
      end=${fragment##*-}
      end=${end#L}
      total=$(line_count "$resource")
      if [ "$end" -gt "$total" ]; then
        report fragment-missing "$page" \
          "[^$label] cites $fragment of $resource, which has $total lines"
        continue
      fi
      ;;
    *)
      if ! grep -Fxq -- "$fragment" "$resource"; then
        report fragment-missing "$page" \
          "[^$label] cites the heading '$fragment', absent from $resource"
        continue
      fi
      ;;
    esac

    text=$(fragment_text "$resource" "$fragment")
    actual=$(printf '%s\n' "$text" | normalize_and_hash)
    if [ "$actual" != "$recorded" ]; then
      report source-drift "$page" \
        "[^$label] records $recorded for $fragment of $resource, which now hashes to $actual"
    fi
  done <<EOF
$recs
EOF
  return 0
}

# A claim whose evidence is external is marked [reported] and carries its source
# in the line itself rather than in sources[]. External sources stay informal —
# no snapshot, no drift checking — so the URL and the date it was read are the
# whole of what a later reader gets. A marker inside backticks is a page writing
# about the vocabulary, which strip_code removes before this looks.
check_external_claims() {
  local page="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
    *http://* | *https://*) ;;
    *)
      report external-claim-incomplete "$page" "a [reported] claim names no URL: $line"
      continue
      ;;
    esac
    if ! printf '%s' "$line" | grep -Eq 'retrieved [0-9]{4}-[0-9]{2}-[0-9]{2}'; then
      report external-claim-incomplete "$page" "a [reported] claim names no retrieval date: $line"
    fi
  done <<EOF
$(strip_code "$page" | grep -F '[reported]' || true)
EOF
}

check_reachability() {
  local docs="$1" map="$2" seen queue cur dir t resolved n page mapabs
  [ -f "$map" ] || return 0

  seen="$WORKDIR/seen"
  queue="$WORKDIR/queue"

  abspath "$map" >"$seen" || {
    report REACHABILITY-FAILED "$docs" "could not write the traversal set under $WORKDIR"
    return 1
  }
  cp "$seen" "$queue" || {
    report REACHABILITY-FAILED "$docs" "could not seed the traversal queue under $WORKDIR"
    return 1
  }
  mapabs=$(cat "$seen")

  n=0
  while [ "$n" -lt "$(line_count "$queue")" ]; do
    n=$((n + 1))
    cur=$(awk -v i="$n" 'NR==i' "$queue")
    [ -f "$cur" ] || continue
    dir=$(dirname "$cur")
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      [ -f "$dir/$t" ] || continue
      resolved=$(abspath "$dir/$t")
      [ -n "$resolved" ] || continue
      if ! grep -Fxq -- "$resolved" "$seen"; then
        # A failed append would silently shrink the reachable set and report
        # pages unreachable that are not.
        printf '%s\n' "$resolved" >>"$seen" || {
          report REACHABILITY-FAILED "$docs" "could not extend the traversal set under $WORKDIR"
          return 1
        }
        printf '%s\n' "$resolved" >>"$queue" || {
          report REACHABILITY-FAILED "$docs" "could not extend the traversal queue under $WORKDIR"
          return 1
        }
      fi
    done <<EOF
$(page_link_targets "$cur")
EOF
  done

  while IFS= read -r page; do
    [ -n "$page" ] || continue
    resolved=$(abspath "$page")
    [ "$resolved" = "$mapabs" ] && continue
    if ! grep -Fxq -- "$resolved" "$seen"; then
      report unreachable "$page" "not reachable from $map by following relative .md links"
    fi
  done <"$WORKDIR/pages"
}

# --------------------------------------------------------- capture selection

# Every decision in every record under a root, as path<TAB>heading.
capture_decisions_all() {
  local root="$1" rec rel index
  index="$WORKDIR/select-index"
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    rel=${rec#"$root"/}
    capture_decision_index "$rec" >"$index" || return 1
    awk -F'\t' -v p="$rel" '$1 == "DEC" {print p "\t" $3}' "$index"
  done <<EOF
$(find "$root" -type f -name '*.md' -print | LC_ALL=C sort)
EOF
}

# What a run may still take in. Eligibility is mechanical — it is the decisions
# the one consumption ledger does not record as consumed — while which of them
# a run actually takes is the model's choice, and the run's report is the only
# place that choice is written down. Detecting that a record is eligible
# therefore does not guarantee it was examined.
cmd_captures_eligible() {
  local root="${1:-}" line path heading last state
  [ -n "$root" ] || usage
  if [ ! -d "$root" ]; then
    report NO-RECORDS-ROOT captures-eligible "$root is not a directory"
    return 1
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    path=$(printf '%s' "$line" | cut -f1)
    heading=$(printf '%s' "$line" | cut -f2)
    last=$(consumed_last capture "$path" "$heading") || {
      report CONSUMED-UNREADABLE captures-eligible "could not read $CONSUMED"
      return 1
    }
    state=$(printf '%s' "$last" | cut -f2)
    [ "$state" = "consumed" ] && continue
    printf '%s\t%s\n' "$path" "$heading"
  done <<EOF
$(capture_decisions_all "$root")
EOF
  return 0
}

# The decisions a run looked at and left. A deferred decision waits indefinitely
# rather than expiring, so something has to come back to it, and that something
# is a pass the owner starts. Nothing here wakes it.
cmd_captures_deferred() {
  local root="${1:-}"
  [ -n "$root" ] || usage
  if [ ! -d "$root" ]; then
    report NO-RECORDS-ROOT captures-deferred "$root is not a directory"
    return 1
  fi
  [ -f "$CONSUMED" ] || return 0
  # A ledger that exists but cannot be read is not an empty ledger: under
  # pipefail an unreadable file fails the first awk and the pipeline exits
  # non-zero, which the guard below catches rather than reporting an empty,
  # falsely clean deferred set.
  # Last row per (kind, path, unit), then the capture rows still deferred.
  awk -F'\t' '{k[$1 "\t" $2 "\t" $3] = $4 "\t" $5} END {for (i in k) print i "\t" k[i]}' "$CONSUMED" |
    awk -F'\t' '$1 == "capture" && $5 == "deferred" {print $2 "\t" $3}' | LC_ALL=C sort -u || {
    report CONSUMED-UNREADABLE captures-deferred "could not read $CONSUMED"
    return 1
  }
  return 0
}

# ------------------------------------------------------------- consumed.tsv

# One ledger for everything a run read out of the raw layer. A capture row is
# per decision and hashes the normalized body, the way a record's identity is
# computed everywhere else; a note row is per file and hashes the bytes. The
# kind implies the scheme, so a row carries no scheme column. Append-only; the
# last row per (kind, path, unit) wins.
#
#   <kind>\t<path>\t<unit>\t<hash>\t<state>
#
# kind is capture or note. For a capture row, path is relative to the records
# root and unit is the decision heading; state is consumed or deferred, and
# the hash is receipt_identity's 12 hex characters. For a note row, path is
# relative to the raw root and unit is empty; state is consumed or no-home,
# and the hash is sha256_file's 64 hex characters. A capture record is
# immutable, so a hash mismatch on a capture row is a defect; a note is the
# owner's to edit, so a hash mismatch on a note row is a reason to compile it
# again — that is the intended difference between the two kinds, both carried
# in one file so a run has one ledger to write rather than two.
#
# Tracked and committed alongside the pages it describes, so reverting a bad
# run reverts its bookkeeping too — an untracked ledger survives that revert
# and goes on claiming things were consumed for pages that no longer exist.
CONSUMED=".kb/consumed.tsv"

# The hash a capture row and a decision reference both use: the first 12 hex
# characters of the normalized body's sha256. Stored rather than recomputed
# from a slug — the one disclosed failure in this shape was a slug collision
# that staged hundreds of records and ingested none. It is also what proves
# the record on disk is the one that was acknowledged: a published record is
# immutable, so a mismatch means somebody edited one.
receipt_identity() {
  fragment_text "$1" "(whole)" | normalize_and_hash
}

# Prints hash<TAB>state for the last row matching kind, path, unit; nothing
# when there is none or no ledger.
consumed_last() {
  [ -f "$CONSUMED" ] || return 0
  awk -F'\t' -v k="$1" -v p="$2" -v u="$3" \
    '$1 == k && $2 == p && $3 == u {h = $4; s = $5} END {if (h != "") print h "\t" s}' "$CONSUMED"
  return $?
}

consumed_kind_valid() {
  case "$1" in
  capture | note) return 0 ;;
  esac
  return 1
}

consumed_state_valid() {
  case "$1:$2" in
  capture:consumed | capture:deferred | note:consumed | note:no-home) return 0 ;;
  esac
  return 1
}

# A path the ledger will accept: relative, no `.` or `..` segment, no leading
# slash. A staging line here is written by the model from a name the owner
# typed, so the spelling is checked before it is looked up.
consumed_path_canonical() {
  case "$1" in
  "" | /* | ./* | ../* | */./* | */../* | */. | */.. | *//*) return 1 ;;
  esac
  return 0
}

# What either hash scheme prints: 12 hex characters for a capture row, 64 for
# a note row — the kind implies which.
consumed_hash_wellformed() {
  case "$1" in
  capture) printf '%s' "$2" | grep -Eq '^[0-9a-f]{12}$'; return $? ;;
  note) printf '%s' "$2" | grep -Eq '^[0-9a-f]{64}$'; return $? ;;
  esac
  return 1
}

# A capture row must carry a heading; a note row must carry none. Shared by
# consumed-commit's validation and consumed-check's own-format pass, so the
# same malformed row is named the same way whichever mode catches it first.
consumed_unit_valid() {
  case "$1" in
  capture)
    [ -n "$2" ]
    return $?
    ;;
  note)
    [ -z "$2" ]
    return $?
    ;;
  esac
  return 1
}

# A note row may not name a path under captures/: a capture row already
# acknowledges everything there, per decision, and a second answer per file
# would disagree with the first.
consumed_note_not_capture() {
  case "$1" in
  captures/*) return 1 ;;
  esac
  return 0
}

# Raw sources no run has consumed at their current bytes. Enumeration is
# mechanical; which of the listed sources a run then takes is the model's
# choice, and the run's report is where that choice is written down.
cmd_sources_pending() {
  local root="${1:-}" path rel hash last recorded state
  [ -n "$root" ] || usage
  if [ ! -d "$root" ]; then
    report NO-RAW-ROOT sources-pending "$root is not a directory"
    return 1
  fi
  root="${root%/}"
  # Enumerate once, into a file, guarded, for the reason cmd_check gives: a
  # find that fails partway would otherwise print a short queue with exit 0.
  find "$root" -type f -name '*.md' -print | LC_ALL=C sort >"$WORKDIR/raw-files" || {
    report ENUMERATION-FAILED sources-pending "could not enumerate the files under $root"
    return 1
  }
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rel="${path#"$root"/}"
    case "$rel" in
    captures/*) continue ;;
    esac
    # Assigned and tested separately: inside a printf the hash's exit status
    # is lost and an unreadable file records as an empty hash.
    hash=$(sha256_file "$path") || {
      report HASH-FAILED sources-pending "could not hash $rel"
      return 1
    }
    last=$(consumed_last note "$rel" "") || {
      report CONSUMED-UNREADABLE sources-pending "could not read $CONSUMED"
      return 1
    }
    recorded=$(printf '%s' "$last" | cut -f1)
    if [ -z "$recorded" ]; then
      printf '%s\tnew\n' "$rel"
    elif [ "$recorded" != "$hash" ]; then
      printf '%s\tchanged\n' "$rel"
    fi
  done <<EOF
$(cat "$WORKDIR/raw-files")
EOF
  return 0
}

cmd_consumed_commit() {
  local root="${1:-}" staging="${2:-}" pending line kind path unit state hash n
  [ -n "$root" ] || usage
  [ -n "$staging" ] || usage
  if [ ! -f "$staging" ] || [ ! -r "$staging" ]; then
    report NO-STAGING consumed-commit "$staging is not a readable file"
    return 1
  fi
  root="${root%/}"
  pending="$WORKDIR/consumed-pending"
  : >"$pending" || {
    report CONSUMED-FAILED consumed-commit "could not stage under $WORKDIR"
    return 1
  }
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    if [ "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" -ne 4 ]; then
      report consumed-malformed "$staging" "expected 4 tab-separated fields: $line"
      continue
    fi
    kind=$(printf '%s' "$line" | cut -f1)
    path=$(printf '%s' "$line" | cut -f2)
    unit=$(printf '%s' "$line" | cut -f3)
    state=$(printf '%s' "$line" | cut -f4)
    if ! consumed_kind_valid "$kind"; then
      report consumed-kind "$staging" "kind must be capture or note: $line"
      continue
    fi
    if ! consumed_state_valid "$kind" "$state"; then
      report consumed-state "$staging" "state $state is not valid for kind $kind: $line"
      continue
    fi
    if ! consumed_path_canonical "$path"; then
      report consumed-path "$staging" "path must be relative and canonical: $path"
      continue
    fi
    case "$kind" in
    capture)
      if ! consumed_unit_valid capture "$unit"; then
        report consumed-unit "$staging" "a capture row must name a decision heading: $line"
        continue
      fi
      if [ ! -f "$root/captures/$path" ]; then
        report consumed-source-missing "$staging" "$root/captures/$path does not exist"
        continue
      fi
      if ! record_has_heading "$root/captures/$path" "$unit"; then
        report consumed-heading-missing "$staging" "$path has no decision heading '$unit'"
        continue
      fi
      hash=$(receipt_identity "$root/captures/$path") || {
        report HASH-FAILED "$path" "could not hash the record"
        continue
      }
      ;;
    note)
      if ! consumed_note_not_capture "$path"; then
        report consumed-in-captures "$staging" "a note row may not name a capture record: $path"
        continue
      fi
      if ! consumed_unit_valid note "$unit"; then
        report consumed-unit "$staging" "a note row carries no unit: $line"
        continue
      fi
      if [ ! -f "$root/$path" ]; then
        report consumed-source-missing "$staging" "$root/$path does not exist"
        continue
      fi
      hash=$(sha256_file "$root/$path") || {
        report HASH-FAILED "$path" "could not hash the file"
        continue
      }
      ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$path" "$unit" "$hash" "$state" >>"$pending" || {
      report CONSUMED-FAILED consumed-commit "could not stage under $WORKDIR"
      return 1
    }
    n=$((n + 1))
  done <"$staging"
  [ "$fail" -eq 0 ] || return 1
  mkdir -p "$(dirname "$CONSUMED")" || {
    report CONSUMED-FAILED consumed-commit "could not create $(dirname "$CONSUMED")"
    return 1
  }
  # A ledger edited by hand may end without a newline; appending straight after
  # it would join two records into one line. Command substitution strips a
  # trailing newline, so this is empty exactly when the last byte already is
  # one — the same idiom cmd_intake_commit used.
  if [ -s "$CONSUMED" ] && [ -n "$(tail -c 1 "$CONSUMED")" ]; then
    printf '\n' >>"$CONSUMED" || {
      report CONSUMED-FAILED consumed-commit "could not terminate $CONSUMED"
      return 1
    }
  fi
  cat "$pending" >>"$CONSUMED" || {
    report CONSUMED-FAILED consumed-commit "could not append to $CONSUMED"
    return 1
  }
  echo "consumed-commit: $n rows recorded in $CONSUMED"
  return 0
}

# The ledger's own format, then its rows against the raw layer. A capture row
# whose record hashes differently is a report — a published record is
# immutable, so a mismatch means somebody edited one. A note row whose file
# hashes differently is a note — a note is allowed to move on, and
# sources-pending re-queues it.
cmd_consumed_check() {
  local root="${1:-}" line kind path unit hash state n=0 current
  [ -n "$root" ] || usage
  root="${root%/}"
  if [ ! -f "$CONSUMED" ]; then
    echo "OK: no ledger at $CONSUMED"
    return 0
  fi
  if [ ! -r "$CONSUMED" ]; then
    report CONSUMED-UNREADABLE "$CONSUMED" "cannot read the ledger"
    return 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    if [ "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" -ne 5 ]; then
      report consumed-malformed "$CONSUMED" "line $n: expected 5 fields"
      continue
    fi
    kind=$(printf '%s' "$line" | cut -f1)
    path=$(printf '%s' "$line" | cut -f2)
    unit=$(printf '%s' "$line" | cut -f3)
    hash=$(printf '%s' "$line" | cut -f4)
    state=$(printf '%s' "$line" | cut -f5)
    consumed_kind_valid "$kind" || report consumed-kind "$CONSUMED" "line $n: $kind"
    consumed_state_valid "$kind" "$state" || report consumed-state "$CONSUMED" "line $n: $state for $kind"
    consumed_path_canonical "$path" || report consumed-path "$CONSUMED" "line $n: $path"
    consumed_hash_wellformed "$kind" "$hash" || report consumed-hash "$CONSUMED" "line $n: $hash"
    consumed_unit_valid "$kind" "$unit" || report consumed-unit "$CONSUMED" "line $n: $unit"
    if [ "$kind" = "note" ] && ! consumed_note_not_capture "$path"; then
      report consumed-in-captures "$CONSUMED" "line $n: $path"
    fi
  done <"$CONSUMED"
  [ "$fail" -eq 0 ] || return 1

  # Last row per identity against the raw layer. Read the whole line and split
  # with cut -f rather than `IFS=<tab> read`: tab is IFS whitespace, so
  # consecutive tabs collapse and a note row (whose unit field is empty, so
  # two tabs sit side by side) would parse its hash into unit and its state
  # into hash.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    kind=$(printf '%s' "$line" | cut -f1)
    path=$(printf '%s' "$line" | cut -f2)
    unit=$(printf '%s' "$line" | cut -f3)
    hash=$(printf '%s' "$line" | cut -f4)
    state=$(printf '%s' "$line" | cut -f5)
    case "$kind" in
    capture)
      if [ ! -f "$root/captures/$path" ]; then
        report consumed-capture-gone "$path" "recorded but the record is gone"
        continue
      fi
      current=$(receipt_identity "$root/captures/$path") || {
        report HASH-FAILED "$path" "could not hash"
        continue
      }
      [ "$current" = "$hash" ] || report consumed-capture-changed "$path" "the record was edited after it was recorded"
      ;;
    note)
      if [ ! -f "$root/$path" ]; then
        note consumed-note-gone "$path" "recorded but the file is gone"
        continue
      fi
      current=$(sha256_file "$root/$path") || {
        report HASH-FAILED "$path" "could not hash"
        continue
      }
      [ "$current" = "$hash" ] || note consumed-note-changed "$path" "changed since it was consumed; sources-pending lists it"
      ;;
    esac
  done <<EOF
$(awk -F'\t' '{k[$1 "\t" $2 "\t" $3] = $4 "\t" $5} END {for (i in k) print i "\t" k[i]}' "$CONSUMED" | LC_ALL=C sort)
EOF
  if [ "$fail" -eq 0 ]; then
    echo "OK: $n rows in $CONSUMED"
  fi
  return 0
}

# ------------------------------------------------------- provenance and pages

# State access. Every path here resolves against the working directory, the
# way CONSUMED does: a plugin-bundled script has no directory of its own to
# infer these from, so the caller's cwd is the one anchor both share.
PROVENANCE=".kb/provenance.tsv"
PAGES=".kb/pages.tsv"
SCHEMA=".kb/schema.md"

# Rows for one page. Columns: page label resource fragment sha256.
provenance_rows() {
  [ -f "$PROVENANCE" ] || return 0
  awk -F'\t' -v p="$1" '$1 == p' "$PROVENANCE"
}

page_registered() {
  [ -f "$PAGES" ] && awk -F'\t' -v p="$1" '$1 == p {found = 1} END {exit !found}' "$PAGES"
}

# A provenance row's label must be non-empty and carry no whitespace: GFM and
# Pandoc both forbid whitespace in a footnote label, and a labeled row is
# meant to be citable as [^label]. Shared by provenance-commit, which refuses
# a bad label before it is ever written, and check, which must still refuse
# one already on disk — a hand edit or a migration script does not go through
# provenance-commit.
provenance_label_valid() {
  case "$1" in
  "" | *[[:space:]]*) return 1 ;;
  esac
  return 0
}

# The fragment an empty field means: the whole file. provenance-commit stores
# this normalized value, but a row already on disk — hand-written or migrated
# rather than committed — may still carry the field empty, and check must
# treat it the same way rather than falling into the heading-citation branch
# on an empty string.
provenance_fragment_default() {
  [ -n "$1" ] && printf '%s\n' "$1" || printf '(whole)\n'
}

# The fingerprint a compiled page is recorded at: the same normalize-and-hash
# pipeline every other identity in this script uses, over the whole file.
page_fingerprint() {
  fragment_text "$1" "(whole)" | normalize_and_hash
}

# Rewrites a state file with every row for the named pages removed, then
# appends the staged rows. Written to a temp file and moved into place, so a
# failure leaves the old file. `pages` is a newline-separated list of the
# distinct page paths being replaced; an empty `rows` file (pages-forget)
# still produces a valid file rather than an error under set -euo pipefail.
#
# The drop list is written to a file and read with NR==FNR rather than passed
# to awk as a -v string: BSD awk — this script's floor — rejects a literal
# newline inside a -v assignment and produces an empty match set instead of
# failing loudly, which silently dropped every row for every page not in the
# list on any multi-page commit against an existing file.
state_replace() {
  local file="$1" pages="$2" rows="$3" tmp dropfile
  tmp="$WORKDIR/$(basename "$file").new"
  dropfile="$WORKDIR/$(basename "$file").drop"
  printf '%s\n' "$pages" >"$dropfile" || return 1
  {
    if [ -f "$file" ]; then
      awk -F'\t' 'NR == FNR {drop[$0] = 1; next} !($1 in drop)' "$dropfile" "$file" || return 1
    fi
    cat "$rows"
  } >"$tmp" || return 1
  mkdir -p "$(dirname "$file")" || return 1
  LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k2,2 "$tmp" >"$tmp.sorted" || return 1
  mv "$tmp.sorted" "$file"
}

cmd_provenance_commit() {
  local staging="${1:-}" raw="${2:-thoughts}" line page label resource fragment sha
  local end total rows distinct n=0
  [ -n "$staging" ] || usage
  if [ ! -f "$staging" ] || [ ! -r "$staging" ]; then
    report NO-STAGING provenance-commit "$staging is not a readable file"
    return 1
  fi
  raw=$(cd "${raw%/}" 2>/dev/null && pwd -P) || raw=""

  rows="$WORKDIR/provenance-pending"
  distinct="$WORKDIR/provenance-pages"
  : >"$rows"
  : >"$distinct"
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    if [ "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" -ne 4 ]; then
      report provenance-malformed "$staging" "expected 4 tab-separated fields: $line"
      continue
    fi
    page=$(printf '%s' "$line" | cut -f1)
    label=$(printf '%s' "$line" | cut -f2)
    resource=$(printf '%s' "$line" | cut -f3)
    fragment=$(printf '%s' "$line" | cut -f4)

    case "$page" in
    *.md) ;;
    *)
      report provenance-page "$staging" "page must be a .md file: $line"
      continue
      ;;
    esac
    if [ ! -f "$page" ]; then
      report provenance-page "$staging" "$page does not exist"
      continue
    fi
    if ! provenance_label_valid "$label"; then
      report provenance-label "$staging" "a label must be non-empty and free of whitespace: $line"
      continue
    fi
    if [ -z "$resource" ] || [ ! -f "$resource" ]; then
      report provenance-resource "$staging" "$resource does not exist"
      continue
    fi

    # The same zone check check_sources applies to every row it reads, applied
    # here so a row that could never pass check is refused before it is ever
    # written.
    case "$(provenance_resource_zone "$raw" "$resource")" in
    capture)
      report provenance-resource "$staging" "$resource is a capture record; a record is never cited by a page"
      continue
      ;;
    raw)
      report provenance-resource "$staging" "$resource is inside the raw root $raw, which a fresh clone does not have"
      continue
      ;;
    esac

    fragment=$(provenance_fragment_default "$fragment")
    case "$fragment" in
    "(whole)") ;;
    L[0-9]*-L[0-9]*)
      end=${fragment##*-}
      end=${end#L}
      total=$(line_count "$resource")
      if [ "$end" -gt "$total" ]; then
        report provenance-fragment "$staging" "$fragment of $resource exceeds its $total lines"
        continue
      fi
      ;;
    *)
      if ! grep -Fxq -- "$fragment" "$resource"; then
        report provenance-fragment "$staging" "the heading '$fragment' is absent from $resource"
        continue
      fi
      ;;
    esac

    sha=$(fragment_text "$resource" "$fragment" | normalize_and_hash) || {
      report HASH-FAILED "$staging" "could not hash $fragment of $resource"
      continue
    }
    printf '%s\t%s\t%s\t%s\t%s\n' "$page" "$label" "$resource" "$fragment" "$sha" >>"$rows" || {
      report PROVENANCE-FAILED provenance-commit "could not stage under $WORKDIR"
      return 1
    }
    printf '%s\n' "$page" >>"$distinct"
    n=$((n + 1))
  done <"$staging"
  [ "$fail" -eq 0 ] || return 1

  LC_ALL=C sort -u "$distinct" >"$distinct.u" && mv "$distinct.u" "$distinct"
  state_replace "$PROVENANCE" "$(cat "$distinct")" "$rows" || {
    report PROVENANCE-FAILED provenance-commit "could not write $PROVENANCE"
    return 1
  }
  echo "provenance-commit: $n rows for $(line_count "$distinct") pages in $PROVENANCE"
}

cmd_pages_commit() {
  local staging="${1:-}" page rows distinct n=0
  [ -n "$staging" ] || usage
  if [ ! -f "$staging" ] || [ ! -r "$staging" ]; then
    report NO-STAGING pages-commit "$staging is not a readable file"
    return 1
  fi

  rows="$WORKDIR/pages-pending"
  distinct="$WORKDIR/pages-distinct"
  : >"$rows"
  : >"$distinct"
  while IFS= read -r page || [ -n "$page" ]; do
    [ -n "$page" ] || continue
    if [ ! -f "$page" ]; then
      report pages-missing "$staging" "$page does not exist"
      continue
    fi
    printf '%s\t%s\n' "$page" "$(page_fingerprint "$page")" >>"$rows" || {
      report PAGES-FAILED pages-commit "could not stage under $WORKDIR"
      return 1
    }
    printf '%s\n' "$page" >>"$distinct"
    n=$((n + 1))
  done <"$staging"
  [ "$fail" -eq 0 ] || return 1

  LC_ALL=C sort -u "$distinct" >"$distinct.u" && mv "$distinct.u" "$distinct"
  state_replace "$PAGES" "$(cat "$distinct")" "$rows" || {
    report PAGES-FAILED pages-commit "could not write $PAGES"
    return 1
  }
  echo "pages-commit: $n pages in $PAGES"
}

# The point of forgetting: a page gone from disk stops being page-gone, and a
# page kept but withdrawn from the compiled set stops carrying stale
# provenance and a stale fingerprint. Neither file is required to hold a row
# for the page named, so this never fails on account of the page's own state.
cmd_pages_forget() {
  local page="${1:-}"
  [ -n "$page" ] || usage
  : >"$WORKDIR/forget-rows"
  state_replace "$PAGES" "$page" "$WORKDIR/forget-rows" || {
    report PAGES-FAILED pages-forget "could not update $PAGES"
    return 1
  }
  state_replace "$PROVENANCE" "$page" "$WORKDIR/forget-rows" || {
    report PAGES-FAILED pages-forget "could not update $PROVENANCE"
    return 1
  }
  echo "pages-forget: $page removed from $PAGES and $PROVENANCE"
}

# ------------------------------------------------------------- supersession

# A reference addresses one decision, never a whole file: a record holds several
# independent decisions, and a file-level reference invalidates the ones nobody
# touched. Two forms, both carrying a literal heading line rather than an anchor
# or a slug, because nothing here generates or resolves either:
#
#   decision <decision_id>                  a compiled decision page
#   record <path> ### <heading>             a decision inside an earlier record
#
# The path is relative to the records root. Whitespace is squeezed so two
# spellings of one reference compare equal.
supersession_normalize() {
  awk '{$1 = $1; print}'
}

# Every edge among the records under a root, as target<TAB>superseder. Both
# sides are normalized references, so an edge's endpoints are comparable with
# the target a caller names.
supersession_edges() {
  local root="$1" rec rel index total n start end nxt heading body ref
  index="$WORKDIR/edge-index"
  body="$WORKDIR/edge-body"
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    rel=${rec#"$root"/}
    capture_decision_index "$rec" >"$index" || return 1
    total=$(awk -F'\t' '$1 == "DEC" {n++} END {print n + 0}' "$index")
    end=$(awk -F'\t' '$1 == "END" {print $2; exit}' "$index")
    n=0
    while [ "$n" -lt "$total" ]; do
      n=$((n + 1))
      start=$(awk -F'\t' -v i="$n" '$1 == "DEC" {c++; if (c == i) {print $2; exit}}' "$index")
      heading=$(awk -F'\t' -v i="$n" '$1 == "DEC" {c++; if (c == i) {print $3; exit}}' "$index")
      nxt=$(awk -F'\t' -v i="$n" '$1 == "DEC" {c++; if (c == i + 1) {print $2; exit}}' "$index")
      if [ -n "$nxt" ]; then
        awk -v s="$start" -v e="$((nxt - 1))" 'NR > s && NR <= e' "$rec" >"$body" || return 1
      else
        awk -v s="$start" -v e="$end" 'NR > s && NR <= e' "$rec" >"$body" || return 1
      fi
      # Only a Supersedes: field at the start of a line is an edge. The word in
      # prose is somebody talking about supersession, not declaring one.
      while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        printf '%s\trecord %s ### %s\n' \
          "$(printf '%s' "$ref" | supersession_normalize)" "$rel" "$heading"
      done <<EOF
$(awk "$AWK_FENCE"'
  fence_line($0) {next}
  infence {next}
  index($0, "Supersedes: ") == 1 {sub(/^Supersedes:[[:space:]]*/, ""); print}' "$body")
EOF
    done
  done <<EOF
$(find "$root" -type f -name '*.md' -print | LC_ALL=C sort)
EOF
}

# Whether a reference names something that exists.
supersession_resolves() {
  local ref="$1" root="$2" docs="$3" path heading page
  case "$ref" in
  "decision "*)
    cmd_resolve_decision "$docs" "${ref#decision }" >/dev/null 2>&1
    return $?
    ;;
  "record "*" ### "*)
    path=${ref#record }
    path=${path%% \#\#\# *}
    heading=${ref#*" ### "}
    [ -f "$root/$path" ] || return 1
    record_has_heading "$root/$path" "$heading"
    return $?
    ;;
  esac
  return 1
}

cmd_supersession_scan() {
  local root="${1:-}" docs="${2:-}" target="${3:-}" edges seen queue nodes circle rec n cur sup
  [ -n "$root" ] || usage
  [ -n "$docs" ] || usage
  [ -n "$target" ] || usage
  if [ ! -d "$root" ]; then
    report NO-RECORDS-ROOT supersession-scan "$root is not a directory"
    return 1
  fi

  # A record the format check rejects cannot be parsed for edges, so the scan
  # over this root is incomplete. An incomplete scan is never reported as "no
  # supersession found": it exits 3, which is neither the clean 0 nor the 1 a
  # dangling reference or a cycle produces.
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    if ! "$self" check-capture "$rec" >/dev/null 2>&1; then
      report scan-incomplete "$rec" \
        "this record does not conform, so the supersession scan over $root cannot be complete"
      fail=3
      return 3
    fi
  done <<EOF
$(find "$root" -type f -name '*.md' -print | LC_ALL=C sort)
EOF

  edges="$WORKDIR/edges"
  supersession_edges "$root" >"$edges" || {
    report SCAN-FAILED supersession-scan "could not read the records under $root"
    return 1
  }

  # Every reference must name something. A dangling one is a claim about a
  # decision nobody wrote, and leaving it unreported would let the scan look
  # complete while missing whatever the reference meant.
  while IFS= read -r sup; do
    [ -n "$sup" ] || continue
    if ! supersession_resolves "$sup" "$root" "$docs"; then
      report supersession-dangling "$sup" "no decision under $root or $docs answers to this reference"
    fi
  done <<EOF
$(cut -f1 "$edges" | LC_ALL=C sort -u)
EOF
  [ "$fail" -eq 0 ] || return 1

  seen="$WORKDIR/scan-seen"
  queue="$WORKDIR/scan-queue"
  printf '%s\n' "$(printf '%s' "$target" | supersession_normalize)" >"$queue"
  : >"$seen"

  n=0
  while [ "$n" -lt "$(line_count "$queue")" ]; do
    n=$((n + 1))
    cur=$(awk -v i="$n" 'NR==i' "$queue")
    while IFS= read -r sup; do
      [ -n "$sup" ] || continue
      if ! grep -Fxq -- "$sup" "$seen"; then
        printf '%s\n' "$sup" >>"$seen" || {
          report SCAN-FAILED supersession-scan "could not extend the result set under $WORKDIR"
          return 1
        }
        printf '%s\n' "$sup" >>"$queue" || {
          report SCAN-FAILED supersession-scan "could not extend the queue under $WORKDIR"
          return 1
        }
      fi
    done <<EOF
$(awk -F'\t' -v t="$cur" '$1 == t {print $2}' "$edges")
EOF
  done

  # Supersession is terminal, so the family the walk reached must be an order:
  # something first, something last. Peeling every decision that nothing in the
  # family supersedes leaves exactly the ones that sit in a circle. Asking only
  # whether the walk returned to the target misses a circle further out, and
  # calling any second visit a circle would reject a decision two others both
  # lead to, which is an order and not a loop.
  nodes="$WORKDIR/scan-nodes"
  { printf '%s\n' "$(printf '%s' "$target" | supersession_normalize)"; cat "$seen"; } |
    LC_ALL=C sort -u >"$nodes"
  circle=$(awk -F'\t' '
    NR == FNR {node[$0] = 1; total++; next}
    ($1 in node) && ($2 in node) {from[++m] = $1; to[m] = $2; indeg[$2]++}
    END {
      changed = 1
      while (changed) {
        changed = 0
        for (n in node) {
          if (gone[n] || indeg[n] + 0 > 0) continue
          gone[n] = 1
          changed = 1
          for (i = 1; i <= m; i++) if (!cut[i] && from[i] == n) {cut[i] = 1; indeg[to[i]]--}
        }
      }
      for (n in node) if (!gone[n]) print n
    }' "$nodes" "$edges" | LC_ALL=C sort)
  if [ -n "$circle" ]; then
    while IFS= read -r cur; do
      report supersession-cycle "$cur" "this decision sits in a circle of references reachable from $target"
    done <<EOF
$circle
EOF
    return 1
  fi

  if [ ! -s "$seen" ]; then
    echo "supersession-scan: nothing supersedes $target"
    return 0
  fi
  LC_ALL=C sort "$seen"
}

# ----------------------------------------------------------- the run claim

# One claim covers a whole run, from its first action to its last, rather than
# the snapshot and the verification separately. A publisher writing the raw
# layer during a live session is what makes the gap matter: a claim held only
# across the two ends leaves the middle open, and the run edits the compiled
# layer in that middle with no staged output and nothing to roll back.
#
# It is repository-local and lives beside the git directory, so it is outside
# every snapshot and never reaches a commit. A linked worktree gets its own,
# which is the right scope: each worktree has its own compiled layer.
claim_dir() {
  local gd
  gd=$(git rev-parse --absolute-git-dir 2>/dev/null) || return 1
  [ -n "$gd" ] || return 1
  printf '%s/kb-claim\n' "$gd"
}

# Identity of the current boot. A machine that rebooted did not carry the
# owning process across, whatever its pid says now.
boot_identity() {
  if [ -r /proc/sys/kernel/random/boot_id ]; then
    cat /proc/sys/kernel/random/boot_id
  elif sysctl -n kern.boottime >/dev/null 2>&1; then
    sysctl -n kern.boottime
  else
    echo unknown
  fi
}

# When a process started, empty when it is not running. A pid alone is not an
# identity: the number is reused, and a reused number belongs to a different
# process than the one that took the claim.
process_start() {
  ps -o lstart= -p "$1" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

claim_record() {
  find "$1" -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort | awk 'NR==1'
}

claim_field() {
  awk -v k="$2" 'index($0, k ": ") == 1 {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$1"
}

# held, abandoned, or unknown. Three facts each establish that the owner is
# gone: no such process, a process that started at a different moment, and a
# machine that has rebooted since. The converse does not follow — a live
# process is not proof the run is still going — so a live owner is never
# assumed finished and always needs an explicit release.
claim_state() {
  local rec="$1" pid started
  [ -n "$rec" ] && [ -f "$rec" ] || {
    echo unknown
    return 0
  }
  if [ "$(claim_field "$rec" boot)" != "$(boot_identity)" ]; then
    echo abandoned
    return 0
  fi
  pid=$(claim_field "$rec" pid)
  started=$(process_start "$pid")
  if [ -z "$started" ] || [ "$started" != "$(claim_field "$rec" started)" ]; then
    echo abandoned
    return 0
  fi
  echo held
}

# The state of an existing claim, reported. Shared by acquire, which refuses on
# it, and inspect, which exists to print it.
claim_report() {
  local dir="$1" mode="$2" rec state
  rec=$(claim_record "$dir")
  state=$(claim_state "$rec")
  case "$state" in
  held)
    report claim-held "$mode" \
      "run $(claim_field "$rec" run) holds the claim, its process $(claim_field "$rec" pid) is alive, and only that run may release it"
    ;;
  abandoned)
    report claim-abandoned "$mode" \
      "run $(claim_field "$rec" run) held the claim and its process is gone — look at what it left in the compiled layer, then release run $(claim_field "$rec" run) by hand"
    ;;
  *)
    report claim-held "$mode" \
      "a claim exists at $dir with no owner record — look at what is there before releasing it"
    ;;
  esac
}

cmd_claim_acquire() {
  local session="${1:-}" pid="${2:-}" dir runid started
  [ -n "$pid" ] || usage
  dir=$(claim_dir) || {
    report NO-GIT-DIR claim-acquire "not inside a git repository, and the claim is repository-local"
    return 1
  }
  started=$(process_start "$pid")
  if [ -z "$started" ]; then
    report NO-SUCH-PROCESS claim-acquire "process $pid is not running, so it cannot own a claim"
    return 1
  fi

  # mkdir is the whole of the exclusion: it either creates the directory or
  # fails because someone else already did, in one step nothing can interleave.
  if ! mkdir "$dir" 2>/dev/null; then
    claim_report "$dir" claim-acquire
    return 1
  fi

  runid=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
  {
    echo "run: $runid"
    echo "tree: $(git rev-parse --show-toplevel)"
    echo "session: ${session:-missing}"
    echo "host: $(hostname)"
    echo "boot: $(boot_identity)"
    echo "pid: $pid"
    echo "started: $started"
  } >"$dir/$runid" || {
    rm -f "$dir/$runid"
    rmdir "$dir" 2>/dev/null
    report CLAIM-FAILED claim-acquire "could not write the owner record under $dir"
    return 1
  }
  echo "claim-acquire: run $runid holds the claim for $(git rev-parse --show-toplevel)" >&2
  printf '%s\n' "$runid"
}

cmd_claim_release() {
  local runid="${1:-}" dir
  [ -n "$runid" ] || usage
  dir=$(claim_dir) || {
    report NO-GIT-DIR claim-release "not inside a git repository, and the claim is repository-local"
    return 1
  }
  if [ ! -d "$dir" ]; then
    report claim-absent claim-release "there is no claim to release"
    return 1
  fi
  # The run id is in the path, so removing the file is the ownership check.
  # Checking first and then removing a fixed name would let a second operator
  # delete a claim taken between their check and their delete.
  if ! rm "$dir/$runid" 2>/dev/null; then
    report claim-not-owner claim-release "run $runid does not hold the claim"
    return 1
  fi
  rmdir "$dir" 2>/dev/null || {
    report CLAIM-FAILED claim-release "released run $runid, but $dir still holds something — look at what"
    return 1
  }
  echo "claim-release: run $runid released the claim"
}

cmd_claim_inspect() {
  local dir rec
  dir=$(claim_dir) || {
    report NO-GIT-DIR claim-inspect "not inside a git repository, and the claim is repository-local"
    return 1
  }
  if [ ! -d "$dir" ]; then
    echo "claim-inspect: no claim is held"
    return 0
  fi
  rec=$(claim_record "$dir")
  [ -n "$rec" ] && cat "$rec"
  claim_report "$dir" claim-inspect
  return 1
}

# ------------------------------------------------------- decision identifiers

# A decision page's name, derived from its body and then stored. Deriving it
# from content rather than from a date is what lets two machines share one
# compiled layer while each keeps its own untracked raw layer: a date-keyed name
# collides across them. The frontmatter is not part of the derivation, so
# writing the identifier into the page does not change it, and neither does an
# editorial rename of the title.
#
# The identifier is assigned once and stored. It is never recomputed and
# compared: a page whose prose was tightened is the same decision, and a
# substantively new decision gets a new page and a new assignment.
cmd_assign_id() {
  local page="${1:-}"
  [ -n "$page" ] || usage
  if [ ! -f "$page" ]; then
    report NO-PAGE assign-id "$page is not a file"
    return 1
  fi
  fragment_text "$page" "(whole)" | normalize_and_hash
}

# Identifiers seen so far, id<TAB>page. A page carrying none is reported as it
# is checked; duplicates need the whole set, so they wait for the loop to end.
# Gated on registration rather than on a type: key — an unregistered page under
# decisions/ is a draft nobody has compiled yet, and requiring an identifier of
# it would report every page kb:weave has not reached.
check_decision_id() {
  local page="$1" decisions="$2" ids="$3" id
  page_registered "$page" || return 0
  # An empty decisions: — absent from the schema, or present with no value,
  # which an adopted tree with no decisions directory yet has every reason to
  # carry — must never become the "$decisions"/* glob: with an empty prefix
  # that pattern is /* and matches any absolute page path, holding every
  # registered page to a rule meant only for pages under decisions/.
  [ -n "$decisions" ] || return 0
  case "$page" in
  "$decisions"/*) ;;
  *) return 0 ;;
  esac
  id=$(fm_value "$page" decision_id)
  if [ -z "$id" ]; then
    report decision-id-missing "$page" "a decision page carries no decision_id, so no reference can name it across a rename"
    return 0
  fi
  printf '%s\t%s\n' "$id" "$page" >>"$ids"
}

# A registered page whose current bytes no longer match the fingerprint
# .kb/pages.tsv recorded. Advisory: an edit after compilation is not wrong, it
# is a page kb:lint has not looked at since.
check_fingerprint() {
  local page="$1" recorded current
  page_registered "$page" || return 0
  recorded=$(awk -F'\t' -v p="$page" '$1 == p {print $2; exit}' "$PAGES")
  current=$(page_fingerprint "$page")
  if [ "$current" != "$recorded" ]; then
    note page-edited "$page" "changed since the compiler last wrote it; kb:lint inspects it"
  fi
  return 0
}

# A deprecated page keeps its links and its history, and where a replacement
# was built it names it. The link is by identifier, so it survives the
# replacement being renamed; a value naming nothing is a promise of a successor
# that does not exist, which is worse than the third row's honest silence.
check_superseded_by() {
  local page="$1" refs="$2" id
  id=$(fm_value "$page" superseded_by)
  [ -n "$id" ] || return 0
  printf '%s\t%s\n' "$id" "$page" >>"$refs"
}

check_superseded_by_resolves() {
  local refs="$1" ids="$2" id page
  [ -s "$refs" ] || return 0
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if ! cut -f1 "$ids" | grep -Fxq -- "${id%%\t*}"; then
      page=$(awk -F'\t' -v i="${id%%\t*}" '$1 == i {print $2; exit}' "$refs")
      report superseded-by-dangling "$page" "superseded_by names ${id%%\t*}, which no page carries"
    fi
  done <<EOF
$(cut -f1 "$refs" | LC_ALL=C sort -u)
EOF
}

check_decision_id_unique() {
  local ids="$1" dup pages
  [ -s "$ids" ] || return 0
  while IFS= read -r dup; do
    [ -n "$dup" ] || continue
    pages=$(awk -F'\t' -v i="$dup" '$1 == i {printf "%s ", $2}' "$ids")
    report decision-id-duplicate "$dup" "carried by more than one page: ${pages% }"
  done <<EOF
$(cut -f1 "$ids" | LC_ALL=C sort | uniq -d)
EOF
}

# The page an identifier names. A path hint is a location, never the reference:
# a renamed page still resolves, and a path reoccupied by a different decision
# does not resolve the old one. That second case is the reason the identifier
# exists — a rename produces an observable miss somebody notices, while a reused
# path resolves successfully to the wrong decision and nothing reports it.
cmd_resolve_decision() {
  local docs="${1:-}" id="${2:-}" hint="${3:-}" matches page count
  [ -n "$docs" ] || usage
  [ -n "$id" ] || usage
  if [ ! -d "$docs" ]; then
    report NO-DOCS-ROOT resolve-decision "$docs is not a directory"
    return 1
  fi

  matches="$WORKDIR/resolve"
  : >"$matches"
  while IFS= read -r page; do
    [ -n "$page" ] || continue
    if [ "$(fm_value "$page" decision_id)" = "$id" ]; then
      printf '%s\n' "$page" >>"$matches" || {
        report RESOLVE-FAILED "$id" "could not record a match under $WORKDIR"
        return 1
      }
    fi
  done <<EOF
$(find "$docs" -type f -name '*.md' -print | LC_ALL=C sort)
EOF

  count=$(line_count "$matches")
  if [ "$count" -eq 0 ]; then
    report decision-ref-dangling "$id" "no page under $docs carries this decision_id"
    return 1
  fi
  if [ "$count" -gt 1 ]; then
    report decision-id-duplicate "$id" "carried by more than one page: $(tr '\n' ' ' <"$matches")"
    return 1
  fi

  page=$(awk 'NR==1' "$matches")
  if [ -n "$hint" ] && [ "$hint" != "${page#"$docs"/}" ]; then
    note stale-path-hint "$id" "the reference points at $hint; the decision now lives at ${page#"$docs"/}"
  fi
  printf '%s\n' "$page"
}

cmd_check() {
  local docs="${1:-docs}" raw="${2:-thoughts}" map decisions page line path
  docs="${docs%/}"
  # A provenance row's resource resolves against the working directory, not
  # against the raw root: a citation names tracked code or checked-in config,
  # which lives anywhere in the repository. The raw root is here so the
  # opposite can be caught — a citation that points inside it.
  # Resolved once, so every citation compares against one spelling of the tree.
  # An absent raw root leaves it empty, and no citation can then match it.
  raw=$(cd "${raw%/}" 2>/dev/null && pwd -P) || raw=""

  if [ ! -d "$docs" ]; then
    report NO-DOCS-ROOT check "$docs is not a directory — nothing to check"
    return 1
  fi

  [ -f "$SCHEMA" ] || {
    report schema-missing "$SCHEMA" "no schema; run kb:weave to seed or adopt"
    return 1
  }
  map=$(fm_value "$SCHEMA" map)
  if [ -z "$map" ] || [ ! -f "$map" ]; then
    report map-missing "$SCHEMA" "map: names $map, which does not exist"
    return 1
  fi
  decisions=$(fm_value "$SCHEMA" decisions)
  decisions="${decisions%/}"

  # Enumerate once, into a file, guarded. A find that fails partway — one
  # unreadable subdirectory is enough — would otherwise leave those pages
  # unchecked and still print the OK line, which is a run that checked nothing
  # reporting success.
  find "$docs" -type f -name '*.md' -print | LC_ALL=C sort >"$WORKDIR/pages" || {
    report CHECK-FAILED "$docs" "could not enumerate the pages under $docs"
    return 1
  }

  : >"$WORKDIR/decision-ids"
  : >"$WORKDIR/superseded-by"

  while IFS= read -r page; do
    [ -n "$page" ] || continue
    check_page_frontmatter "$page"
    check_links "$page"
    check_anchors "$page"
    check_open_markers "$page"
    check_footnote_join "$page"
    check_sources "$page" "$raw"
    check_external_claims "$page"
    check_decision_id "$page" "$decisions" "$WORKDIR/decision-ids"
    check_superseded_by "$page" "$WORKDIR/superseded-by"
    check_fingerprint "$page"
  done <"$WORKDIR/pages"

  check_decision_id_unique "$WORKDIR/decision-ids"
  check_superseded_by_resolves "$WORKDIR/superseded-by" "$WORKDIR/decision-ids"
  check_reachability "$docs" "$map"

  # A page .kb/pages.tsv still names but that no longer sits under $docs —
  # moved, renamed, or deleted since it was registered.
  if [ -f "$PAGES" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      path=$(printf '%s' "$line" | cut -f1)
      if ! grep -Fxq -- "$path" "$WORKDIR/pages"; then
        report page-gone "$path" "registered in $PAGES but not on disk; kb:lint moves or forgets it"
      fi
    done <"$PAGES"
  fi

  # A page .kb/provenance.tsv still cites but that is not among the pages the
  # loop above walked — provenance-commit refuses this at commit time (the
  # page must exist to be staged), so it only arises from a hand-edited or
  # migrated ledger, the page loop having no other way to see a row for a
  # page it never enumerated.
  if [ -f "$PROVENANCE" ]; then
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      if ! grep -Fxq -- "$path" "$WORKDIR/pages"; then
        report provenance-gone "$path" "cited in $PROVENANCE but not on disk; provenance-commit or pages-forget clears it"
      fi
    done <<EOF
$(cut -f1 "$PROVENANCE" | LC_ALL=C sort -u)
EOF
  fi

  if [ "$fail" -eq 0 ]; then
    echo "OK: $(line_count "$WORKDIR/pages") pages under $docs conform"
  fi
}

# ------------------------------------------------------------------------ main

[ $# -ge 1 ] || usage

mode="$1"
shift

case "$mode" in
# || fail=1 rather than || true: a mode function returns non-zero for a failure
# it could not route through report, and swallowing that would exit 0 on a run
# that checked nothing.
snapshot) cmd_snapshot "$@" || fail=1 ;;
verify-sources) cmd_verify_sources "$@" || fail=1 ;;
check) cmd_check "$@" || fail=1 ;;
check-capture) cmd_check_capture "$@" || fail=1 ;;
assign-id) cmd_assign_id "$@" || fail=1 ;;
resolve-decision) cmd_resolve_decision "$@" || fail=1 ;;
claim-acquire) cmd_claim_acquire "$@" || fail=1 ;;
claim-release) cmd_claim_release "$@" || fail=1 ;;
claim-inspect) cmd_claim_inspect "$@" || fail=1 ;;
supersession-scan) cmd_supersession_scan "$@" || fail=$? ;;
captures-eligible) cmd_captures_eligible "$@" || fail=1 ;;
captures-deferred) cmd_captures_deferred "$@" || fail=1 ;;
sources-pending) cmd_sources_pending "$@" || fail=1 ;;
consumed-commit) cmd_consumed_commit "$@" || fail=1 ;;
consumed-check) cmd_consumed_check "$@" || fail=1 ;;
provenance-commit) cmd_provenance_commit "$@" || fail=1 ;;
pages-commit) cmd_pages_commit "$@" || fail=1 ;;
pages-forget) cmd_pages_forget "$@" || fail=1 ;;
*) usage ;;
esac

exit "$fail"
