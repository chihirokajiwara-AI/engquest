#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ENG Quest — live-demo self-healing watchdog (Hetzner VPS)
#
# Run by systemd (engquest-watchdog.timer) every 2 minutes, and 60s after boot.
#
# Responsibility: keep http://<host>:8080/ serving HTTP 200 at all times.
#   1. If the persistent web root is missing/empty, re-sync it from the build
#      dir (covers the "/tmp wiped on reboot" failure mode).
#   2. If nginx is not active, (re)start it.
#   3. Health-check 127.0.0.1:PORT — if not 200, restart nginx once and re-check.
#
# Exit codes:
#   0  site healthy (possibly after self-repair)
#   1  still unhealthy after repair attempt (systemd logs the failure)
#
# All actions are idempotent and safe to run repeatedly.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

PORT="${PORT:-8080}"
WEB_ROOT="${WEB_ROOT:-/var/www/engquest}"
BUILD_SRC="${BUILD_SRC:-/tmp/engquest/build/web}"
URL="http://127.0.0.1:${PORT}/"

log() { printf '[engquest-watchdog] %s\n' "$*"; }

http_code() {
    curl -fsS -o /dev/null -m 8 -w '%{http_code}' "$URL" 2>/dev/null || echo 000
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

# ── 1. content present? ──────────────────────────────────────────────────────
ensure_content

# ── 2. nginx running? ────────────────────────────────────────────────────────
if ! systemctl is-active --quiet nginx 2>/dev/null; then
    log "nginx not active — starting."
    restart_nginx
fi

# ── 3. health check (with one repair attempt) ────────────────────────────────
code="$(http_code)"
if [[ "$code" == "200" ]]; then
    exit 0
fi

log "Health check FAILED (HTTP $code) — attempting self-repair."
ensure_content
restart_nginx

code="$(http_code)"
if [[ "$code" == "200" ]]; then
    log "Recovered — HTTP 200 after restart."
    exit 0
fi

log "STILL UNHEALTHY after repair (HTTP $code). See: journalctl -u nginx -n 50"
exit 1
