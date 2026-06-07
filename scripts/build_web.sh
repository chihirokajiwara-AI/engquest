#!/usr/bin/env bash
# scripts/build_web.sh — canonical A-KEN Quest web build.
#
# CanvasKit source: gstatic CDN (Flutter default — NO --no-web-resources-cdn).
# Measured 2026-06-08 (scripts/qa/perf_audit.mjs breakdown): canvaskit.wasm is the
# single biggest cold-boot cost. gstatic = 0.35s / 2.27MB (Brotli, global edge incl.
# a Tokyo PoP for our JP users); self-hosting from the single-origin Hetzner VPS
# (Germany, gzip-only) = 3.21s / 3.23MB — ~9× SLOWER. An earlier self-host attempt
# (--no-web-resources-cdn, commit b07140b) was therefore a ~2.8s boot REGRESSION and
# is reverted here. gstatic is a Google CDN (widely reachable in Japan); the
# speculative "school-filter" resilience does not justify a measured 9× slowdown.
#
# HEAVY JOB: always run via scripts/safe-job.sh, never in the agent tool loop:
#   scripts/safe-job.sh webbuild 900 scripts/build_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."
exec flutter build web --release "$@"
