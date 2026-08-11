#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# profile.sh — the profile sync engine
#
# Stores the Chrome profile ($CHROME_PROFILE) as a tarball in a
# GitHub Release of the PRIVATE store repo ($PROFILE_REPO) so it
# survives between runs — every GitHub Actions runner is
# ephemeral, so that release IS the persistent home of the
# synced profile. This public repo never holds the profile.
#
# Auth: requires GH_TOKEN (set from the GH_PUSH_TOKEN repo
# secret in workflows). Never commit the token.
#
# Usage:
#   bash profile.sh download   # fetch profile.tar.gz from PRIVATE repo
#   bash profile.sh upload     # pack $CHROME_PROFILE → PRIVATE repo (clobber)
#   bash profile.sh pack       # just create /tmp/profile.tar.gz
#   bash profile.sh unpack     # just unpack /tmp/profile.tar.gz
#   bash profile.sh info       # show stored size/date (private repo)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

: "${GH_TOKEN:?GH_TOKEN is required — set the GH_PUSH_TOKEN secret on the repo}"
TARBALL="/tmp/$PROFILE_ASSET"

cmd="${1:-}"

case "$cmd" in
  pack)
    echo "📦 Packing $CHROME_PROFILE → $TARBALL ..."
    # Chrome must not be running while packing (flush caches first).
    pkill -f "google-chrome.*--user-data-dir=$CHROME_PROFILE" 2>/dev/null || true
    sleep 1
    tar -C "$(dirname "$CHROME_PROFILE")" -czf "$TARBALL" "$(basename "$CHROME_PROFILE")"
    du -h "$TARBALL" | sed 's/^/  ✅ /'
    ;;

  unpack)
    echo "📂 Unpacking $TARBALL → $CHROME_PROFILE ..."
    mkdir -p "$(dirname "$CHROME_PROFILE")"
    tar -C "$(dirname "$CHROME_PROFILE")" -xzf "$TARBALL"
    echo "  ✅ profile ready at $CHROME_PROFILE"
    ;;

  download)
    echo "⬇️  Downloading $PROFILE_ASSET from $PROFILE_REPO release '$PROFILE_RELEASE' ..."
    if ! gh release download "$PROFILE_RELEASE" --repo "$PROFILE_REPO" \
        -p "$PROFILE_ASSET" --clobber -D /tmp 2>/dev/null; then
      echo "  ⚠️  No stored profile yet (release missing) — will use a fresh profile."
      exit 2
    fi
    du -h "$TARBALL" | sed 's/^/  ✅ /'
    bash "$SCRIPT_DIR/profile.sh" unpack
    ;;

  upload)
    echo "⬆️  Uploading $TARBALL to $PROFILE_REPO release '$PROFILE_RELEASE' ..."
    gh release create "$PROFILE_RELEASE" --repo "$PROFILE_REPO" \
      --title "Synced browser profile" \
      --notes "Packed Chrome profile for browser-use-sync. PRIVATE — auto-updated by workflows." \
      >/dev/null 2>&1 || true
    gh release upload "$PROFILE_RELEASE" "$TARBALL" --repo "$PROFILE_REPO" --clobber
    echo "  ✅ profile stored in the PRIVATE repo (survives until the next run)"
    ;;

  info)
    gh release view "$PROFILE_RELEASE" --repo "$PROFILE_REPO" 2>/dev/null | head -12 \
      || echo "no release in $PROFILE_REPO yet"
    ;;

  *)
    echo "usage: $0 download|upload|pack|unpack|info"
    exit 1
    ;;
esac
