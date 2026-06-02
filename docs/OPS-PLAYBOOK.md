# ENG Quest — Ops Playbook (hermes-engquest)

## 1. VPS Access

| Item | Value |
|------|-------|
| Host | `178.105.113.79` (Hetzner) |
| SSH | `ssh root@178.105.113.79` |
| Web root | `/var/www/engquest` (persistent — survives reboots) |
| Source checkout | `/opt/engquest-src` (persistent clone of `main`) |
| nginx config | `/etc/nginx/sites-available/engquest.conf` → symlinked to `sites-enabled/` |
| nginx logs | `/var/log/nginx/engquest.{access,error}.log` |

Ports served: **:80** and **:8080** (both required — documented demo URL is `:8080`).

---

## 2. Flutter Web Deploy

```bash
# 1. Build locally (requires Flutter 3.44+)
flutter build web --release --web-renderer canvaskit

# 2. Rsync to VPS persistent root
rsync -avz --delete build/web/ root@178.105.113.79:/var/www/engquest/

# 3. Reload nginx (no downtime)
ssh root@178.105.113.79 "nginx -t && systemctl reload nginx"
```

Docker build alternative (no local Flutter install):
```bash
docker run --rm -v $(pwd):/app cirrusci/flutter:latest bash -c \
  "cd /app && flutter build web --release --web-renderer canvaskit"
```

After rsync the watchdog (`*/2 * * * *`) self-verifies health on both ports.

---

## 3. Backend Deploy (aken-backend)

`backend/docker-compose.yml` — container `aken-backend`, port `127.0.0.1:3001`.

```bash
ssh root@178.105.113.79
cd /opt/engquest-src/backend

# Rebuild and restart
docker compose up -d --build

# Check
docker compose ps
docker compose logs --tail 50 aken-backend
```

Required env vars (set in `.env` alongside `docker-compose.yml` — never baked into image):
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `CLAUDE_API_KEY`, `STRIPE_PRICE_ID`,
`FIREBASE_PROJECT_ID`, `ALLOWED_ORIGINS`, `GOOGLE_APPLICATION_CREDENTIALS`.
Firebase service account JSON must be mounted at `/app/firebase-service-account.json`.

---

## 4. Watchdog

**Script**: `deploy/engquest-watchdog.sh` → deployed to `/usr/local/bin/engquest-watchdog.sh`
**Cron backstop**: `/etc/cron.d/engquest-watchdog`

```
@reboot      root  /usr/local/bin/engquest-watchdog.sh >> /var/log/engquest-watchdog.log 2>&1
*/2 * * * *  root  /usr/local/bin/engquest-watchdog.sh >> /var/log/engquest-watchdog.log 2>&1
```

Also backed by `engquest-watchdog.timer` (systemd, every 2 min + 60 s after boot).

What it does on each run:
1. Re-syncs `/var/www/engquest` from `/tmp/engquest/build/web` if `index.html` is missing.
2. Fetches `origin/main` into `/opt/engquest-src` and re-installs nginx config if it drifted.
3. Restarts nginx if not active.
4. HTTP health-checks `127.0.0.1:8080` AND `127.0.0.1:80` — one repair attempt if either != 200.
5. Exit 0 = healthy; exit 1 = still down (logged).

```bash
# Verify
systemctl status engquest-watchdog.timer
tail -n 20 /var/log/engquest-watchdog.log
```

---

## 5. Recovery (post-reboot / blank VPS)

```bash
curl -fsSL https://raw.githubusercontent.com/chihirokajiwara-AI/engquest/main/deploy/recover_live_demo.sh | sudo bash
```

What it does:
1. Installs git if missing.
2. Clones/refreshes repo into `/opt/engquest-src` (never `/tmp`).
3. Seeds `/var/www/engquest` from: fresh `/tmp` build → existing persistent root → checked-in `web/` fallback.
4. Runs `deploy/install_nginx.sh` (idempotent — nginx + systemd watchdog).
5. Installs cron backstop `/etc/cron.d/engquest-watchdog`.
6. Final health check on `:8080` — exits non-zero if still unhealthy.

On failure: `journalctl -u nginx -n 50 --no-pager`

The old runbook (`cd /tmp/engquest && git pull`) is broken — `/tmp` is wiped on reboot.

---

## 6. Kokoro TTS

**Venv**: `~/.venvs/kokoro/` (Mac Mini, ¥0, no external API)
**Script**: `scripts/generate_kokoro_audio.py`
**Output**: `assets/audio/{grade}/{vocab_id}_{word}.mp3`

```bash
source ~/.venvs/kokoro/bin/activate

# Count missing without generating
python3 scripts/generate_kokoro_audio.py --dry-run

# Generate all grades
python3 scripts/generate_kokoro_audio.py

# Single grade
python3 scripts/generate_kokoro_audio.py --grade eiken5

# Custom voice (default: af_heart)
python3 scripts/generate_kokoro_audio.py --voice af_heart
```

Key details:
- `KPipeline(lang_code='a')` — American English
- Each word spoken twice: `"{word}. {word}."` for clear pronunciation
- WAV (24 kHz) → MP3 via `ffmpeg -codec:a libmp3lame -qscale:a 6`; WAV kept as fallback if ffmpeg absent
- Skips existing files > 100 bytes (idempotent)
- Grades: `eiken5`, `eiken4`, `eiken3`, `eiken_pre2`, `eiken2`, `eiken_pre1`

---

## 7. Common Issues

### WAV race condition with flutter test
**Symptom**: `flutter test` fails with file-not-found on `.wav` assets.
**Cause**: `generate_kokoro_audio.py` writes `.wav` then renames/removes it; parallel test catches the intermediate state.
**Fix**: Never run audio generation and `flutter test` in parallel.
If a stale `.wav` was committed: `git rm assets/audio/**/*.wav`.

### Formatter drift (CI red on `dart format`)
**Symptom**: CI `dart format --output=none --set-exit-if-changed` fails on 59+ files.
**Cause**: Flutter 3.22 formatter (old CI) vs Flutter 3.44 (local) produce different output.
**Fix**: Pin CI to Flutter 3.44.x. Until then:
```bash
dart format lib/ test/
git add -u && git commit -m "chore: dart format 3.44"
```

### nginx 404 after VPS reboot
**Cause**: Old config used `/tmp/engquest/build/web` as root — `/tmp` wiped on reboot.
**Fix**: Web root is now `/var/www/engquest` (persistent). If still 404: run recovery (§5).

### :8080 up but :80 down (or vice versa)
**Cause**: nginx config replaced with a single-port version (config drift).
**Fix**: Watchdog auto-detects and re-installs dual-port config on next run.
Manual: `systemctl reload nginx`, or re-run `recover_live_demo.sh`.
