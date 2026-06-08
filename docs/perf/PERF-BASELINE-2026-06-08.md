# Perf baseline — 2026-06-08 (real-browser load audit, #49)

Tool: `scripts/qa/perf_audit.mjs` (Chromium, measures the `flutter-first-frame`
window event from navigation start; flags broken routes, over-budget routes, and
asset-load 404s = tofu/blank). This IS the standing #49 load-time audit — run it
every Commercial Quality Audit cadence (§H) and before shipping any perf-relevant
change:

```
node scripts/qa/perf_audit.mjs http://178.105.113.79:8088 4000
```

## Measured (live demo, 2026-06-08)
- **54/54 routes render. 0 broken. 0 asset-load failures (no tofu/404).** ✅
- Warm per-route first-frame: **~1.75–1.90s** (acceptable). ✅
- **COLD boot (title, no cache): ~6.6–7.0s — OVER the 4000ms budget.** ❌ (the one
  failing metric)

## Cold-boot bottleneck (diagnosis)
Not a code/asset bug (render is clean, gzip IS on). It is transport:
- `main.dart.js` = **3.8 MB** on disk, served **gzip** (~1 MB transfer). The server
  offers gzip but **NOT brotli** (a `br,gzip` request still returns gzip).
- Served from a **single-origin Hetzner VPS in Germany** with no edge/CDN. For the
  product's Japanese users that is a long-haul fetch (the same reason
  `build_web.sh` deliberately keeps canvaskit on the gstatic CDN — self-hosting
  canvaskit from this VPS measured ~9× slower).
- So the cold first-time visitor waits ~7s (behind the #18 loading splash, not a
  blank); returning/cached visitors get ~2s.

## Lever (ESCALATED — infra, not a Flutter code change)
The fix is transport, which I will not change unilaterally (prod nginx config +
the untracked :8088 nginx block, #51; and #48's "how to serve heavy assets"):
1. **brotli** for `main.dart.js`/JS (nginx `brotli_static on` + precompressed
   `.br`) — ~15–20% smaller than gzip on JS.
2. **A JP-reachable edge/CDN** for `main.dart.js` (as already done for canvaskit
   via gstatic) — removes the Germany long-haul for JP users.
Either materially cuts the ~7s cold boot. Both are infra/ops decisions (CEO).

Code-side options considered and NOT taken (rework/risk, no clean win): deferred
route loading to shrink main.dart.js (big refactor, Flutter-web caveats);
switching renderer / dart2wasm (build_web.sh already measured canvaskit+gstatic as
the fast path; changing it risks a regression).
