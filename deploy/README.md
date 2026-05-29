# ENG Quest — Deployment (Hetzner VPS)

Production Flutter Web is served at **http://178.105.113.79:8080/**.

## P0.3 — nginx (replaces `python -m http.server`)

The throwaway `python -m http.server` had no gzip, no cache headers, and did
**not** survive reboots. This package replaces it with nginx managed by systemd.

### Files
| File | Purpose |
|------|---------|
| `nginx/engquest.conf` | nginx server block (port 8080, gzip, cache headers, SPA fallback) |
| `install_nginx.sh` | idempotent installer — deploys config, enables auto-restart, health-checks |
| `test_nginx_config.py` | static + sandboxed `nginx -t` verification (27 checks) |

### Deploy / migrate (run on the VPS as root)
```bash
cd /tmp/engquest && git pull
sudo bash deploy/install_nginx.sh
```
The script will:
1. install nginx if missing
2. kill any lingering `python http.server` bound to :8080
3. pre-compress static assets (`.gz`) for `gzip_static`
4. deploy + symlink the site config, remove the default site
5. `nginx -t` validate **before** reloading
6. `systemctl enable nginx` → **survives reboot**, auto-restarts on crash
7. health-check `http://127.0.0.1:8080/` (must return 200)

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
python3 deploy/test_nginx_config.py        # 27 checks, exits non-zero on failure
curl -sI http://178.105.113.79:8080/        # expect 200 + no-cache on index
```

### Rebuild + redeploy a new web build
```bash
cd /tmp/engquest && flutter build web --release
sudo bash deploy/install_nginx.sh   # re-runs gzip precompress + reload (idempotent)
```

> ⚠️ **Operational note (2026-05-29):** at the time of writing, :8080 was
> unreachable (old `python http.server` had stopped and does not auto-restart).
> Running `install_nginx.sh` on the VPS resolves this permanently — nginx is
> enabled under systemd and restarts on boot/crash. This step requires SSH
> access to the VPS and must be run there; it cannot be performed from CI.
