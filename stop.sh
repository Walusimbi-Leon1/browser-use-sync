#!/usr/bin/env bash
set -euo pipefail

# stop.sh — Stop the automation Chrome + Xvfb used by browser-use.
# Only kills OUR processes (never the OpenClaw gateway or its tunnel).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

echo "🛑 Stopping browser-use browser..."

pkill -f "Xvfb :99 " 2>/dev/null || true
pkill -f "google-chrome.*--user-data-dir=$CHROME_PROFILE" 2>/dev/null || true
pkill -f "chrome.*--user-data-dir=$CHROME_PROFILE" 2>/dev/null || true

echo "✅ Stopped. Restart with:  bash start.sh"
