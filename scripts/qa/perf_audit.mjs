// scripts/qa/perf_audit.mjs — standing real-browser load-time + render-health audit.
//
// Answers the CEO's "is page-load speed / are broken screens in the loop's audit?"
// (msgs 767/769/770) with MEASURED data: drives every ?preview route on the LIVE
// demo in a real browser (Chromium) and records boot→first-frame time + flags
// routes that never render (blank/broken — the #24 crash class) or exceed a
// load-time budget.
//
// Flutter web is CanvasKit (no DOM widgets), so we measure the engine signal:
// the `flutter-first-frame` window event (timed from navigation start). Each
// ?preview route is a full app boot, so this captures per-screen cold render.
//
// Usage:
//   PLAYWRIGHT_DIR=/tmp/shot/node_modules node scripts/qa/perf_audit.mjs [baseUrl] [budgetMs]
// Defaults: baseUrl=http://178.105.113.79:8088  budgetMs=4000
// Exit 0 only if all routes render under budget AND no asset (image/font) 404s
// or fails to load; 1 if any route is broken, over budget, or has a failed asset.

import { readFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { createRequire } from 'node:module';

const __dir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dir, '..', '..');
const BASE = process.argv[2] || 'http://178.105.113.79:8088';
const BUDGET_MS = Number(process.argv[3] || 4000);
const FF_TIMEOUT_MS = 30000;
const OUT_DIR = '/tmp/perf_audit';

// Resolve playwright from PLAYWRIGHT_DIR (or the shot-tool install) so this runs
// without adding a node toolchain to the Flutter repo.
const pwDir = process.env.PLAYWRIGHT_DIR || '/tmp/shot/node_modules';
// playwright exposes `chromium` via a getter on its CJS export (not an enumerable
// ESM named export), so load it through require.
const { chromium } = createRequire(import.meta.url)(`${pwDir}/playwright`);

// Keep the route list in sync with the app by parsing kPreviewRouteNames.
function previewRoutes() {
  const src = readFileSync(resolve(repoRoot, 'lib/app.dart'), 'utf8');
  const m = src.match(/kPreviewRouteNames\s*=\s*\[([\s\S]*?)\];/);
  if (!m) throw new Error('could not parse kPreviewRouteNames from lib/app.dart');
  return [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]);
}

async function measure(context, route) {
  const page = await context.newPage();
  // Record performance.now() at the moment Flutter paints its first frame.
  await page.addInitScript(() => {
    window.__ff = undefined;
    window.addEventListener('flutter-first-frame', () => {
      window.__ff = performance.now();
    });
  });

  // ASSET-LOAD HEALTH (closes the audit gap CEO flagged 2026-06-07): a screen
  // can fire flutter-first-frame yet be visibly broken — missing images, or a
  // failed font fetch that leaves every Japanese glyph as tofu (□). "first frame
  // fired" is NOT "readable". So we watch the network and flag any asset that
  // 404s or fails to load. CanvasKit fetches images/fonts/manifests as
  // fetch/xhr, so HTTP status is the reliable signal (the DOM has no <img>).
  const ASSET_TYPES = new Set([
    'image', 'font', 'stylesheet', 'script', 'fetch', 'xhr', 'media',
  ]);
  const assetFailures = [];
  page.on('response', (r) => {
    try {
      if (r.status() >= 400 && ASSET_TYPES.has(r.request().resourceType())) {
        assetFailures.push({ url: r.url(), status: String(r.status()) });
      }
    } catch (_) {}
  });
  page.on('requestfailed', (r) => {
    try {
      if (ASSET_TYPES.has(r.resourceType())) {
        assetFailures.push({ url: r.url(), status: `FAILED:${r.failure()?.errorText || '?'}` });
      }
    } catch (_) {}
  });

  const url = `${BASE}/?preview=${route}`;
  let ms = null;
  let firstFrame = false;
  try {
    await page.goto(url, { waitUntil: 'commit', timeout: FF_TIMEOUT_MS });
    await page.waitForFunction(() => window.__ff !== undefined, { timeout: FF_TIMEOUT_MS });
    ms = Math.round(await page.evaluate(() => window.__ff));
    firstFrame = true;
    // Give late asset fetches (images/fonts pulled after first frame) a moment
    // to resolve so their 404s are captured, not missed by an early close.
    await page.waitForTimeout(1500);
  } catch (_) {
    firstFrame = false; // never rendered within timeout → broken/blank
  }
  try {
    await page.screenshot({ path: `${OUT_DIR}/${route}.png` });
  } catch (_) {}
  await page.close();
  // De-dup identical URL+status (CanvasKit may retry).
  const seen = new Set();
  const failures = assetFailures.filter((f) => {
    const k = `${f.status} ${f.url}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
  return { route, ms, firstFrame, failures };
}

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });
  const routes = previewRoutes();
  console.log(`PERF AUDIT — ${BASE} — ${routes.length} routes — budget ${BUDGET_MS}ms`);
  const browser = await chromium.launch();
  // Cold boot: fresh context (no cache) for the very first paint.
  const cold = await browser.newContext();
  const coldRes = await measure(cold, 'title');
  await cold.close();
  console.log(`COLD boot (title, no cache): ${coldRes.firstFrame ? coldRes.ms + 'ms' : 'NO FIRST FRAME'}`);

  // Warm per-route: shared context (HTTP cache warm) → per-screen re-render cost.
  const ctx = await browser.newContext();
  const results = [];
  for (const r of routes) {
    results.push(await measure(ctx, r));
  }
  await ctx.close();
  await browser.close();

  const broken = results.filter((r) => !r.firstFrame);
  const slow = results.filter((r) => r.firstFrame && r.ms > BUDGET_MS);
  const withFailures = results.filter((r) => (r.failures || []).length > 0);
  results.filter((r) => r.firstFrame).sort((a, b) => b.ms - a.ms)
    .forEach((r) => console.log(`${String(r.ms).padStart(6)}ms  ${r.route}`));
  if (broken.length) console.log(`\nBROKEN (no first-frame): ${broken.map((r) => r.route).join(', ')}`);
  if (slow.length) console.log(`OVER BUDGET (>${BUDGET_MS}ms): ${slow.map((r) => `${r.route}(${r.ms})`).join(', ')}`);
  if (withFailures.length) {
    // Aggregate the distinct broken asset URLs across all routes (one bad
    // shared asset — e.g. the font — shows on many routes; list it once).
    const byUrl = new Map();
    for (const r of withFailures) {
      for (const f of r.failures) {
        const e = byUrl.get(f.url) || { status: f.status, routes: new Set() };
        e.routes.add(r.route);
        byUrl.set(f.url, e);
      }
    }
    console.log(`\nASSET-LOAD FAILURES (missing image / failed font = tofu/blank):`);
    for (const [url, e] of byUrl) {
      const short = url.replace(BASE, '');
      console.log(`  [${e.status}] ${short}  (${e.routes.size} route${e.routes.size > 1 ? 's' : ''})`);
    }
  }
  const ok = results.filter((r) => r.firstFrame).length;
  console.log(`\nSUMMARY: ${ok}/${results.length} rendered; ${broken.length} broken; ${slow.length} over budget; ${withFailures.length} with asset-load failures; cold=${coldRes.ms ?? 'n/a'}ms`);
  process.exit(broken.length || slow.length || withFailures.length ? 1 : 0);
}

main().catch((e) => { console.error('perf_audit error:', e); process.exit(2); });
