#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# profile.sh — the profile sync engine
#
# Stores the Chrome profile ($CHROME_PROFILE) as a tarball in
# a GitHub Release (PROFILE_RELEASE) so it survives between
# runs — every GitHub Actions runner is ephemeral, so this
# release IS the persistent home of the synced profile.
#
# Usage:
#   bash profile.sh download   # fetch profile.tar.gz → /tmp, unpack
#   bash profile.sh upload     # pack $CHROME_PROFILE → release (clobber)
#   bash profile.sh pack       # just create /tmp/profile.tar.gz
#   bash profile.sh unpack     # just unpack /tmp/profile.tar.gz
#   bash profile.sh info       # show stored size/date
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

GH="gh"
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
    echo "⬇️  Downloading $PROFILE_ASSET from release '$PROFILE_RELEASE' ..."
    if ! gh release download "$PROFILE_RELEASE" -p "$PROFILE_ASSET" --clobber -D /tmp 2>/dev/null; then
      echo "  ⚠️  No stored profile yet (release missing) — will use a fresh profile."
      exit 2
    fi
    du -h "$TARBALL" | sed 's/^/  ✅ /'
    bash "$SCRIPT_DIR/profile.sh" unpack
    ;;

  upload)
    echo "⬆️  Uploading $TARBALL to release '$PROFILE_RELEASE' ..."
    gh release create "$PROFILE_RELEASE" --title "Synced browser profile" \
      --notes "Packed Chrome profile for browser-use. Auto-updated by workflows." \
      2>/dev/null || true
    gh release upload "$PROFILE_RELEASE" "$TARBALL" --clobber
    echo "  ✅ profile stored (survives until the next run)"
    ;;

  info)
    gh release view "$PROFILE_RELEASE" 2>/dev/null | head -12 || echo "no release yet"
    ;;

  *)
    echo "usage: $0 download|upload|pack|unpack|info"
    exit 1
    ;;
esac
