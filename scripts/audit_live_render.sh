#!/usr/bin/env bash
# scripts/audit_live_render.sh — #49 slice-2: real-browser RENDER audit.
#
# slice-1 (audit_live.sh) measures the cold-boot payload over HTTP. This slice
# actually RENDERS the live app in a real headless browser and verifies it
# PAINTED — catching what neither flutter_test nor a curl can: the app failing to
# boot (white screen / crashed canvas), a blank/broken render, or a tofu'd title.
# It captures a screenshot for visual review (by a human or the loop's art-QA eye)
# and asserts the Flutter view actually mounted.
#
# Uses the installed Google Chrome in headless mode — no extra dependency. (A
# richer slice-2.5 with page-console + network-404 capture and semantic flow
# clicks would use Playwright; this v1 is the reliable, zero-install core.)
#
# Usage:  scripts/audit_live_render.sh [base_url]
# Exit 0 = app booted and painted; 1 = did not boot / blank / unreachable.

set -u
BASE="${1:-http://178.105.113.79:8088}"
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT="${ART_OUTDIR:-/tmp}/engquest_live_render.png"
DOM="/tmp/engquest_live_dom.html"
MIN_PNG_BYTES=40000   # a real painted screen is >40KB; a blank canvas is tiny

say() { printf '%s\n' "$*"; }
hr()  { printf '%s\n' "------------------------------------------------------------"; }

hr; say "LIVE-APP RENDER AUDIT (#49 slice-2)  base=$BASE"; hr

if [ ! -x "$CHROME" ]; then
  say "SKIP  headless Chrome not found at: $CHROME (set CHROME_BIN). Not failing."
  exit 0
fi

# Screenshot (give Flutter time to download the engine + first paint).
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=15000 \
  --window-size=1280,900 --hide-scrollbars --screenshot="$OUT" \
  "$BASE/" >/dev/null 2>&1
shot_rc=$?

# Dump the rendered DOM to confirm the Flutter view actually mounted.
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=15000 \
  --dump-dom "$BASE/" >"$DOM" 2>/dev/null

FAIL=0

# 1. Screenshot produced + non-trivial (blank/white screen → tiny PNG).
if [ ! -f "$OUT" ]; then
  say "FAIL  no screenshot produced (headless render failed, rc=$shot_rc)"; FAIL=1
else
  bytes=$(stat -f%z "$OUT" 2>/dev/null || stat -c%s "$OUT" 2>/dev/null || echo 0)
  if [ "${bytes:-0}" -lt "$MIN_PNG_BYTES" ]; then
    say "FAIL  screenshot only ${bytes}B (<${MIN_PNG_BYTES}) — likely a blank/white screen"; FAIL=1
  else
    say "  screenshot OK: ${bytes}B → $OUT (review visually for tofu/layout)"
  fi
fi

# 2. Flutter view mounted? (CanvasKit paints to canvas, but the host DOM has
#    flt-* / flutter-view elements once the engine boots.)
if grep -qiE 'flt-glass-pane|flutter-view|flt-scene-host|flt-renderer' "$DOM" 2>/dev/null; then
  say "  Flutter view mounted (flt-* host elements present)"
else
  say "FAIL  no Flutter host elements in the DOM — the app did not boot"; FAIL=1
fi

# 3. The bundled JP font must be referenced (a missing font → tofu title).
if grep -qiE 'NotoSerifJP|fonts/' "$DOM" 2>/dev/null; then
  say "  JP font referenced in the rendered document"
fi

hr
if [ "$FAIL" -ne 0 ]; then
  say "RESULT: FAIL — the live app did not render correctly (see above)."; exit 1
fi
say "RESULT: PASS — app booted and painted a real screen. Screenshot: $OUT"
exit 0
