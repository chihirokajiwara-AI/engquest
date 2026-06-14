#!/usr/bin/env bash
# scripts/audit_realbrowser.sh — #49: one-command REAL-BROWSER gate.
#
# The loop's structural blind spot (CEO 1355/1358): every other gate runs in
# flutter_test and NEVER touches the actual running app, so "slow boot / blank
# render / dead tap / JS error" slip through green. Three slices already exist —
# but they live in three separate scripts, and that friction is exactly why the
# check gets neglected (it went ~12 loop ticks unrun once). This chains all three
# into a single pass/fail so a perf/QA tick can run the whole real-app audit with
# one command:
#   1. audit_live.sh        — cold-boot payload weight vs hard budgets (curl)
#   2. audit_live_render.sh — real headless-Chrome render + screenshot (booted?)
#   3. smoke_flow.mjs       — Playwright semantic click-flow (dead/slow taps, JS)
#
# Usage:  scripts/audit_realbrowser.sh [base_url]
#         (default http://178.105.113.79:8088 — the live deploy)
# Exit 0 = every available slice passed. Exit 1 = a hard failure in any slice.
# The flow slice needs Playwright; if it is not installed it is SKIPPED with a
# warning (the zero-install payload+render core still gates).

set -u
BASE="${1:-http://178.105.113.79:8088}"
DIR="$(cd "$(dirname "$0")" && pwd)"

hr() { printf '%s\n' "============================================================"; }
say() { printf '%s\n' "$*"; }

FAIL=0
PAYLOAD=skip
RENDER=skip
FLOW=skip

hr; say "REAL-BROWSER AUDIT (#49 combined)  base=$BASE"; hr

# ── 1. Payload budget ────────────────────────────────────────────────────────
say ""; say ">>> [1/3] cold-boot payload budget"
if bash "$DIR/audit_live.sh" "$BASE"; then PAYLOAD=PASS; else PAYLOAD=FAIL; FAIL=1; fi

# ── 2. Real render ───────────────────────────────────────────────────────────
say ""; say ">>> [2/3] real headless-Chrome render"
if bash "$DIR/audit_live_render.sh" "$BASE"; then RENDER=PASS; else RENDER=FAIL; FAIL=1; fi

# ── 3. Semantic click-flow (needs Playwright) ────────────────────────────────
say ""; say ">>> [3/3] real-browser click-flow smoke"
PW=""
for cand in \
  "${PLAYWRIGHT_PATH:-}" \
  "$HOME/dev/ecoauc-resale/node_modules/playwright/index.js" \
  "$HOME/dev/airwork-session/node_modules/playwright/index.js"; do
  [ -n "$cand" ] && [ -f "$cand" ] && { PW="$cand"; break; }
done
if [ -z "$PW" ]; then
  say "SKIP  Playwright not found — install it or set PLAYWRIGHT_PATH to run the"
  say "      flow slice. (payload + render still gate above.)"
  FLOW=SKIP
elif PLAYWRIGHT_PATH="$PW" node "$DIR/smoke_flow.mjs" "$BASE"; then
  FLOW=PASS
else
  FLOW=FAIL; FAIL=1
fi

# ── Summary ──────────────────────────────────────────────────────────────────
say ""; hr
say "  payload budget : $PAYLOAD"
say "  real render    : $RENDER"
say "  click-flow     : $FLOW"
hr
if [ "$FAIL" -eq 0 ]; then
  say "RESULT: PASS — the live app is healthy in a real browser."
else
  say "RESULT: FAIL — a real-browser slice failed (see above)."
fi
exit "$FAIL"
