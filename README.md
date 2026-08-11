# ☁️ browser-use-sync — Cloud Chrome for Leon

A **persistent, synced Chrome** that runs on GitHub Actions and is controlled
by [browser-use](https://github.com/browser-use/browser-use). It carries
**your real Google profile** — signed in as `walusimbileon2@gmail.com` — with
your bookmarks, history, and sync data, and it survives between runs.

This is the base for what comes next (e.g. posting Instagram reels with your
accounts).

---

## How it works

| Piece | What it does |
|---|---|
| `setup.sh` | Installs browser-use + **Google Chrome stable** + Xvfb (idempotent) |
| `start.sh` | Starts Xvfb + Chrome with `$CHROME_PROFILE` on CDP :9222 |
| `browse.sh` | Tab control wrapper: `tabs / open / info / switch / close / shot / ai` |
| `profile.sh` | The **sync engine** — packs/unpacks the profile to/from a GitHub Release (`browser-profile`) |
| `.github/workflows/provision.yml` | **One-time:** live noVNC session → you log into Google + enable sync → profile is stored |
| `.github/workflows/browse.yml` | **Every run:** downloads stored profile → Chrome with it → browser-use → saves profile back |

GitHub Actions runners are **ephemeral** — a fresh machine every run. The
GitHub Release is the persistent home of your profile. `browse.yml` downloads
it at the start and re-uploads it at the end, so logins, cookies, and sync
state carry across runs.

---

## Step 1 — Provision (one-time, ~10 minutes)

Run **Provision — Google login + sync** (Actions → Run workflow).

You get a **tunnel URL** in the job logs + summary. Open it in your browser —
you'll see the runner's live desktop. Then:

1. Go to `accounts.google.com` → sign in as **walusimbileon2@gmail.com**.
   (Solve any captcha / 2FA here — this is the one-time gate. Google
   deliberately blocks fully-automated logins, so we do it once, visually.)
2. `chrome://settings/syncSetup` → **Turn on sync** → **Sync everything**
   (bookmarks, history, open tabs, passwords, settings).
3. Create a bookmark named **`SYNC-DONE`** (Ctrl+D → rename).
   The job detects it, packs the profile, and stores it in the release.

Done. Every future run starts from that profile.

## Step 2 — Use it

Run **Browse — synced profile session** (manual, or add a cron later).
It restores your profile, opens Chrome, runs the smoke test
(bookmarks count, recent history, login cookies, live account page +
screenshot), and saves the profile back. Add real tasks after the smoke
step — e.g. an Instagram reel poster (coming next).

### Local tab control (same as neko-colab)

```bash
./browse.sh tabs                # list open tabs
./browse.sh open <url>          # open a tab
./browse.sh info                # current tab
./browse.sh shot                # screenshot → /tmp/bu-shots/
./browse.sh ai "<task>"         # AI-driven browsing (needs OPENCODE_API_KEY)
```

Or the full CLI:

```bash
"$BROWSER_ENV/bin/browser-use" <<'PY'
new_tab("https://example.com")
wait_for_load()
print(page_info())
PY
```

---

## What this can and can't see — read this

**✅ Yes (once provisioned + synced):**
- Your **bookmarks** (all folders, all devices — sync pulls them down)
- Your **history** (synced from your devices, available in the profile DB)
- A **persistent login** to your Google account (and any site you log into
  during a session — cookies are stored and re-uploaded)
- Same-origin tabs within the cloud browser itself

**⚠️ Not directly:**
- **"Which tabs you currently have open" on your laptop.** browser-use
  controls *its own* Chrome — it can't reach into your PC's browser. What
  sync gives you is your laptop's open tabs appearing in the cloud
  browser's "Other devices / tabs from other devices" view (best-effort,
  not live control). If you ever want TRUE live control of your PC's
  Chrome, the way is: run a Chrome with remote debugging on your PC and
  attach over Tailscale (safe, encrypted) — say the word and I'll set that
  up instead.

**⚠️ Google may occasionally challenge the session** (expired cookies,
suspicious-IP prompts). If a run shows "not logged in", re-run the
provision workflow to log in again — the profile then refreshes.

---

## Security

- **This repo is PRIVATE** — it stores your Google session. Never make it
  public.
- The profile release (`browser-profile`) contains your cookies — it lives
  only in this private repo.
- The CDP port binds to localhost on the runner (never exposed; the noVNC
  tunnel is created only during provision and only for you).
- No credentials in the repo — you sign in visually during provision.

## Notes

- Runner IPs are datacenter IPs — some sites (banks, etc.) may flag the
  login. Google's one-time visual sign-in handles its own checks fine.
- Setup takes ~4 min per run (installs Chrome + browser-use fresh each time).
  A self-hosted runner on your Kamatera VPS would make this near-instant —
  ask if you want that.
