#!/usr/bin/env bash
# scripts/audit_phone_all.sh — #49: phone-layout regression gate.
#
# Sweeps every key preview route through the PHONE-ACCURATE render audit
# (audit_phone_render.mjs, Playwright device emulation) and FAILS if any route
# has horizontal overflow at a real phone width (320/390/430 CSS px). This is the
# gate that would have caught — at build time, without a device — the class of
# "画面が画面からズレている" report the headless --window-size audit could not
# reproduce (Flutter web ignores --window-size; only true device emulation reflows).
#
# Serves build/web on a local port if no server is given. Usage:
#   scripts/audit_phone_all.sh                 # builds nothing; serves ./build/web
#   scripts/audit_phone_all.sh http://host:port [route ...]
set -u

BASE="${1:-}"
shift || true
ROUTES=("$@")
if [ "${#ROUTES[@]}" -eq 0 ]; then
  ROUTES=(home exam vocab onboarding prologue title)
fi

SERVE_PID=""
cleanup() { [ -n "$SERVE_PID" ] && kill "$SERVE_PID" 2>/dev/null; }
trap cleanup EXIT

if [ -z "$BASE" ]; then
  if [ ! -f build/web/index.html ]; then
    echo "FAIL  no build/web — run: flutter build web --release"; exit 1
  fi
  PORT=8099
  ( cd build/web && python3 -m http.server "$PORT" >/tmp/eq_phone_serve.log 2>&1 ) &
  SERVE_PID=$!
  BASE="http://localhost:$PORT"
  sleep 1.5
fi

echo "PHONE-LAYOUT GATE  base=$BASE  routes=${ROUTES[*]}"
fail=0
for r in "${ROUTES[@]}"; do
  out=$(node scripts/audit_phone_render.mjs "$BASE" "$r" /tmp 2>&1)
  if printf '%s\n' "$out" | grep -q OVERFLOW; then
    fail=1
    printf '%s\n' "$out" | grep OVERFLOW | sed "s/^/  FAIL [$r] /"
  else
    echo "  ok   [$r]"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "RESULT  FAIL — horizontal overflow at phone width (see screenshots in /tmp)"; exit 1
fi
echo "RESULT  PASS — no phone-width overflow on any route"
