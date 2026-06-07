#!/usr/bin/env bash
# scripts/build_web.sh — canonical A-KEN Quest web build.
#
# --no-web-resources-cdn: self-host CanvasKit from /canvaskit/ instead of fetching
# it from https://www.gstatic.com/flutter-canvaskit/<rev> on the CRITICAL boot
# path. Removes an uncontrolled cross-origin DNS+TLS+download from every cold open
# (faster + deterministic + offline-capable + resilient on JP/school networks that
# may throttle/filter gstatic). The matching canvaskit/ is emitted into build/web
# by this same build, so revisions stay in lockstep (deploy build/web wholesale).
# Decided by the perf design-panel (agent team), 2026-06-08; CEO load-speed P0.
#
# HEAVY JOB: always run via scripts/safe-job.sh (detached + timeout), never in the
# agent tool loop:
#   scripts/safe-job.sh webbuild 900 scripts/build_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."
exec flutter build web --release --no-web-resources-cdn "$@"
