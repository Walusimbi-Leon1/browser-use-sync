#!/usr/bin/env bash
# provision-watch.sh — waits for Leon to finish Google login + sync
# in the noVNC session, then packs the profile.
#
# Signals that "we're done":
#   1. A bookmark titled SYNC-DONE exists (Leon creates it via
#      Ctrl+D in the browser — unambiguous human signal), OR
#   2. Hard timeout (TIMEOUT_MIN) → pack whatever exists anyway.
#
# NOTE: "logged in" alone is NOT a completion signal — the Sync Data
# dir appears the moment you sign in, so it used to kill the run right
# after login, before sync/bookmark steps. Login is logged info only.
#
# Usage: bash scripts/provision-watch.sh
# Env:   TIMEOUT_MIN (default 25)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # repo root (this script lives in scripts/)
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

TIMEOUT_MIN="${TIMEOUT_MIN:-25}"
DEFAULT_DIR="$CHROME_PROFILE/Default"
DEADLINE=$(( $(date +%s) + TIMEOUT_MIN * 60 ))

echo "👀 Watching for login completion (up to ${TIMEOUT_MIN} min)…"
echo "   Signal: SYNC-DONE bookmark (or timeout). Login alone won't stop the run."

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  DONE=0
  REASON=""

  # Signal 1: SYNC-DONE bookmark
  if [ -f "$DEFAULT_DIR/Bookmarks" ]; then
    if grep -q '"SYNC-DONE"' "$DEFAULT_DIR/Bookmarks" 2>/dev/null; then
      DONE=1; REASON="SYNC-DONE bookmark found"
    fi
  fi

  # Informational only: login detected → tell the user to keep going.
  if [ -f "$DEFAULT_DIR/Preferences" ]; then
    if grep -q '"account_info"' "$DEFAULT_DIR/Preferences" 2>/dev/null \
       && [ -d "$DEFAULT_DIR/Sync Data" ]; then
      echo "ℹ️  Login detected — keep going: turn on sync and create the SYNC-DONE bookmark (Ctrl+D → rename)."
    fi
  fi

  if [ "$DONE" = 1 ]; then
    echo "✅ $REASON — packing profile."
    bash "$SCRIPT_DIR/profile.sh" pack
    exit 0
  fi

  sleep 20
done

echo "⏰ Timeout reached — packing whatever the profile has."
bash "$SCRIPT_DIR/profile.sh" pack
exit 0
