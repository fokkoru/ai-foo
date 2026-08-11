#!/usr/bin/env bash
# Conformance, reachability, provenance, and raw-source immutability checks for
# a knowledge base compiled by kb:compile.
#
#   snapshot [raw-root]            hash every raw source and remember the result
#   verify-sources [raw-root]      prove the raw layer did not change during a run
#   check [docs-root] [raw-root]   every conformance rule over the compiled tree
#
# Each mode exits 0 on success and 1 on any failure, printing one
# RULE(subject): detail line per failure.
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

MANIFEST="${TMPDIR:-/tmp}/df-compile-sources.sha256"
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
       $self verify-sources [raw-root]
       $self check [docs-root] [raw-root]
EOF
  exit 2
}

report() {
  echo "$1($2): $3"
  fail=1
}

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
    awk -v h="$frag" -v lvl="$level" '
      !on && $0==h {on=1; print; next}
      on {
        if ($0 ~ /^#+[[:space:]]/) {
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
  awk '
    /^[[:space:]]*(```|~~~)/ {infence = !infence; next}
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
    printf '%s  %s\n' "$h" "$f"
  done
}

cmd_snapshot() {
  local raw="${1:-thoughts}"
  if [ ! -d "$raw" ]; then
    report NO-RAW-ROOT snapshot "$raw is not a directory"
    return 1
  fi
  # Every I/O failure below is reported rather than left to set -e. A function
  # invoked as the left operand of || runs with errexit ignored for its whole
  # body, so a failed redirect here would otherwise fall through to the success
  # line and the script would exit 0 having recorded nothing.
  hash_tree "$raw" >"$MANIFEST" || {
    report SNAPSHOT-FAILED snapshot "could not hash every file under $raw, or could not write the manifest to $MANIFEST"
    return 1
  }
  echo "snapshot: $(line_count "$MANIFEST") files under $raw recorded in $MANIFEST"
}

cmd_verify_sources() {
  local raw="${1:-thoughts}" now findings
  if [ ! -d "$raw" ]; then
    report NO-RAW-ROOT verify-sources "$raw is not a directory"
    return 1
  fi
  if [ ! -f "$MANIFEST" ]; then
    report NO-SNAPSHOT verify-sources \
      "no manifest at $MANIFEST — a run that never snapshotted cannot claim it left the raw layer alone"
    return 1
  fi

  now="$WORKDIR/now"
  findings="$WORKDIR/findings"
  hash_tree "$raw" >"$now" || {
    report VERIFY-FAILED verify-sources "could not hash the tree under $raw"
    return 1
  }

  awk -F'  ' '
    NR==FNR {old[$2] = $1; next}
    {new[$2] = $1}
    END {
      for (p in new) {
        if (!(p in old)) print "SOURCE-ADDED(" p "): not present when the run started"
        else if (old[p] != new[p]) print "SOURCE-CHANGED(" p "): content differs from the snapshot"
      }
      for (p in old) if (!(p in new)) print "SOURCE-REMOVED(" p "): present when the run started, gone now"
    }' "$MANIFEST" "$now" | LC_ALL=C sort >"$findings" || {
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
  local page="$1" recs idx resource fragment recorded retired text actual total end
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

cmd_check() {
  local docs="${1:-docs}" root_index page base
  # The second argument is the raw root, accepted so every mode takes the same
  # pair. No rule here resolves against it: a sources[].resource may cite code
  # outside the raw layer, so resources resolve against the working directory.
  : "${2:-thoughts}"

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

  while IFS= read -r page; do
    [ -n "$page" ] || continue
    check_page_frontmatter "$page" "$root_index"
    check_links "$page"
    check_sources "$page"
    base=$(basename "$page")
    if [ "$base" = "log.md" ]; then
      check_log "$page"
    fi
  done <"$WORKDIR/pages"

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
*) usage ;;
esac

exit "$fail"
