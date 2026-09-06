#!/usr/bin/env bash
# Conformance, reachability, provenance, and raw-source immutability checks for
# a knowledge base compiled by kb:weave.
#
#   snapshot [raw-root]                    hash every raw source, print the manifest path
#   verify-sources <manifest> [raw-root]   prove the raw layer did not change during a run
#   check [docs-root] [raw-root]           every conformance rule over the compiled tree
#   check-capture <record>                 the format rules for one capture record
#   assign-id <page>                       an identifier for a new decision page
#   resolve-decision <docs-root> <id> [path-hint]
#                                          the page an identifier names
#   claim-acquire <session-id> <pid>       take the whole-run claim, print its run id
#   claim-release <run-id>                 give it back
#   claim-inspect                          say who holds it and whether they are alive
#   supersession-scan <records-root> <docs-root> <target>
#                                          every record decision that supersedes a target
#   receipt-commit <receipt> <records-root> <staging>
#                                          record what a validated run consumed
#   receipt-check <receipt> <records-root> the receipt's own format and its hashes
#   captures-eligible <records-root> [receipt]
#                                          decisions no run has consumed yet
#   captures-deferred <records-root> <receipt>
#                                          decisions a run looked at and left
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
       $self receipt-commit <receipt> <records-root> <staging>
       $self receipt-check <receipt> <records-root>
       $self captures-eligible <records-root> [receipt]
       $self captures-deferred <records-root> <receipt>
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

# The one list of maps this schema carries, flattened to index<TAB>key<TAB>value.
# Deliberately not a YAML parser: it reads `sources:` at column 1, then treats an
# indented `- key: value` as the start of an entry and any further indented
# `key: value` as belonging to it.
sources_records() {
  awk '
    NR==1 && $0!="---" {exit}
    NR==1 {infm=1; next}
    infm && $0=="---" {exit}
    !infm {next}
    /^sources:[[:space:]]*$/ {insrc=1; idx=0; next}
    insrc && /^[^[:space:]]/ {insrc=0}
    insrc && /^[[:space:]]*-[[:space:]]/ {
      idx++
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      emit(idx, line)
      next
    }
    insrc && /^[[:space:]]+[^[:space:]-]/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      emit(idx, line)
      next
    }
    function emit(i, s,   k, v, first) {
      if (s !~ /:/) return
      k = s; sub(/:.*$/, "", k)
      v = s; sub(/^[^:]*:[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v)
      first = substr(v, 1, 1)
      if (length(v) >= 2 && first == substr(v, length(v), 1) &&
          (first == "\"" || first == "\047")) {
        v = substr(v, 2, length(v) - 2)
      }
      print i "\t" k "\t" v
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

  # Every loop that reports reads from a heredoc rather than a pipe, for the
  # reason check_log gives: a report inside a pipeline sets fail=1 in a subshell
  # and throws it away.
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
  local page="$1" root_index="$2" base end
  base=$(basename "$page")
  end=$(fm_end "$page")

  case "$base" in
  index.md)
    if [ "$page" != "$root_index" ] && [ "$(head -1 "$page")" = "---" ]; then
      report index-frontmatter "$page" "an index.md below the bundle root carries frontmatter"
    fi
    ;;
  # The rule table defines no frontmatter rule for log.md, so it gets none here.
  # It stays reserved for type-required below and for unreachable in
  # check_reachability, both of which exempt it by name.
  log.md) ;;
  *)
    if [ "$(head -1 "$page")" != "---" ]; then
      report frontmatter-present "$page" "no --- on line 1"
      return 0
    fi
    ;;
  esac

  if [ "$(head -1 "$page")" = "---" ] && [ "$end" -eq 0 ]; then
    report frontmatter-parseable "$page" "the opening --- has no closing ---"
    return 0
  fi

  case "$base" in
  index.md | log.md) ;;
  *)
    if [ -z "$(fm_value "$page" type)" ]; then
      report type-required "$page" "no type: key, or its value is empty"
    fi
    ;;
  esac
}

check_root_index() {
  local root_index="$1" keys
  if [ ! -f "$root_index" ]; then
    report index-version-key "$root_index" "the bundle root has no index.md"
    return 0
  fi
  if [ "$(head -1 "$root_index")" != "---" ] || [ "$(fm_end "$root_index")" -eq 0 ]; then
    report index-version-key "$root_index" "the bundle-root index.md carries no frontmatter block"
    return 0
  fi
  keys=$(fm_keys "$root_index")
  if [ "$keys" != "okf_version" ]; then
    report index-version-key "$root_index" \
      "frontmatter keys are [$(printf '%s' "$keys" | tr '\n' ' ')], expected okf_version alone"
  fi
}

