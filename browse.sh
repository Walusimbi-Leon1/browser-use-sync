#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# browse.sh — browser-use tab control wrapper
#
# Usage:
#   ./browse.sh tabs                 list all tabs
#   ./browse.sh open <url>           open a new tab
#   ./browse.sh info                 current tab URL + title
#   ./browse.sh switch <url-part>    switch to tab whose URL contains <url-part>
#   ./browse.sh close [url-part]     close current tab (or matching tab)
#   ./browse.sh shot [name]          screenshot current tab to /tmp/bu-shots/
#   ./browse.sh ai "<task>"          AI-driven browsing (needs OPENCODE_API_KEY)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

CMD="${1:-}"
export BU_CDP_URL="${BU_CDP_URL:-$BU_CDP_URL}"

bu() { "$BROWSER_ENV/bin/browser-use" "$@"; }

case "$CMD" in
  tabs)
    bu <<'PY'
for t in list_tabs():
    if t.get("type") in (None, "page"):
        print(f"{t['targetId']}  {t.get('title','')[:50]}  {t.get('url','')}")
PY
    ;;
  open)
    URL="${2:?usage: ./browse.sh open <url>}"
    export BU_URL="$URL"
    bu <<'PY'
import os
new_tab(os.environ["BU_URL"])
wait_for_load()
print("OPENED:", page_info().get("url"))
PY
    ;;
  info)
    bu <<'PY'
info = page_info()
print("URL:", info.get("url"))
print("TITLE:", info.get("title"))
PY
    ;;
  switch)
    PART="${2:?usage: ./browse.sh switch <url-part>}"
    export BU_PART="$PART"
    bu <<'PY'
import os
tabs = list_tabs()
hit = [t for t in tabs if os.environ["BU_PART"] in t.get("url", "")]
if not hit:
    print("NO TAB MATCHES:", os.environ["BU_PART"])
else:
    switch_tab(hit[0]["targetId"])
    print("SWITCHED:", page_info().get("url"))
PY
    ;;
  close)
    PART="${2:-}"
    if [ -n "$PART" ]; then
      export BU_PART="$PART"
      bu <<'PY'
import os
tabs = list_tabs()
hit = [t for t in tabs if os.environ["BU_PART"] in t.get("url", "")]
if not hit:
    print("NO TAB MATCHES:", os.environ["BU_PART"])
else:
    switch_tab(hit[0]["targetId"])
    close_tab()
    print("CLOSED:", os.environ["BU_PART"])
PY
    else
      bu <<'PY'
close_tab()
print("CLOSED current tab")
PY
    fi
    ;;
  shot)
    NAME="${2:-shot}"
    export BU_NAME2="$NAME"
    mkdir -p /tmp/bu-shots
    bu <<'PY'
import os, time
path = f"/tmp/bu-shots/{os.environ['BU_NAME2']}-{int(time.time())}.png"
capture_screenshot(path)
print("SAVED:", path)
PY
    ;;
  ai)
    TASK="${2:?usage: ./browse.sh ai \"<task>\"}"
    if [ -z "$OPENCODE_API_KEY" ]; then
      echo "❌ OPENCODE_API_KEY not set — add it to config.env or export it." >&2
      exit 1
    fi
    export BU_TASK="$TASK"
    export OPENCODE_BASE_URL OPENCODE_MODEL OPENCODE_API_KEY
    bu <<'PY'
import os
from browser_use.agent import Agent
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url=os.environ["OPENCODE_BASE_URL"],
    api_key=os.environ["OPENCODE_API_KEY"],
    model=os.environ["OPENCODE_MODEL"],
)
agent = Agent(task=os.environ["BU_TASK"], llm=llm)
result = agent.run()
print("RESULT:", result)
PY
    ;;
  *)
    echo "usage: ./browse.sh {tabs|open <url>|info|switch <url-part>|close [url-part]|shot [name]|ai \"<task>\"}"
    ;;
esac
