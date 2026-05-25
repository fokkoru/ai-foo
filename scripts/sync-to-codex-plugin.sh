#!/usr/bin/env bash
#
# sync-to-codex-plugin.sh
#
# Sync this ai-foo checkout's plugins/df/ → fokkoru/openai-plugins fork,
# landing files at plugins/df/ in the fork, committing on a timestamped sync
# branch, pushing, and opening a PR against openai/plugins:main.
#
# Two-stage workspace: the rsync preview always runs against a clone-of-clone,
# never against the apply checkout. Real runs always print an itemized preview
# and ask for confirmation before applying.
#
# Deterministic: running twice against the same upstream SHA produces PRs with
# identical diffs, so two back-to-back runs verify the tool itself.
#
# Usage:
#   ./scripts/sync-to-codex-plugin.sh                              # full run
#   ./scripts/sync-to-codex-plugin.sh -n                           # dry run
#   ./scripts/sync-to-codex-plugin.sh -y                           # skip confirms
#   ./scripts/sync-to-codex-plugin.sh --local PATH                 # existing fork checkout
#   ./scripts/sync-to-codex-plugin.sh --base BRANCH                # default: main
#   ./scripts/sync-to-codex-plugin.sh --bootstrap                  # create plugins/df/ if missing on base
#
# Bootstrap mode: skips the "plugin must exist on base" requirement and creates
# plugins/df/ when absent on the base branch.
#
# Requires: bash, rsync, git, gh (authenticated), python3.

set -euo pipefail

# =============================================================================
# Config
# =============================================================================

FORK="fokkoru/openai-plugins"
PR_REPO="openai/plugins"
DEFAULT_BASE="main"
DEST_REL="plugins/df"
SOURCE_REL="plugins/df"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="$(cd "$SCRIPT_DIR/.." && pwd)"

# Paths under SOURCE_REL that should NOT land in the embedded plugin.
# Leading "/" anchors to the source root (plugins/df/). Unanchored ".DS_Store"
# matches at any depth — Finder creates them everywhere.
EXCLUDES=(
  "/.claude-plugin/"
  "/.claude/"
  "/agents/"
  "/commands/"
  "/codex/"
  ".DS_Store"
)

# =============================================================================
# Helpers
# =============================================================================

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '/^# Usage:/,/^# Requires:/s/^# \{0,1\}//p' "$0"
  exit "${1:-0}"
}

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  read -rp "$1 [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

IGNORED_DIR_EXCLUDES=()

path_has_directory_exclude() {
  local path="$1"
  local dir
  [[ ${#IGNORED_DIR_EXCLUDES[@]} -eq 0 ]] && return 1
  for dir in "${IGNORED_DIR_EXCLUDES[@]}"; do
    [[ "$path" == "$dir"* ]] && return 0
  done
  return 1
}

# Returns success if an ignored directory contains tracked files (so we should
# NOT exclude it) — guard against accidentally dropping tracked content.
ignored_directory_has_tracked_descendants() {
  local rel="$1"
  [[ -n "$(git -C "$UPSTREAM" ls-files --cached -- "$SOURCE_REL/$rel/")" ]]
}

# git ls-files returns paths relative to UPSTREAM root; we strip the
# SOURCE_REL/ prefix so rsync (which sees paths relative to its source root)
# matches them.
strip_source_prefix() {
  local path="$1"
  printf '%s' "${path#"$SOURCE_REL"/}"
}

append_git_ignored_directory_excludes() {
  local path
  local rel
  while IFS= read -r -d '' path; do
    [[ "$path" == */ ]] || continue
    [[ "$path" == "$SOURCE_REL/"* ]] || continue
    rel="$(strip_source_prefix "${path%/}")"
    if ! ignored_directory_has_tracked_descendants "$rel"; then
      IGNORED_DIR_EXCLUDES+=("$rel/")
      RSYNC_ARGS+=(--exclude="/$rel/")
    fi
  done < <(git -C "$UPSTREAM" ls-files --others --ignored --exclude-standard --directory -z -- "$SOURCE_REL")
}

append_git_ignored_file_excludes() {
  local path
  local rel
  while IFS= read -r -d '' path; do
    [[ "$path" == "$SOURCE_REL/"* ]] || continue
    rel="$(strip_source_prefix "$path")"
    path_has_directory_exclude "$rel" && continue
    RSYNC_ARGS+=(--exclude="/$rel")
  done < <(git -C "$UPSTREAM" ls-files --others --ignored --exclude-standard -z -- "$SOURCE_REL")
}

# Copy any */agents/openai.yaml files from the destination plugin into the
# source overlay so the rsync apply preserves OpenAI-owned marketplace metadata.
copy_preserved_destination_metadata() {
  local destination="$1"
  local source="$2"
  local path
  local rel
  [[ -d "$destination/skills" ]] || return 0
  while IFS= read -r -d '' path; do
    rel="${path#"$destination"/}"
    mkdir -p "$source/$(dirname "$rel")"
    cp -p "$path" "$source/$rel"
  done < <(find "$destination/skills" -path '*/agents/openai.yaml' -type f -print0)
}

# =============================================================================
# Args
# =============================================================================

BASE="$DEFAULT_BASE"
DRY_RUN=0
ASSUME_YES=0
LOCAL_CHECKOUT=""
BOOTSTRAP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)  DRY_RUN=1; shift ;;
    -y|--yes)      ASSUME_YES=1; shift ;;
    --local)       LOCAL_CHECKOUT="${2:-}"; [[ -z "$LOCAL_CHECKOUT" ]] && die "--local requires a path"; shift 2 ;;
    --base)        BASE="${2:-}"; [[ -z "$BASE" ]] && die "--base requires an argument"; shift 2 ;;
    --bootstrap)   BOOTSTRAP=1; shift ;;
    -h|--help)     usage 0 ;;
    *)             die "unknown arg: $1 (try --help)" ;;
  esac
