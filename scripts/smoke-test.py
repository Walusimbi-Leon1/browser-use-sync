# Smoke test for browser-use-sync.
# Run via:  "$BROWSER_ENV/bin/browser-use" < scripts/smoke-test.py
# (the browser-use harness reads the script from stdin and
#  pre-imports its helpers: new_tab, wait_for_load, page_info,
#  capture_screenshot, ...)
#
# Verifies:
#   1. Google login state (session cookies in the profile)
#   2. Bookmarks (Default/Bookmarks JSON)
#   3. History (Default/History SQLite — recent URLs)
#   4. Live browser: opens myaccount.google.com, confirms the
#      signed-in account, takes a screenshot.
#
# Prints a machine-readable summary line: SMOKE: <json>

import json
import os
import shutil
import sqlite3
import time

PROFILE = os.environ.get("CHROME_PROFILE", "/tmp/bu-profile")
DEFAULT = os.path.join(PROFILE, "Default")
results = {}

# ── 1. Login state: Google session cookies ────────────────
cookies_db = os.path.join(DEFAULT, "Network", "Cookies")
google_auth_cookies = []
if os.path.exists(cookies_db):
    try:
        tmp = "/tmp/cookies-copy.db"
        shutil.copy(cookies_db, tmp)
        con = sqlite3.connect(tmp)
        rows = con.execute(
            "SELECT name, host_key FROM cookies WHERE host_key LIKE '%google.com'"
        ).fetchall()
        con.close()
        names = {r[0] for r in rows}
        # SID / HSID / SSID / SAPISID are the auth cookies.
        for n in ("SID", "HSID", "SSID", "SAPISID", "__Secure-1PSID", "OTZ"):
            if n in names:
                google_auth_cookies.append(n)
    except Exception as e:
        results["cookie_error"] = str(e)
results["google_auth_cookies"] = google_auth_cookies
results["logged_in"] = len(google_auth_cookies) >= 3

# ── 2. Bookmarks ──────────────────────────────────────────
bm_path = os.path.join(DEFAULT, "Bookmarks")
bm_count = 0
bm_folders = []
if os.path.exists(bm_path):
    try:
        bm = json.load(open(bm_path, encoding="utf-8"))
        roots = bm.get("roots", {})

        def walk(node, depth=0):
            global bm_count
            if node.get("type") == "url":
                bm_count += 1
            elif node.get("type") == "folder":
                bm_folders.append(node.get("name", "?"))
                for c in node.get("children", []):
                    walk(c, depth + 1)

        for root in roots.values():
            walk(root)
    except Exception as e:
        results["bookmark_error"] = str(e)
results["bookmarks"] = bm_count
results["bookmark_folders"] = bm_folders[:15]

# ── 3. History (recent URLs) ──────────────────────────────
hist_path = os.path.join(DEFAULT, "History")
recent = []
if os.path.exists(hist_path):
    try:
        tmp = "/tmp/history-copy.db"
        shutil.copy(hist_path, tmp)
        con = sqlite3.connect(tmp)
        rows = con.execute(
            "SELECT url, title, last_visit_time FROM urls "
            "ORDER BY last_visit_time DESC LIMIT 8"
        ).fetchall()
        con.close()
        for url, title, t in rows:
            # Chrome timestamp: microseconds since 1601-01-01
            ms = (t - 11644473600000000) / 1000.0
            recent.append({"url": url[:80], "title": (title or "")[:40]})
    except Exception as e:
        results["history_error"] = str(e)
results["recent_history"] = recent

# ── 4. Live browser: confirm the signed-in account ────────
try:
    new_tab("https://myaccount.google.com/")
    wait_for_load()
    time.sleep(3)
    info = page_info() or {}
    results["account_page_title"] = info.get("title", "")
    # Grab the page's visible text to confirm the account email.
    try:
        text = js("document.body.innerText")
        results["page_has_email"] = "walusimbileon2@gmail.com" in (text or "")
    except Exception:
        results["page_has_email"] = None
    os.makedirs("/tmp/bu-shots", exist_ok=True)
    shot_path = "/tmp/bu-shots/smoke-account.png"
    capture_screenshot(shot_path)
    results["screenshot"] = shot_path
except Exception as e:
    results["browser_error"] = str(e)

print("SMOKE:", json.dumps(results, indent=2))
