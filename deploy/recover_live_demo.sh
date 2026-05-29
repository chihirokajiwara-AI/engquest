#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ENG Quest — ONE-LINE live-demo recovery + permanent self-heal bootstrap
#
#   curl -fsSL https://raw.githubusercontent.com/chihirokajiwara-AI/engquest/main/deploy/recover_live_demo.sh | sudo bash
#
# WHY THIS EXISTS
# ───────────────
# `deploy/install_nginx.sh` is the production installer, but its recovery runbook
# told operators to `cd /tmp/engquest && git pull`. That is broken on the *exact*
# failure mode we are fixing: **/tmp is wiped on reboot**, so after a reboot the
# repo checkout in /tmp is GONE and the runbook cannot run. Likewise the systemd
# watchdog only restarts nginx — it does nothing if nginx was never installed
# (e.g. the box is still on the throwaway `python -m http.server`, which died).
#
# This script is the resilient front door. It is SELF-CONTAINED and SAFE to run
# on a fresh, half-configured, or post-reboot VPS:
#
#   1. Ensure git is present.
#   2. Clone/refresh the repo into a PERSISTENT path (/opt/engquest-src) — never
#      /tmp — so recovery survives reboots.
#   3. Ensure a Flutter web build exists to serve. If the build dir is missing
#      AND the persistent web root already has content, reuse it; otherwise fall
#      back to the checked-in static web demo (web/) so the site is NEVER blank.
#   4. Run install_nginx.sh (idempotent: installs nginx + systemd watchdog).
#   5. Install a @reboot + */2min CRON backstop that is INDEPENDENT of systemd
#      timers, so even if systemd timers are wiped/disabled the demo self-heals.
#   6. Final external-style health check on :8080.
#
# IDEMPOTENT. Re-running only converges state. Run as root (sudo).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/chihirokajiwara-AI/engquest.git}"
SRC_DIR="${SRC_DIR:-/opt/engquest-src}"        # PERSISTENT checkout (NOT /tmp)
BUILD_SRC="${BUILD_SRC:-/tmp/engquest/build/web}"
WEB_ROOT="${WEB_ROOT:-/var/www/engquest}"
WATCHDOG_BIN="${WATCHDOG_BIN:-/usr/local/bin/engquest-watchdog.sh}"
CRON_FILE="/etc/cron.d/engquest-watchdog"
PORT="${PORT:-8080}"

log() { printf '\033[1;36m[recover]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[recover][ERROR]\033[0m %s\n' "$*" >&2; }

# ── 0. root ──────────────────────────────────────────────────────────────────
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root (use sudo)."
    exit 1
fi

# ── 1. ensure git ────────────────────────────────────────────────────────────
if ! command -v git >/dev/null 2>&1; then
    log "Installing git..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq git
fi

# ── 2. clone/refresh repo into PERSISTENT path ───────────────────────────────
if [[ -d "${SRC_DIR}/.git" ]]; then
    log "Refreshing existing checkout at ${SRC_DIR}"
    git -C "${SRC_DIR}" fetch --depth 1 origin main >/dev/null 2>&1 || true
    git -C "${SRC_DIR}" reset --hard origin/main >/dev/null 2>&1 || true
else
    log "Cloning ${REPO_URL} -> ${SRC_DIR}"
    rm -rf "${SRC_DIR}" 2>/dev/null || true
    git clone --depth 1 "${REPO_URL}" "${SRC_DIR}"
fi

# ── 3. guarantee SOMETHING to serve (never a blank demo) ─────────────────────
# Priority: fresh /tmp build > existing persistent root > checked-in static web/.
mkdir -p "${WEB_ROOT}"
have_build=false
if [[ -f "${BUILD_SRC}/index.html" ]]; then
    have_build=true
elif [[ -f "${WEB_ROOT}/index.html" ]]; then
    log "Reusing existing persistent web root content."
    have_build=true
elif [[ -f "${SRC_DIR}/web/index.html" ]]; then
    log "No Flutter build found — seeding persistent root from checked-in web/ demo."
    if command -v rsync >/dev/null 2>&1; then
        rsync -a "${SRC_DIR}/web/" "${WEB_ROOT}/"
    else
        cp -a "${SRC_DIR}/web/." "${WEB_ROOT}/"
    fi
    chown -R www-data:www-data "${WEB_ROOT}" 2>/dev/null || true
    have_build=true
fi
if [[ "${have_build}" != true ]]; then
    err "No content available to serve (no /tmp build, no persistent root, no web/)."
    exit 1
fi

# ── 4. run the production installer (nginx + systemd watchdog) ───────────────
log "Running install_nginx.sh ..."
bash "${SRC_DIR}/deploy/install_nginx.sh"

# ── 5. CRON backstop (independent of systemd timers) ─────────────────────────
# Belt-and-suspenders: even if the systemd watchdog timer is removed/masked,
# cron re-runs the watchdog at boot and every 2 minutes.
if [[ -x "${WATCHDOG_BIN}" ]]; then
    log "Installing cron backstop -> ${CRON_FILE}"
    cat > "${CRON_FILE}" <<EOF
# ENG Quest live-demo self-heal backstop (independent of systemd timers).
# Installed by deploy/recover_live_demo.sh. Safe to remove if systemd timer is trusted.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
@reboot root PORT=${PORT} WEB_ROOT=${WEB_ROOT} BUILD_SRC=${BUILD_SRC} ${WATCHDOG_BIN} >> /var/log/engquest-watchdog.log 2>&1
*/2 * * * * root PORT=${PORT} WEB_ROOT=${WEB_ROOT} BUILD_SRC=${BUILD_SRC} ${WATCHDOG_BIN} >> /var/log/engquest-watchdog.log 2>&1
EOF
    chmod 0644 "${CRON_FILE}"
    # cron picks up /etc/cron.d automatically; nudge the daemon if present.
    systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
else
    err "Watchdog binary missing at ${WATCHDOG_BIN}; cron backstop skipped."
fi

# ── 6. final health check ────────────────────────────────────────────────────
sleep 1
code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/" || echo 000)"
if [[ "${code}" == "200" ]]; then
    log "✅ Live demo RECOVERED on :${PORT} (HTTP ${code})."
    log "   Persistent src: ${SRC_DIR}  |  web root: ${WEB_ROOT}"
    log "   Self-heal: systemd timer + cron backstop (@reboot + every 2 min)."
else
    err "Health check returned HTTP ${code}. Inspect: journalctl -u nginx -n 50 --no-pager"
    exit 1
fi