done

# =============================================================================
# Preflight
# =============================================================================

command -v rsync   >/dev/null || die "rsync not found in PATH"
command -v git     >/dev/null || die "git not found in PATH"
command -v gh      >/dev/null || die "gh not found — install GitHub CLI"
command -v python3 >/dev/null || die "python3 not found in PATH"

gh auth status >/dev/null 2>&1 || die "gh not authenticated — run 'gh auth login'"

[[ -d "$UPSTREAM/.git" ]] || die "upstream '$UPSTREAM' is not a git checkout"
[[ -f "$UPSTREAM/$SOURCE_REL/.codex-plugin/plugin.json" ]] \
  || die "committed Codex manifest missing at $UPSTREAM/$SOURCE_REL/.codex-plugin/plugin.json"

UPSTREAM_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' \
  "$UPSTREAM/$SOURCE_REL/.codex-plugin/plugin.json")"
[[ -n "$UPSTREAM_VERSION" ]] || die "could not read 'version' from committed Codex manifest"

UPSTREAM_BRANCH="$(git -C "$UPSTREAM" rev-parse --abbrev-ref HEAD)"
UPSTREAM_SHA="$(git -C "$UPSTREAM" rev-parse HEAD)"
UPSTREAM_SHORT="$(git -C "$UPSTREAM" rev-parse --short HEAD)"

if [[ "$UPSTREAM_BRANCH" != "main" ]]; then
  printf 'WARNING: upstream is on "%s", not "main"\n' "$UPSTREAM_BRANCH" >&2
  confirm "Sync from '$UPSTREAM_BRANCH' anyway?" || exit 1
fi

UPSTREAM_STATUS="$(git -C "$UPSTREAM" status --porcelain)"
if [[ -n "$UPSTREAM_STATUS" ]]; then
  printf 'WARNING: upstream has uncommitted changes:\n%s\n' "$UPSTREAM_STATUS" | sed 's/^/  /' >&2
  printf 'Sync will use working-tree state, not HEAD (%s).\n' "$UPSTREAM_SHORT" >&2
  confirm "Continue anyway?" || exit 1
fi

# =============================================================================
# Workspace (clone fork, or use --local)
# =============================================================================

CLEANUP_DIR=""
cleanup() { [[ -n "$CLEANUP_DIR" ]] && rm -rf "$CLEANUP_DIR"; }
trap cleanup EXIT

if [[ -n "$LOCAL_CHECKOUT" ]]; then
  DEST_REPO="$(cd "$LOCAL_CHECKOUT" 2>/dev/null && pwd)" \
    || die "--local path '$LOCAL_CHECKOUT' does not exist"
  [[ -d "$DEST_REPO/.git" ]] || die "--local path '$DEST_REPO' is not a git checkout"
else
  echo "Cloning $FORK..."
  CLEANUP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sync-df-codex.XXXXXX")"
  DEST_REPO="$CLEANUP_DIR/fork"
  gh repo clone "$FORK" "$DEST_REPO" -- --quiet >/dev/null
fi

