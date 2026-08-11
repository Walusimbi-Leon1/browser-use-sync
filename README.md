# ☁️ browser-use-sync — Cloud Chrome for Leon

A **persistent, synced Chrome** that runs on GitHub Actions and is controlled
by [browser-use](https://github.com/browser-use/browser-use). It carries
**your real Google profile** — signed in as `walusimbileon2@gmail.com` — with
your bookmarks, history, and sync data, and it survives between runs.

> ⚠️ **This repo is PUBLIC** (public repos get unlimited Actions minutes).
> All sensitive data — the Chrome profile, cookies, sessions — lives in a
> **private** repo instead: **`Walusimbi-Leon1/browser-profile-store`**.
> This repo only contains code; the workflows fetch the profile from the
> private store using a GitHub token stored in repo secrets.

---

## Architecture

```
┌─────────────────────────────┐        GH_PUSH_TOKEN (secret)        ┌──────────────────────────────┐
│  browser-use-sync  (PUBLIC) │ ───────────────────────────────────▶ │  browser-profile-store (PRIV)│
│  • all workflows + scripts  │   gh CLI (authenticated, masked)     │  • profile.tar.gz (release)  │
│  • NO sensitive data        │ ◀─────────────────────────────────── │  • provision-url.txt         │
└─────────────────────────────┘   download at start / upload at end   └──────────────────────────────┘
```

GitHub Actions runners are **ephemeral** — a fresh machine every run. The
private repo's Release is the persistent home of your profile:
`browse.yml` downloads it at the start, and re-uploads it at the end, so
logins, cookies, and sync state carry across runs.

| Piece | What it does |
|---|---|
| `setup.sh` | Installs browser-use + **Google Chrome stable** + Xvfb (idempotent) |
| `start.sh` | Starts Xvfb + Chrome with `$CHROME_PROFILE` on CDP :9222 |
| `browse.sh` | Tab control wrapper: `tabs / open / info / switch / close / shot / ai` |
| `profile.sh` | The **sync engine** — packs/unpacks the profile to/from the PRIVATE repo's Release |
| `.github/workflows/provision.yml` | **One-time:** live noVNC session → you log into Google + enable sync → profile stored privately |
| `.github/workflows/browse.yml` | **Every run:** downloads stored profile → Chrome with it → browser-use → saves profile back |

---

## Step 1 — Provision (one-time, ~10 minutes)

Run **Provision — Google login + sync** (Actions → Run workflow).

The job starts a live desktop on the runner, then writes the **tunnel URL to
the private store repo** (file `provision-url.txt`) — it is *not* printed
here, because this repo is public. You can also ask LA5 to read it for you.

Then, in the tunnel URL's desktop:

1. Go to `accounts.google.com` → sign in as **walusimbileon2@gmail.com**.
   (Solve any captcha / 2FA here — this is the one-time gate. Google
   deliberately blocks fully-automated logins, so we do it once, visually.)
2. `chrome://settings/syncSetup` → **Turn on sync** → **Sync everything**
   (bookmarks, history, open tabs, passwords, settings).
3. Create a bookmark named **`SYNC-DONE`** (Ctrl+D → rename).
   The job detects it, packs the profile, and stores it in the private repo.

Done. Every future run starts from that profile.

## Step 2 — Use it

Run **Browse — synced profile session** (manual, or add a cron later).
It restores your profile, opens Chrome, runs the smoke test
(bookmarks count, recent history, login cookies, live account page), and
saves the profile back. Add real tasks after the smoke step — e.g. an
Instagram reel poster (coming next).

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

## Security — how sensitive data stays private

- **The profile never touches this public repo.** It is packed and stored
  only in `Walusimbi-Leon1/browser-profile-store` (private, Release
  `browser-profile`). No profile files are committed here, and nothing is
  uploaded as a public artifact.
- **Auth via a secret:** workflows use the `GH_PUSH_TOKEN` repo secret (a
  GitHub personal access token) with `gh`. Tokens are never logged —
  GitHub masks secret values everywhere.
- **The provision tunnel URL is masked** (`::add-mask::`) and delivered via
  the private repo instead of the public logs, so nobody can grab the live
  login session mid-provision.
- **No fork-PR risk:** all workflows are `workflow_dispatch`-only (manual),
  never triggered by pushes/PRs — a malicious fork PR cannot run them.
- Screenshots taken during runs stay on the ephemeral runner (no artifact
  upload) to avoid leaking anything via public run artifacts.
- **Recommended hardening:** replace the classic PAT with a
  fine-grained token scoped to *only* `browser-profile-store` (Contents +
  Releases read/write). Ask LA5 and he'll wire it.

## Networking — stable IP via Tailscale exit node

GitHub runners get a fresh datacenter IP every run — sites (including Google)
can flag that. Both workflows now install Tailscale and route **all** traffic
through the EC2 node `100.114.90.6` (the la5-ec2 AWS instance, an exit node
on Leon's tailnet) via `tailscale/github-action@v4` with
`args: --exit-node=100.114.90.6 --exit-node-allow-routing`.

This means browser-use sessions, the Google login, and profile sync all look
like they come from the EC2's stable IP. The action pings `100.114.90.6` to
verify the tailnet link before proceeding, and a step prints the resulting
public IP for confirmation.

> Requires: the EC2 node must run `tailscale up --advertise-exit-node` (or
> `tailscale set --advertise-exit-node`) so it can serve as an exit node.

## Notes

- Runner IPs are datacenter IPs — some sites (banks, etc.) may flag the
  login. Google's one-time visual sign-in handles its own checks fine.
- Setup takes ~4 min per run (installs Chrome + browser-use fresh each time).
  A self-hosted runner on your Kamatera VPS would make this near-instant —
  ask if you want that.
