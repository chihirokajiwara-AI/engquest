#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ENG Quest — nginx deployment / migration script (Hetzner VPS)
#
# Purpose (P0.3): replace the throwaway `python -m http.server :8080` with a
# production nginx server that:
#   • serves /var/www/engquest with gzip + cache headers
#   • survives reboots (systemd nginx.service enabled + PERSISTENT web root)
#   • restarts automatically on crash (systemd default Restart behavior)
#   • self-heals via a systemd watchdog timer (engquest-watchdog) that pings
#     :8080 every 2 min and restarts nginx if the live demo is down
#
# RESILIENCE FIX (P0.3): the build is BUILT at /tmp/engquest/build/web but is
# now COPIED into /var/www/engquest. /tmp is wiped on reboot on many distros
# (systemd-tmpfiles), which is the classic cause of "live demo 404 after
# reboot". The persistent root + watchdog eliminate that failure mode.
#
# IDEMPOTENT: safe to run repeatedly. Run as root (or via sudo) on the VPS.
#
#   curl -fsSL <repo>/deploy/install_nginx.sh | sudo bash
#   # or, from a checkout:
#   sudo bash deploy/install_nginx.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

BUILD_SRC="/tmp/engquest/build/web"   # where flutter build web --release writes
WEB_ROOT="/var/www/engquest"          # PERSISTENT served root (survives reboot)
SITE_SRC_REL="deploy/nginx/engquest.conf"
SITE_AVAILABLE="/etc/nginx/sites-available/engquest.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/engquest.conf"
WATCHDOG_SRC_REL="deploy/engquest-watchdog.sh"
WATCHDOG_BIN="/usr/local/bin/engquest-watchdog.sh"
PORT="8080"          # documented live-demo URL port
ALT_PORT="80"        # clean no-port URL; served by the same nginx server block

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

# ── 3. stop any lingering non-nginx listener on :8080 and :80 ────────────────
log "Stopping any non-nginx process bound to :${PORT} or :${ALT_PORT}..."
if command -v fuser >/dev/null 2>&1; then
    # kill python http.server (or anything) holding the ports; ignore if none.
    for p in "${PORT}" "${ALT_PORT}"; do
        for pid in $(fuser "${p}/tcp" 2>/dev/null || true); do
            if ! ps -p "$pid" -o comm= 2>/dev/null | grep -qi nginx; then
                log "  killing PID $pid on :${p}"
                kill "$pid" 2>/dev/null || true
            fi
        done
    done
fi
# also disable any systemd unit or cron that may relaunch python http.server
if systemctl list-unit-files 2>/dev/null | grep -q '^engquest-http'; then
    log "  disabling legacy engquest-http.service"
    systemctl disable --now engquest-http.service 2>/dev/null || true
fi

# ── 4. sync build into PERSISTENT web root (survives reboot) ──────────────────
# The build is produced under /tmp (volatile). Copy it into /var/www/engquest
# so a reboot that wipes /tmp can never take the live demo down.
mkdir -p "${WEB_ROOT}"
if [[ -d "${BUILD_SRC}" ]] && [[ -n "$(ls -A "${BUILD_SRC}" 2>/dev/null || true)" ]]; then
    log "Syncing fresh build ${BUILD_SRC} -> ${WEB_ROOT}"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "${BUILD_SRC}/" "${WEB_ROOT}/"
    else
        rm -rf "${WEB_ROOT:?}/"* 2>/dev/null || true
        cp -a "${BUILD_SRC}/." "${WEB_ROOT}/"
    fi
elif [[ -f "${WEB_ROOT}/index.html" ]]; then
    log "No fresh build at ${BUILD_SRC}; keeping existing persistent content in ${WEB_ROOT}"
else
    err "No build to serve: ${BUILD_SRC} is empty AND ${WEB_ROOT} has no index.html."
    err "Build Flutter web first:  cd /tmp/engquest && flutter build web --release"
    exit 1
fi
chown -R www-data:www-data "${WEB_ROOT}" 2>/dev/null || true

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

# ── 8b. install self-healing watchdog (systemd timer, every 2 min) ───────────
# Pings the live :8080 endpoint; if it is not serving HTTP 200, it restarts
# nginx and (if the persistent root somehow lost content) re-syncs from the
# build dir. This is the safety net for the "live demo went dark" failure mode.
if [[ -f "${SCRIPT_DIR}/engquest-watchdog.sh" ]]; then
    WATCHDOG_SRC="${SCRIPT_DIR}/engquest-watchdog.sh"
elif [[ -f "${WATCHDOG_SRC_REL}" ]]; then
    WATCHDOG_SRC="${WATCHDOG_SRC_REL}"
else
    WATCHDOG_SRC=""
fi

if [[ -n "${WATCHDOG_SRC}" ]]; then
    log "Installing self-healing watchdog -> ${WATCHDOG_BIN}"
    install -D -m 0755 "${WATCHDOG_SRC}" "${WATCHDOG_BIN}"

    cat > /etc/systemd/system/engquest-watchdog.service <<EOF
[Unit]
Description=ENG Quest live-demo watchdog (restarts nginx if :${PORT} is down)
After=network.target nginx.service

[Service]
Type=oneshot
Environment=PORT=${PORT}
Environment=WEB_ROOT=${WEB_ROOT}
Environment=BUILD_SRC=${BUILD_SRC}
ExecStart=${WATCHDOG_BIN}
EOF

    cat > /etc/systemd/system/engquest-watchdog.timer <<EOF
[Unit]
Description=Run ENG Quest watchdog every 2 minutes

[Timer]
OnBootSec=60
OnUnitActiveSec=120
AccuracySec=15

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now engquest-watchdog.timer >/dev/null 2>&1 || true
    log "Watchdog timer enabled (checks every 2 min, also runs 60s after boot)."
else
    err "engquest-watchdog.sh not found — skipping self-healing watchdog install."
fi

# ── 9. health check (both documented :8080 and clean :80) ────────────────────
sleep 1
log "Health check on http://127.0.0.1:${PORT}/ and http://127.0.0.1:${ALT_PORT}/ ..."
code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/" || echo 000)"
acode="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${ALT_PORT}/" || echo 000)"
if [[ "$code" == "200" && "$acode" == "200" ]]; then
    log "✅ nginx serving ENG Quest on :${PORT} (HTTP $code) AND :${ALT_PORT} (HTTP $acode). Auto-restart on reboot ENABLED."
else
    err "Health check failed (:${PORT}=$code, :${ALT_PORT}=$acode). Inspect: journalctl -u nginx --no-pager -n 50"
    exit 1
fi
