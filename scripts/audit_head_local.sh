#!/usr/bin/env bash
# scripts/audit_head_local.sh — playtest the CURRENT local code (HEAD), not the
# stale :8088 deploy. Builds web, serves it locally, and runs the real-browser
# core-英検-flow smoke against it. Answers "can the NEW work actually be played?"
# and de-risks the eventual deploy.
#
# HEAVY JOB — never run in the agent tool loop. Launch detached + bounded:
#   scripts/safe-job.sh headplaytest 900 scripts/audit_head_local.sh
set -uo pipefail
cd "$(dirname "$0")/.."

PORT=8077
echo "[1/3] flutter build web --release (edilab entrypoint)…"
if ! flutter build web --release -t lib/main_edilab.dart; then
  echo "RESULT: FAIL — web build broke on HEAD"
  exit 2
fi

echo "[2/3] serving build/web on :$PORT …"
( cd build/web && python3 -m http.server "$PORT" >/dev/null 2>&1 ) &
SERVE_PID=$!
trap 'kill "$SERVE_PID" 2>/dev/null || true' EXIT
up=0
for _ in $(seq 1 30); do
  curl -sf "http://localhost:$PORT/" >/dev/null 2>&1 && { up=1; break; }
  sleep 1
done
[ "$up" = 1 ] || { echo "RESULT: FAIL — local server never came up"; exit 3; }

echo "[3/3] real-browser core-flow smoke…"
PW=""
for c in "${PLAYWRIGHT_PATH:-}" \
         "$HOME/dev/ecoauc-resale/node_modules/playwright/index.js" \
         "$HOME/dev/airwork-session/node_modules/playwright/index.js"; do
  [ -n "$c" ] && [ -f "$c" ] && { PW="$c"; break; }
done
if [ -z "$PW" ]; then
  echo "RESULT: PARTIAL — build+serve OK but playwright not found (smoke skipped)"
  exit 0
fi

PLAYWRIGHT_PATH="$PW" node scripts/smoke_flow.mjs "http://localhost:$PORT"
STATUS=$?
if [ "$STATUS" = 0 ]; then
  echo "RESULT: PASS — HEAD builds, boots, and the core 英検 flow plays locally"
else
  echo "RESULT: FAIL — smoke failed (status=$STATUS) on the HEAD build"
fi
exit "$STATUS"
