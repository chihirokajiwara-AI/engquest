#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ENG Quest — nginx deployment / migration script (Hetzner VPS)
#
# Purpose (P0.3): replace the throwaway `python -m http.server :8080` with a
# production nginx server that:
#   • serves /tmp/engquest/build/web with gzip + cache headers
#   • survives reboots (systemd nginx.service enabled)
#   • restarts automatically on crash (systemd default Restart behavior)
#
# IDEMPOTENT: safe to run repeatedly. Run as root (or via sudo) on the VPS.
#
#   curl -fsSL <repo>/deploy/install_nginx.sh | sudo bash
#   # or, from a checkout:
#   sudo bash deploy/install_nginx.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

WEB_ROOT="/tmp/engquest/build/web"
SITE_SRC_REL="deploy/nginx/engquest.conf"
SITE_AVAILABLE="/etc/nginx/sites-available/engquest.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/engquest.conf"
PORT="8080"

log()  { printf '\033[1;36m[engquest]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[engquest][ERROR]\033[0m %s\n' "$*" >&2; }

# Resolve the config source whether run from a checkout or piped from curl.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo /tmp)"
if [[ -f "${SCRIPT_DIR}/nginx/engquest.conf" ]]; then
    SITE_SRC="${SCRIPT_DIR}/nginx/engquest.conf"
elif [[ -f "${SITE_SRC_REL}" ]]; then
    SITE_SRC="${SITE_SRC_REL}"
else
    err "Cannot locate engquest.conf. Run from repo root or alongside deploy/nginx/."
    exit 1
fi

# ── 1. root check ────────────────────────────────────────────────────────────
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root (use sudo)."
    exit 1
fi

# ── 2. install nginx if missing ──────────────────────────────────────────────
if ! command -v nginx >/dev/null 2>&1; then
    log "Installing nginx..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq nginx
else
    log "nginx already installed: $(nginx -v 2>&1)"
fi

# ── 3. stop any lingering python http.server on :8080 ────────────────────────
log "Stopping any process bound to :${PORT} that is not nginx..."
if command -v fuser >/dev/null 2>&1; then
    # kill python http.server holding the port; ignore if none.
    for pid in $(fuser "${PORT}/tcp" 2>/dev/null || true); do
        if ! ps -p "$pid" -o comm= 2>/dev/null | grep -qi nginx; then
            log "  killing PID $pid on :${PORT}"
            kill "$pid" 2>/dev/null || true
        fi
    done
fi
# also disable any systemd unit or cron that may relaunch python http.server
if systemctl list-unit-files 2>/dev/null | grep -q '^engquest-http'; then
    log "  disabling legacy engquest-http.service"
    systemctl disable --now engquest-http.service 2>/dev/null || true
fi

# ── 4. ensure web root exists ────────────────────────────────────────────────
if [[ ! -d "${WEB_ROOT}" ]]; then
    err "Web root ${WEB_ROOT} does not exist. Build Flutter web first:"
    err "  cd /tmp/engquest && flutter build web --release"
    exit 1
fi

# ── 5. pre-compress static assets for gzip_static ────────────────────────────
log "Pre-compressing static assets (.gz) for gzip_static..."
find "${WEB_ROOT}" -type f \
    \( -name '*.js' -o -name '*.css' -o -name '*.json' -o -name '*.wasm' \
       -o -name '*.svg' -o -name '*.html' \) \
    -exec gzip -9 -k -f {} \; 2>/dev/null || true

# ── 6. deploy site config ────────────────────────────────────────────────────
log "Deploying nginx site config -> ${SITE_AVAILABLE}"
install -D -m 0644 "${SITE_SRC}" "${SITE_AVAILABLE}"
ln -sf "${SITE_AVAILABLE}" "${SITE_ENABLED}"

# remove the default site so it doesn't grab :80/:8080 default_server
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# ── 7. validate config ───────────────────────────────────────────────────────
log "Validating nginx configuration..."
if ! nginx -t; then
    err "nginx config test FAILED — aborting before reload."
    exit 1
fi

# ── 8. enable on boot + (re)start ────────────────────────────────────────────
log "Enabling nginx on boot (survives reboot) and restarting..."
systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx

# ── 9. health check ──────────────────────────────────────────────────────────
sleep 1
log "Health check on http://127.0.0.1:${PORT}/ ..."
code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/" || echo 000)"
if [[ "$code" == "200" ]]; then
    log "✅ nginx serving ENG Quest on :${PORT} (HTTP $code). Auto-restart on reboot ENABLED."
else
    err "Health check returned HTTP $code. Inspect: journalctl -u nginx --no-pager -n 50"
    exit 1
fi