DEST="$DEST_REPO/$DEST_REL"
PREVIEW_REPO="$DEST_REPO"
PREVIEW_DEST="$DEST"
SYNC_SOURCE=""

# =============================================================================
# Workspace helpers
# =============================================================================

overlay_destination_paths() {
  local repo="$1"
  local path
  local source_path
  local preview_path
  while IFS= read -r -d '' path; do
    source_path="$repo/$path"
    preview_path="$PREVIEW_REPO/$path"
    if [[ -e "$source_path" ]]; then
      mkdir -p "$(dirname "$preview_path")"
      cp -R "$source_path" "$preview_path"
    else
      rm -rf "$preview_path"
    fi
  done
}

copy_local_destination_overlay() {
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" diff --name-only -z -- "$DEST_REL"
  )
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" diff --cached --name-only -z -- "$DEST_REL"
  )
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" ls-files --others --exclude-standard -z -- "$DEST_REL"
  )
  overlay_destination_paths "$DEST_REPO" < <(
    git -C "$DEST_REPO" ls-files --others --ignored --exclude-standard -z -- "$DEST_REL"
  )
}

local_checkout_has_uncommitted_destination_changes() {
  [[ -n "$(git -C "$DEST_REPO" status --porcelain=1 --untracked-files=all --ignored=matching -- "$DEST_REL")" ]]
}

prepare_preview_checkout() {
  if [[ -n "$LOCAL_CHECKOUT" ]]; then
    [[ -n "$CLEANUP_DIR" ]] || CLEANUP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sync-df-codex.XXXXXX")"
    PREVIEW_REPO="$CLEANUP_DIR/preview"
    git clone -q --no-local "$DEST_REPO" "$PREVIEW_REPO"
    PREVIEW_DEST="$PREVIEW_REPO/$DEST_REL"
  fi

  git -C "$PREVIEW_REPO" checkout -q "$BASE" 2>/dev/null \
    || die "base branch '$BASE' doesn't exist in $FORK"

  if [[ -n "$LOCAL_CHECKOUT" ]]; then
    copy_local_destination_overlay
  fi

  if [[ $BOOTSTRAP -eq 1 ]]; then
    if [[ -d "$PREVIEW_DEST" ]]; then
      die "base '$BASE' already has '$DEST_REL/' — drop --bootstrap"
    fi
  else
    [[ -d "$PREVIEW_DEST" ]] || die "base '$BASE' has no '$DEST_REL/' — use --bootstrap, or pass --base <branch>"
  fi
}

prepare_apply_checkout() {
  git -C "$DEST_REPO" checkout -q "$BASE" 2>/dev/null \
    || die "base branch '$BASE' doesn't exist in $FORK"
  if [[ $BOOTSTRAP -ne 1 ]]; then
    [[ -d "$DEST" ]] || die "base '$BASE' has no '$DEST_REL/' — use --bootstrap, or pass --base <branch>"
  fi
}

apply_to_preview_checkout() {
  [[ $BOOTSTRAP -eq 1 ]] && mkdir -p "$PREVIEW_DEST"
  rsync "${RSYNC_ARGS[@]}" "$SYNC_SOURCE/" "$PREVIEW_DEST/"
}

preview_checkout_has_changes() {
  [[ -n "$(git -C "$PREVIEW_REPO" status --porcelain "$DEST_REL")" ]]
}

prepare_preview_checkout

TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
if [[ $BOOTSTRAP -eq 1 ]]; then
  SYNC_BRANCH="bootstrap/df-v${UPSTREAM_VERSION}-${UPSTREAM_SHORT}-${TIMESTAMP}"
else
  SYNC_BRANCH="sync/df-v${UPSTREAM_VERSION}-${UPSTREAM_SHORT}-${TIMESTAMP}"
fi

# =============================================================================
# Build rsync args
# =============================================================================

RSYNC_ARGS=(-a --delete --delete-excluded)
for pat in "${EXCLUDES[@]}"; do
  RSYNC_ARGS+=(--exclude="$pat")
done
append_git_ignored_directory_excludes
append_git_ignored_file_excludes

# =============================================================================
# Source overlay (rsync upstream → temp dir, then layer preserved metadata)
# =============================================================================

prepare_sync_source() {
  local destination="$1"
  [[ -n "$CLEANUP_DIR" ]] || CLEANUP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sync-df-codex.XXXXXX")"
  SYNC_SOURCE="$CLEANUP_DIR/source-overlay"
  rm -rf "$SYNC_SOURCE"
  mkdir -p "$SYNC_SOURCE"
  rsync "${RSYNC_ARGS[@]}" "$UPSTREAM/$SOURCE_REL/" "$SYNC_SOURCE/" >/dev/null
  copy_preserved_destination_metadata "$destination" "$SYNC_SOURCE"
}

