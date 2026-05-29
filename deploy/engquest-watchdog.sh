#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ENG Quest — live-demo self-healing watchdog (Hetzner VPS)
#
# Run by systemd (engquest-watchdog.timer) every 2 minutes, and 60s after boot.
#
# Responsibility: keep the live demo serving HTTP 200 at all times on BOTH the
# documented :8080 URL and the clean :80 URL.
#   1. If the persistent web root is missing/empty, re-sync it from the build
#      dir (covers the "/tmp wiped on reboot" failure mode).
#   2. If nginx is not active, (re)start it.
#   3. Health-check 127.0.0.1:8080 AND 127.0.0.1:80 — if either is not 200,
#      restart nginx once and re-check.
#
# Exit codes:
#   0  site healthy (possibly after self-repair)
#   1  still unhealthy after repair attempt (systemd logs the failure)
#
# All actions are idempotent and safe to run repeatedly.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Primary documented port is 8080; we also verify :80 so a single-port
# regression (the failure that took the live demo dark) is caught immediately.
PORT="${PORT:-8080}"
ALT_PORT="${ALT_PORT:-80}"
WEB_ROOT="${WEB_ROOT:-/var/www/engquest}"
BUILD_SRC="${BUILD_SRC:-/tmp/engquest/build/web}"
URL="http://127.0.0.1:${PORT}/"
ALT_URL="http://127.0.0.1:${ALT_PORT}/"

log() { printf '[engquest-watchdog] %s\n' "$*"; }

http_code() {
    curl -fsS -o /dev/null -m 8 -w '%{http_code}' "$1" 2>/dev/null || echo 000
}

# Healthy ONLY when BOTH the documented :8080 and the clean :80 serve 200.
both_healthy() {
    local p a
    p="$(http_code "$URL")"
    a="$(http_code "$ALT_URL")"
    [[ "$p" == "200" && "$a" == "200" ]]
}

ensure_content() {
    # Re-populate the persistent root from the build dir if it lost its content.
    if [[ ! -f "${WEB_ROOT}/index.html" ]]; then
        if [[ -f "${BUILD_SRC}/index.html" ]]; then
            log "Persistent root empty — re-syncing from ${BUILD_SRC}"
            mkdir -p "${WEB_ROOT}"
            if command -v rsync >/dev/null 2>&1; then
                rsync -a --delete "${BUILD_SRC}/" "${WEB_ROOT}/"
            else
                cp -a "${BUILD_SRC}/." "${WEB_ROOT}/"
            fi
            chown -R www-data:www-data "${WEB_ROOT}" 2>/dev/null || true
        else
            log "WARNING: no content in ${WEB_ROOT} and no build at ${BUILD_SRC}"
        fi
    fi
}

restart_nginx() {
    log "Restarting nginx..."
    systemctl restart nginx 2>/dev/null || systemctl start nginx 2>/dev/null || true
    sleep 2
}

# ── self-update deployed nginx config from origin/main when it drifts ─────────
# Closes the "I changed the committed config but can't SSH to deploy it" loop:
# the watchdog refreshes the persistent checkout and, if the committed site
# config differs from what is deployed, re-installs it (validated by nginx -t).
# This is how the dual-port (:80 + :8080) fix reaches the live box without SSH.
SRC_DIR="${SRC_DIR:-/opt/engquest-src}"
SITE_SRC="${SRC_DIR}/deploy/nginx/engquest.conf"
SITE_DEPLOYED="/etc/nginx/sites-available/engquest.conf"

sync_config() {
    [[ -d "${SRC_DIR}/.git" ]] || return 0
    git -C "${SRC_DIR}" fetch --depth 1 origin main >/dev/null 2>&1 || return 0
    git -C "${SRC_DIR}" reset --hard origin/main >/dev/null 2>&1 || return 0
    [[ -f "${SITE_SRC}" ]] || return 0
    if [[ ! -f "${SITE_DEPLOYED}" ]] || ! cmp -s "${SITE_SRC}" "${SITE_DEPLOYED}"; then
        log "nginx config drift detected — re-deploying committed config."
        install -D -m 0644 "${SITE_SRC}" "${SITE_DEPLOYED}"
        ln -sf "${SITE_DEPLOYED}" /etc/nginx/sites-enabled/engquest.conf
        rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
        if nginx -t >/dev/null 2>&1; then
            systemctl reload nginx 2>/dev/null || restart_nginx
            log "Re-deployed + reloaded committed nginx config."
        else
            log "WARNING: committed config failed nginx -t; keeping current."
        fi
    fi
}

# ── 1. content present? ──────────────────────────────────────────────────────
ensure_content

# ── 1.5 self-update config from origin/main if it drifted ────────────────────
sync_config

# ── 2. nginx running? ────────────────────────────────────────────────────────
if ! systemctl is-active --quiet nginx 2>/dev/null; then
    log "nginx not active — starting."
    restart_nginx
fi

# ── 3. health check (with one repair attempt) ────────────────────────────────
if both_healthy; then
    exit 0
fi

log "Health check FAILED (:${PORT}=$(http_code "$URL"), :${ALT_PORT}=$(http_code "$ALT_URL")) — attempting self-repair."
ensure_content
restart_nginx

if both_healthy; then
    log "Recovered — HTTP 200 on both :${PORT} and :${ALT_PORT} after restart."
    exit 0
fi

log "STILL UNHEALTHY after repair (:${PORT}=$(http_code "$URL"), :${ALT_PORT}=$(http_code "$ALT_URL")). See: journalctl -u nginx -n 50"
exit 1