check_log() {
  local log="$1" prev="" h d
  # Every loop that reports reads from a heredoc rather than a pipe: a `report`
  # inside a pipeline runs in a subshell, where fail=1 is set and then thrown
  # away, and the script would exit 0 while printing failures.
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    case "$h" in
    "## "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *)
      report log-date-format "$log" "heading '$h' is not ## YYYY-MM-DD"
      continue
      ;;
    esac
    d=${h#\#\# }
    if [ -n "$prev" ] && [ ! "$prev" \> "$d" ]; then
      report log-date-order "$log" "$prev is not newer than the $d that follows it"
    fi
    prev="$d"
  done <<EOF
$(strip_code "$log" | awk '/^## / {print}')
EOF
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

check_sources() {
  local page="$1" raw="$2" recs idx resource fragment recorded retired text actual total end resolved
  recs=$(sources_records "$page")
  [ -n "$recs" ] || return 0

  for idx in $(printf '%s\n' "$recs" | cut -f1 | LC_ALL=C sort -un); do
    retired=$(printf '%s\n' "$recs" | awk -F'\t' -v i="$idx" '$1==i && $2=="retired" {print $3; exit}')
    [ "$retired" = "true" ] && continue

    resource=$(printf '%s\n' "$recs" | awk -F'\t' -v i="$idx" '$1==i && $2=="resource" {print $3; exit}')
    fragment=$(printf '%s\n' "$recs" | awk -F'\t' -v i="$idx" '$1==i && $2=="fragment" {print $3; exit}')
    recorded=$(printf '%s\n' "$recs" | awk -F'\t' -v i="$idx" '$1==i && $2=="sha256" {print $3; exit}')

    if [ -z "$resource" ]; then
      report source-missing "$page" "sources[$idx] carries no resource"
      continue
    fi
    if [ ! -f "$resource" ]; then
      report source-missing "$page" "sources[$idx] names $resource, which does not exist"
      continue
    fi

    # Every citation must name a file the reader's clone holds. A path inside
    # the raw root is an internal note: a fresh clone does not have it, so the
    # claim it supports cannot be checked by anyone but the author. A capture
    # record is called out separately because it is not merely untracked — it
    # sits outside the source trust order entirely, never competing for a page
    # and never cited by one.
    # Both sides are resolved before comparing, so a relative citation and an
    # absolute raw root are still recognised as the same tree.
    resolved=$(abspath "$resource")
    # With no raw root on disk there is no tree to be inside, and an empty
    # prefix would match any absolute path.
    [ -n "$raw" ] && case "$resolved" in
    "$raw"/captures/*)
      report source-is-capture "$page" "sources[$idx] names the capture record $resource; a record is never cited by a page"
      continue
      ;;
    "$raw"/*)
      report source-in-raw-root "$page" "sources[$idx] names $resource, inside the raw root, which a fresh clone does not have"
      continue
      ;;
    esac
    [ -n "$fragment" ] || fragment="(whole)"

    case "$fragment" in
    "(whole)") ;;
    L[0-9]*-L[0-9]*)
      end=${fragment##*-}
      end=${end#L}
      total=$(line_count "$resource")
      if [ "$end" -gt "$total" ]; then
        report fragment-missing "$page" \
          "sources[$idx] cites $fragment of $resource, which has $total lines"
        continue
      fi
      ;;
    *)
      if ! grep -Fxq -- "$fragment" "$resource"; then
        report fragment-missing "$page" \
          "sources[$idx] cites the heading '$fragment', absent from $resource"
        continue
      fi
      ;;
    esac

    [ -n "$recorded" ] || continue
    text=$(fragment_text "$resource" "$fragment")
    actual=$(printf '%s\n' "$text" | normalize_and_hash)
    if [ "$actual" != "$recorded" ]; then
      report source-drift "$page" \
        "sources[$idx] records $recorded for $fragment of $resource, which now hashes to $actual"
    fi
  done
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
  local docs="$1" root_index="$2" seen queue cur dir t resolved n page base
  [ -f "$root_index" ] || return 0

  seen="$WORKDIR/seen"
  queue="$WORKDIR/queue"

  abspath "$root_index" >"$seen" || {
    report REACHABILITY-FAILED "$docs" "could not write the traversal set under $WORKDIR"
    return 1
  }
  cp "$seen" "$queue" || {
    report REACHABILITY-FAILED "$docs" "could not seed the traversal queue under $WORKDIR"
    return 1
  }

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
    base=$(basename "$page")
    case "$base" in
    log.md | WIKI.md) continue ;;
    esac
    resolved=$(abspath "$page")
    if ! grep -Fxq -- "$resolved" "$seen"; then
      report unreachable "$page" "not reachable from $root_index by following relative .md links"
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
# the receipt does not record as consumed — while which of them a run actually
# takes is the model's choice, and the run's report is the only place that
# choice is written down. Detecting that a record is eligible therefore does not
# guarantee it was examined.
cmd_captures_eligible() {
  local root="${1:-}" receipt="${2:-}" line path heading
  [ -n "$root" ] || usage
  if [ ! -d "$root" ]; then
    report NO-RECORDS-ROOT captures-eligible "$root is not a directory"
    return 1
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    path=$(printf '%s' "$line" | cut -f1)
    heading=$(printf '%s' "$line" | cut -f2)
    if [ -n "$receipt" ] && [ -f "$receipt" ] &&
      awk -F'\t' -v p="$path" -v h="$heading" \
        '$1 == p && $3 == "consumed" && $4 == h {found = 1} END {exit found ? 0 : 1}' "$receipt"; then
      continue
    fi
    printf '%s\t%s\n' "$path" "$heading"
  done <<EOF
$(capture_decisions_all "$root")
EOF
}

# The decisions a run looked at and left. A deferred decision waits indefinitely
# rather than expiring, so something has to come back to it, and that something
# is a pass the owner starts. Nothing here wakes it.
cmd_captures_deferred() {
  local root="${1:-}" receipt="${2:-}"
  [ -n "$root" ] || usage
  [ -n "$receipt" ] || usage
  if [ ! -f "$receipt" ]; then
    report NO-RECEIPT captures-deferred "$receipt is not a file"
    return 1
  fi
  awk -F'\t' '$3 == "deferred" {print $1 "\t" $4}' "$receipt" | LC_ALL=C sort -u
}

# ----------------------------------------------------------------- receipt

# What a run consumed and what it left, per capture and per decision. A record
# is routinely half compiled and half deferred, so acknowledgement is per
# decision: marking a whole record done would lose the deferred half.
#
# The file is tab-separated rather than markdown, so the page enumeration never
# sees it and it needs no exemption. It is tracked and committed alongside the
# pages it describes, so reverting a bad run reverts its bookkeeping too — an
# untracked receipt survives that revert and goes on claiming captures were
# acknowledged for pages that no longer exist.
#
#   <record path>\t<capture id>\t<state>\t<decision heading>
#
# The capture id is the hash of the record's content, stored rather than
# recomputed from a slug — the one disclosed failure in this shape was a slug
# collision that staged hundreds of records and ingested none. It is also what
# proves the record on disk is the one that was acknowledged: a published record
# is immutable, so a mismatch means somebody edited one. Deriving a second hash
# of the same bytes to hold separately would invent a distinction that is not
# there.
#
# A deferred decision carries no expiry. It waits until a run returns to it, and
# nothing here counts down.
receipt_identity() {
  fragment_text "$1" "(whole)" | normalize_and_hash
}

receipt_validate_line() {
  local line="$1" root="$2" subject="$3" path id state heading actual
  case "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" in
  4) ;;
  *)
    report receipt-malformed "$subject" "expected four tab-separated fields, got: $line"
    return 1
    ;;
  esac
  path=$(printf '%s' "$line" | cut -f1)
  id=$(printf '%s' "$line" | cut -f2)
  state=$(printf '%s' "$line" | cut -f3)
  heading=$(printf '%s' "$line" | cut -f4)

  case "$state" in
  consumed | deferred) ;;
  *)
    report receipt-malformed "$subject" "state '$state' is neither consumed nor deferred"
    return 1
    ;;
  esac
  if [ -z "$heading" ]; then
    report receipt-malformed "$subject" "no decision heading on the entry for $path"
    return 1
  fi
  if [ ! -f "$root/$path" ]; then
    report receipt-record-missing "$subject" "$path is not a record under $root"
    return 1
  fi
  if ! record_has_heading "$root/$path" "$heading"; then
    report receipt-heading-missing "$subject" \
      "$path holds no decision headed '$heading' — the entry marks nothing consumed"
    return 1
  fi
  actual=$(receipt_identity "$root/$path")
  if [ "$id" != "$actual" ]; then
    report receipt-record-changed "$subject" \
      "the entry for $path stores $id and the record now hashes to $actual — a published record is immutable"
    return 1
  fi
  return 0
}

# The staged lines a run produces carry no identity: the checker computes it, so
# the format has one implementation rather than a writer in prose and a reader
# in code.
#
#   <record path>\t<state>\t<decision heading>
cmd_receipt_commit() {
  local receipt="${1:-}" root="${2:-}" staging="${3:-}" pending line path state heading
  [ -n "$receipt" ] || usage
  [ -n "$root" ] || usage
  [ -n "$staging" ] || usage
  if [ ! -f "$staging" ]; then
    report NO-STAGING receipt-commit "$staging is not a file"
    return 1
  fi

  pending="$WORKDIR/receipt-pending"
  : >"$pending"

  # Every staged line is expanded and validated before anything is written. A
  # run that fails here leaves the receipt exactly as it was, which is what
  # makes an interrupted run leave no entry.
  # `read` returns non-zero on a last line with no newline after it, and the
  # line is still in the variable: without the second test the whole entry is
  # dropped and the run reports a success that recorded nothing.
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    case "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" in
    3) ;;
    *)
      report staging-malformed receipt-commit "expected three tab-separated fields, got: $line"
      return 1
      ;;
    esac
    path=$(printf '%s' "$line" | cut -f1)
    state=$(printf '%s' "$line" | cut -f2)
    heading=$(printf '%s' "$line" | cut -f3)
    if [ ! -f "$root/$path" ]; then
      report receipt-record-missing receipt-commit "$path is not a record under $root"
      return 1
    fi
    printf '%s\t%s\t%s\t%s\n' "$path" "$(receipt_identity "$root/$path")" "$state" "$heading" >>"$pending"
  done <"$staging"

  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    receipt_validate_line "$line" "$root" receipt-commit || return 1
  done <"$pending"

  cat "$pending" >>"$receipt" || {
    report RECEIPT-FAILED receipt-commit "could not append to $receipt"
    return 1
  }
  echo "receipt-commit: $(line_count "$pending") decisions recorded in $receipt"
}

cmd_receipt_check() {
  local receipt="${1:-}" root="${2:-}" line
  [ -n "$receipt" ] || usage
  [ -n "$root" ] || usage
  if [ ! -f "$receipt" ]; then
    report NO-RECEIPT receipt-check "$receipt is not a file"
    return 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    receipt_validate_line "$line" "$root" "$receipt" || true
  done <"$receipt"
  if [ "$fail" -eq 0 ]; then
    echo "receipt-check: $(line_count "$receipt") entries in $receipt conform"
  fi
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
check_decision_id() {
  local page="$1" ids="$2" id
  [ "$(fm_value "$page" type)" = "decision" ] || return 0
  id=$(fm_value "$page" decision_id)
  if [ -z "$id" ]; then
    report decision-id-missing "$page" "a decision page carries no decision_id, so no reference can name it across a rename"
    return 0
  fi
  printf '%s\t%s\n' "$id" "$page" >>"$ids"
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
  local docs="${1:-docs}" raw="${2:-thoughts}" root_index page base
  # A sources[].resource resolves against the working directory, not against the
  # raw root: a citation names tracked code or checked-in config, which lives
  # anywhere in the repository. The raw root is here so the opposite can be
  # caught — a citation that points inside it.
  # Resolved once, so every citation compares against one spelling of the tree.
  # An absent raw root leaves it empty, and no citation can then match it.
  raw=$(cd "${raw%/}" 2>/dev/null && pwd -P) || raw=""

  if [ ! -d "$docs" ]; then
    report NO-DOCS-ROOT check "$docs is not a directory — nothing to check"
    return 1
  fi
  root_index="$docs/index.md"

  # Enumerate once, into a file, guarded. A find that fails partway — one
  # unreadable subdirectory is enough — would otherwise leave those pages
  # unchecked and still print the OK line, which is a run that checked nothing
  # reporting success.
  find "$docs" -type f -name '*.md' -print | LC_ALL=C sort >"$WORKDIR/pages" || {
    report CHECK-FAILED "$docs" "could not enumerate the pages under $docs"
    return 1
  }

  check_root_index "$root_index"

  : >"$WORKDIR/decision-ids"
  : >"$WORKDIR/superseded-by"

  while IFS= read -r page; do
    [ -n "$page" ] || continue
    check_page_frontmatter "$page" "$root_index"
    check_links "$page"
    check_sources "$page" "$raw"
    check_external_claims "$page"
    check_decision_id "$page" "$WORKDIR/decision-ids"
    check_superseded_by "$page" "$WORKDIR/superseded-by"
    base=$(basename "$page")
    if [ "$base" = "log.md" ]; then
      check_log "$page"
    fi
  done <"$WORKDIR/pages"

  check_decision_id_unique "$WORKDIR/decision-ids"
  check_superseded_by_resolves "$WORKDIR/superseded-by" "$WORKDIR/decision-ids"
  check_reachability "$docs" "$root_index"

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
receipt-commit) cmd_receipt_commit "$@" || fail=1 ;;
receipt-check) cmd_receipt_check "$@" || fail=1 ;;
captures-eligible) cmd_captures_eligible "$@" || fail=1 ;;
captures-deferred) cmd_captures_deferred "$@" || fail=1 ;;
*) usage ;;
esac

exit "$fail"