prepare_sync_source "$PREVIEW_DEST"

# =============================================================================
# Preview (always shown)
# =============================================================================

echo ""
echo "Upstream: $UPSTREAM ($UPSTREAM_BRANCH @ $UPSTREAM_SHORT)"
echo "Version:  $UPSTREAM_VERSION"
echo "Fork:     $FORK"
echo "Base:     $BASE"
echo "Branch:   $SYNC_BRANCH"
[[ $BOOTSTRAP -eq 1 ]] && echo "Mode:     BOOTSTRAP"
echo ""
echo "=== Preview (rsync --dry-run) ==="
rsync "${RSYNC_ARGS[@]}" --dry-run --itemize-changes "$SYNC_SOURCE/" "$PREVIEW_DEST/"
echo "=== End preview ==="
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run only. Nothing was changed or pushed."
  exit 0
fi

confirm "Apply changes, push branch, and open PR?" || { echo "Aborted."; exit 1; }

# =============================================================================
# Apply
# =============================================================================

if [[ -n "$LOCAL_CHECKOUT" ]]; then
  if local_checkout_has_uncommitted_destination_changes; then
    die "local checkout has uncommitted changes under '$DEST_REL' — commit, stash, or discard them before syncing"
  fi
  apply_to_preview_checkout
  if ! preview_checkout_has_changes; then
    echo "No changes — embedded plugin was already in sync with upstream $UPSTREAM_SHORT (v$UPSTREAM_VERSION)."
    exit 0
  fi
fi

prepare_apply_checkout
cd "$DEST_REPO"
git checkout -q -b "$SYNC_BRANCH"
[[ $BOOTSTRAP -eq 1 ]] && mkdir -p "$DEST"
rsync "${RSYNC_ARGS[@]}" "$SYNC_SOURCE/" "$DEST/"

if [[ -z "$(git status --porcelain "$DEST_REL")" ]]; then
  echo "No changes — embedded plugin was already in sync with upstream $UPSTREAM_SHORT (v$UPSTREAM_VERSION)."
  exit 0
fi

# =============================================================================
# Commit, push, open PR
# =============================================================================

git add "$DEST_REL"

if [[ $BOOTSTRAP -eq 1 ]]; then
  COMMIT_TITLE="bootstrap df v$UPSTREAM_VERSION from upstream main @ $UPSTREAM_SHORT"
else
  COMMIT_TITLE="sync df v$UPSTREAM_VERSION from upstream main @ $UPSTREAM_SHORT"
fi

PR_BODY="Automated sync from \`fokkoru/ai-foo\` upstream \`main\` @ [\`$UPSTREAM_SHORT\`](https://github.com/fokkoru/ai-foo/commit/$UPSTREAM_SHA) (v$UPSTREAM_VERSION).

Copies the tracked plugin files from \`$SOURCE_REL/\` upstream, including the committed Codex manifest \`.codex-plugin/plugin.json\` and the skills bundle.

Run via: \`scripts/sync-to-codex-plugin.sh\`

Re-running the sync tool against the same upstream SHA should produce a PR with an identical diff — use that to verify the tool itself is behaving."

git -c user.name="$(git -C "$UPSTREAM" config user.name)" \
    -c user.email="$(git -C "$UPSTREAM" config user.email)" \
    commit --quiet -m "$COMMIT_TITLE

Automated sync via scripts/sync-to-codex-plugin.sh
Upstream: https://github.com/fokkoru/ai-foo/commit/$UPSTREAM_SHA
Branch:   $SYNC_BRANCH"

if [[ -n "$LOCAL_CHECKOUT" ]]; then
  echo "Local-only mode: commit prepared on branch $SYNC_BRANCH in $DEST_REPO (not pushed)"
  exit 0
fi

echo "Pushing $SYNC_BRANCH to $FORK..."
git push -u origin "$SYNC_BRANCH" --quiet

echo "Opening PR..."
PR_URL="$(gh pr create \
  --repo "$PR_REPO" \
  --base "$BASE" \
  --head "${FORK%%/*}:$SYNC_BRANCH" \
  --title "$COMMIT_TITLE" \
  --body "$PR_BODY")"

echo ""
echo "PR opened: $PR_URL"
