# ENG Quest — Deployment (Hetzner VPS)

Production Flutter Web is served at **http://178.105.113.79:8080/**.

## P0.3 — nginx (replaces `python -m http.server`) + reboot resilience

The throwaway `python -m http.server` had no gzip, no cache headers, and did
**not** survive reboots. This package replaces it with nginx managed by systemd,
served from a **persistent web root** with a **self-healing watchdog**.

### Files
| File | Purpose |
|------|---------|
| `nginx/engquest.conf` | nginx server block (port 8080, gzip, cache headers, SPA fallback) — root `/var/www/engquest` |
| `install_nginx.sh` | idempotent installer — syncs build to persistent root, deploys config, enables auto-restart + watchdog, health-checks |
| `engquest-watchdog.sh` | self-healing watchdog — pings :8080, restarts nginx / re-syncs content if the demo is down |
| `test_nginx_config.py` | static + sandboxed `nginx -t` verification (37 checks) |

### ⚠️ Why this changed (root-cause of live-demo outages)
The web root was `/tmp/engquest/build/web`. **`/tmp` is wiped on reboot** on most
distros (systemd-tmpfiles), so a reboot would delete the site and nginx would
404 — exactly the "live demo went dark" symptom. The fix:

1. **Persistent root** — the build is now **copied** from `/tmp/engquest/build/web`
   into **`/var/www/engquest`**, which survives reboots.
2. **Self-healing watchdog** — a systemd timer (`engquest-watchdog.timer`) runs
   60s after boot and **every 2 minutes**, health-checks `:8080`, and if it is
   down: re-syncs the persistent root (if empty) and restarts nginx.

### Deploy / migrate (run on the VPS as root)
```bash
cd /tmp/engquest && git pull
sudo bash deploy/install_nginx.sh
```
The script will:
1. install nginx if missing
2. kill any lingering `python http.server` bound to :8080
3. **sync `/tmp/engquest/build/web` → `/var/www/engquest`** (persistent root)
4. pre-compress static assets (`.gz`) for `gzip_static`
5. deploy + symlink the site config, remove the default site
6. `nginx -t` validate **before** reloading
7. `systemctl enable nginx` → **survives reboot**, auto-restarts on crash
8. install + enable `engquest-watchdog.timer` → **self-heals every 2 min**
9. health-check `http://127.0.0.1:8080/` (must return 200)

### 🚑 Recovery runbook (if the live demo is down RIGHT NOW)
SSH to the VPS and run:
```bash
cd /tmp/engquest && git pull && sudo bash deploy/install_nginx.sh
```
That single command restores the site **and** installs the watchdog so this
outage cannot recur on its own. To check the watchdog:
```bash
systemctl status engquest-watchdog.timer
journalctl -u engquest-watchdog.service -n 20 --no-pager
```

### Behavior
| Path | Cache-Control | Notes |
|------|---------------|-------|
| `/index.html`, `/sw.js`, `/flutter_service_worker.js` | `no-cache` | new builds appear instantly |
| `*.js` `*.css` `*.wasm` | `public, max-age=31536000, immutable` | content-hashed by Flutter |
| `*.mp3` `*.svg` `*.png` `*.json` fonts | `public, max-age=2592000` + `Access-Control-Allow-Origin: *` | 30d |
| any other route | → `/index.html` | SPA deep-link fallback |

- **gzip** on for text/js/css/json/wasm/svg; `gzip_static` serves pre-built `.gz`.

### Verify
```bash
python3 deploy/test_nginx_config.py        # 37 checks, exits non-zero on failure
curl -sI http://178.105.113.79:8080/        # expect 200 + no-cache on index
```

### Rebuild + redeploy a new web build
```bash
cd /tmp/engquest && flutter build web --release
sudo bash deploy/install_nginx.sh   # re-syncs persistent root + gzip + reload (idempotent)
```

> ⚠️ **Operational note (2026-05-29):** :8080 was **unreachable** at this run
> (HTTP 000). The persistent-root + watchdog hardening in this commit is the
> permanent fix. Running `install_nginx.sh` on the VPS resolves the outage and
> prevents recurrence. This step requires SSH access to the VPS and must be run
> there; it cannot be performed from CI (no VPS credentials available here).
