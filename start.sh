#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# start.sh — Start the automation Chrome (with the synced
# profile) + Xvfb for browser-use
#
# browser-use controls a real Google Chrome over CDP. This
# starts a dedicated Chrome (headed, on a virtual display)
# using $CHROME_PROFILE — which is either the synced profile
# (restored by profile.sh) or a fresh one.
#
# Usage:    bash start.sh
# Next:     ./browse.sh tabs   (or the full browser-use CLI)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

SUDO=""
[ "$(id -u)" != "0" ] && SUDO="sudo"

echo "=================================================="
echo "  ☁️  browser-use-sync start"
echo "  $(date)"
echo "=================================================="

# ── Stop any previous instance of OUR stack ─────────────
pkill -f "Xvfb :99 " 2>/dev/null || true
pkill -f "google-chrome.*--user-data-dir=$CHROME_PROFILE" 2>/dev/null || true
sleep 1

# ── 1. Virtual display ──────────────────────────────────
echo "⏳ Starting Xvfb ($BROWSER_SCREEN)..."
setsid nohup $SUDO Xvfb :99 -screen 0 ${BROWSER_SCREEN}x24 -ac \
  > /tmp/bu-xvfb.log 2>&1 < /dev/null &
sleep 2

# ── 2. Chrome binary (real Chrome first) ─────────────────
CHROME_BIN=""
if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN=$(command -v google-chrome)
elif [ -x "$HOME/.cache/ms-playwright/chromium"*/chrome-linux/chrome ]; then
  CHROME_BIN=$(ls "$HOME"/.cache/ms-playwright/chromium*/chrome-linux/chrome | head -1)
else
  echo "  ⬇️  Installing Playwright Chromium (fallback browser)..."
  "$BROWSER_ENV/bin/playwright" install --with-deps chromium
  CHROME_BIN=$(ls "$HOME"/.cache/ms-playwright/chromium*/chrome-linux/chrome | head -1)
fi
echo "  ✅ Chrome: $CHROME_BIN"

# ── 3. Dedicated automation Chrome with CDP ─────────────
echo "🚀 Starting Chrome with CDP on port $CDP_PORT..."
mkdir -p "$CHROME_PROFILE"
# --password-store=basic + --disable-features=... keep the
# profile's cookies decryptable across runner machines
# (no keyring on runners → Chrome uses the portable key).
DISPLAY=:99 setsid nohup "$CHROME_BIN" \
  --no-sandbox --disable-gpu --disable-software-rasterizer \
  --no-first-run --no-default-browser-check --disable-dev-shm-usage \
  --password-store=basic \
  --remote-debugging-port=$CDP_PORT \
  --remote-allow-origins=* \
  --user-data-dir="$CHROME_PROFILE" \
  about:blank > /tmp/bu-chrome.log 2>&1 < /dev/null &

# ── 4. Wait for CDP ─────────────────────────────────────
echo "⏳ Waiting for CDP on $BU_CDP_URL ..."
UP=0
for _ in $(seq 1 30); do
  if curl -s -o /dev/null --max-time 2 "$BU_CDP_URL/json/version" 2>/dev/null; then
    UP=1; break
  fi
  sleep 1
done
if [ "$UP" = 0 ]; then
  echo "⚠️  CDP not responding — check:"
  echo "    tail /tmp/bu-chrome.log /tmp/bu-xvfb.log"
  exit 1
fi

echo "✅ Chrome ready — browser-use is live."
echo ""
echo "Profile: $CHROME_PROFILE"
echo ""
echo "Usage:"
echo "  ./browse.sh tabs                  list tabs"
echo "  ./browse.sh open <url>            open a new tab"
echo "  ./browse.sh info                  current tab info"
echo "  ./browse.sh shot [name]           screenshot current tab"
echo "  ./browse.sh ai \"<task>\"           AI-driven browsing (needs OPENCODE_API_KEY)"
echo "  browser-use <<'PY' ... PY         full CLI (see README)"
echo ""
echo "🛑 Stop later with:  bash stop.sh"
