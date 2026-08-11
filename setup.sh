#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# setup.sh — Install browser-use + Google Chrome on a runner
#
# Installs:
#   • Python venv          → browser-use
#   • Google Chrome stable (real Chrome — needed for a real
#     Google profile: login, bookmarks/history sync, cookies)
#   • xvfb                 → virtual display for headed Chrome
#
# Usage:    bash setup.sh        (idempotent, safe to re-run)
# Next:     bash start.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

SUDO=""
[ "$(id -u)" != "0" ] && SUDO="sudo"

START=$(date +%s)

echo "=================================================="
echo "  ☁️  browser-use-sync setup"
echo "  $(date)"
echo "=================================================="

# ── 1. system deps ──────────────────────────────────────
echo ""
echo "[1/4] System packages..."
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq >/dev/null 2>&1 || true
$SUDO apt-get install -y -qq python3 python3-venv python3-pip curl xvfb \
  >/dev/null 2>&1 || true
echo "  ✅ python3 + venv + xvfb ready"

# ── 2. Google Chrome stable (real Chrome, not Chromium) ──
echo ""
echo "[2/4] Google Chrome stable..."
if command -v google-chrome >/dev/null 2>&1; then
  echo "  ✅ google-chrome already installed"
else
  echo "  ⬇️  Downloading google-chrome-stable (~110 MB)..."
  $SUDO curl -sL -o /tmp/google-chrome.deb \
    https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  $SUDO dpkg -i /tmp/google-chrome.deb >/dev/null 2>&1 \
    || $SUDO apt-get install -y -qq -f >/dev/null 2>&1
  rm -f /tmp/google-chrome.deb
  command -v google-chrome >/dev/null 2>&1 || {
    echo "  ❌ google-chrome install failed"; exit 1; }
  echo "  ✅ google-chrome installed"
fi

# ── 3. browser-use venv ─────────────────────────────────
echo ""
echo "[3/4] Python venv ($BROWSER_ENV)..."
if [ ! -x "$BROWSER_ENV/bin/python" ]; then
  rm -rf "$BROWSER_ENV"
  if ! python3 -m venv "$BROWSER_ENV" 2>/dev/null; then
    python3 -m venv --without-pip "$BROWSER_ENV"
    curl -sL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    "$BROWSER_ENV/bin/python" /tmp/get-pip.py -q
  fi
  echo "  ✅ venv created"
else
  echo "  ✅ venv already exists"
fi

if "$BROWSER_ENV/bin/python" -c "import browser_use" >/dev/null 2>&1; then
  echo "  ✅ browser-use already installed"
else
  "$BROWSER_ENV/bin/pip" install --quiet --upgrade pip
  "$BROWSER_ENV/bin/pip" install --quiet browser-use playwright
  echo "  ✅ browser-use installed"
fi

# Playwright Chromium as the harness's own fallback browser (only used
# if no CDP Chrome is reachable). ~120 MB, one-time per runner.
if [ -d "$HOME/.cache/ms-playwright" ]; then
  echo "  ✅ Playwright Chromium already downloaded"
else
  echo "  ⬇️  Downloading Playwright Chromium fallback (~120 MB)..."
  "$BROWSER_ENV/bin/playwright" install --with-deps chromium >/dev/null 2>&1 || true
  echo "  ✅ Playwright Chromium ready"
fi

# ── 4. Verify ───────────────────────────────────────────
echo ""
echo "[4/4] Verification..."
"$BROWSER_ENV/bin/browser-use" --version >/dev/null 2>&1 \
  && echo "  ✅ browser-use CLI ready" \
  || echo "  ⚠️  browser-use CLI not on PATH — check $BROWSER_ENV/bin"
google-chrome --version 2>/dev/null | sed 's/^/  ✅ /' || true

echo ""
echo "=================================================="
echo "  ✅ Setup complete in $(( $(date +%s) - START ))s"
echo "  Next:  bash start.sh"
echo "=================================================="
