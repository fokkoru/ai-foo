#!/usr/bin/env bash
#
# install-codex-agents.sh — install df's Codex subagents into ~/.codex/agents/.
#
# Codex plugins cannot bundle subagents, so this REQUIRED step copies the
# hand-written TOML agents that df's research/plan/iterate skills depend on.
# Runs from a local checkout, or standalone (shallow-clones the repo).
#
set -euo pipefail

REPO="https://github.com/fokkoru/ai-foo"
DEST="${CODEX_HOME:-$HOME/.codex}/agents"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/../plugins/df/codex/agents"

CLEANUP=""
cleanup() { [[ -n "$CLEANUP" ]] && rm -rf "$CLEANUP"; }
trap cleanup EXIT

if [[ ! -d "$SRC" ]]; then
  command -v git >/dev/null || { echo "error: git not found" >&2; exit 1; }
  CLEANUP="$(mktemp -d)"
  git clone --depth 1 "$REPO" "$CLEANUP" >/dev/null 2>&1 \
    || { echo "error: failed to clone $REPO" >&2; exit 1; }
  SRC="$CLEANUP/plugins/df/codex/agents"
fi

[[ -d "$SRC" ]] || { echo "error: could not locate codex/agents TOMLs" >&2; exit 1; }

mkdir -p "$DEST"
cp "$SRC"/*.toml "$DEST"/
echo "Installed $(ls "$SRC"/*.toml | wc -l | tr -d ' ') df subagents into $DEST"
echo "Note: 'web-search-researcher' needs web_search enabled under [tools] in ~/.codex/config.toml"
