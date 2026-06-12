#!/usr/bin/env bash
# scripts/audit_live.sh — STANDING real-app audit (#49, CEO 1355/1358 2026-06-12).
#
# The loop's other gates (flutter analyze/test, verify_*) run in flutter_test —
# they NEVER touch the actual running app. So real cold-boot weight, broken
# serving, and uncompressed payloads slip through (the load-speed pain the CEO
# hit on :8088). This is the FIRST executable slice of #49: load the LIVE deploy
# and measure what a real browser must download before the app runs, with budgets
# that FAIL on regressions. (Slice 2 = a Playwright flow-click + visual-break
# harness, built next.)
#
# Usage:  scripts/audit_live.sh [base_url]   (default http://178.105.113.79:8088)
# Exit 0 = within budget; 1 = a hard budget breach (oversized / uncompressed /
# unreachable). Warnings (e.g. no brotli) print but don't fail.

set -u
BASE="${1:-http://178.105.113.79:8088}"
FAIL=0; WARN=0

# Hard budgets (raw, uncompressed bytes) — raise deliberately, never silently.
CANVASKIT_MAX=8000000      # ~7.6MB: the CanvasKit wasm engine
MAINJS_MAX=5500000         # ~5.2MB: the compiled app
MANIFEST_MAX=400000        # 400KB: AssetManifest (bloats if a heavy dir is bundled)

say() { printf '%s\n' "$*"; }
hr()  { printf '%s\n' "------------------------------------------------------------"; }

probe() { # name path max  → echoes "code size encoding"; updates FAIL/WARN
  local name="$1" path="$2" max="$3"
  local out code size enc
  out=$(curl -s -o /dev/null -D - -H 'Accept-Encoding: br,gzip' --max-time 25 \
        -w '%{http_code} %{size_download}' "$BASE/$path" 2>/dev/null)
  code=$(printf '%s' "$out" | tail -1 | awk '{print $1}')
  size=$(printf '%s' "$out" | tail -1 | awk '{print $2}')
  enc=$(printf '%s' "$out" | grep -i '^content-encoding:' | tr -d '\r' | awk '{print tolower($2)}')
  if [ "$code" != "200" ]; then
    say "FAIL  $name: HTTP $code (expected 200) for /$path"; FAIL=1; return
  fi
  local flag="ok"
  if [ "${max}" != "-" ] && [ "${size:-0}" -gt "$max" ]; then
    flag="OVER BUDGET (>$max)"; FAIL=1
  fi
  printf '  %-22s %8sB  enc=%-4s  %s\n' "$name" "${size:-0}" "${enc:-none}" "$flag"
  # Compression checks for the big text/wasm payloads.
  case "$name" in
    canvaskit.wasm|main.dart.js)
      if [ -z "$enc" ]; then
        say "FAIL  $name served UNCOMPRESSED — enable gzip/brotli"; FAIL=1
      elif [ "$enc" = "gzip" ]; then
        say "  WARN  $name is gzip but NOT brotli — brotli saves ~25-30% more"; WARN=1
      fi
      ;;
  esac
}

hr; say "LIVE-APP AUDIT (#49)  base=$BASE"; hr

# 1. Reachability
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$BASE/" 2>/dev/null)
if [ "$code" != "200" ]; then
  say "FAIL  app root unreachable (HTTP ${code:-timeout}) — deploy down?"; exit 1
fi
say "  root reachable (HTTP 200)"
say ""
say "Cold-boot payload (what a real browser downloads before first paint):"

# 2. Critical-path assets + budgets
probe "flutter_bootstrap.js" "flutter_bootstrap.js" "-"
probe "flutter.js"           "flutter.js"           "-"
probe "main.dart.js"         "main.dart.js"         "$MAINJS_MAX"
probe "canvaskit.wasm"       "canvaskit/canvaskit.wasm" "$CANVASKIT_MAX"
probe "AssetManifest"        "assets/AssetManifest.bin.json" "$MANIFEST_MAX"

hr
if [ "$FAIL" -ne 0 ]; then
  say "RESULT: FAIL — a hard budget/serving breach above. Cold-boot is engine+app"
  say "download-bound; keep main.dart.js + canvaskit lean and compressed."
  exit 1
fi
[ "$WARN" -ne 0 ] && say "RESULT: PASS (with warnings — see WARN lines)" || say "RESULT: PASS"
exit 0
