// scripts/capture_screens.mjs — REAL-RENDER visual QA (CEO 1612).
//
// Quality/rubric scores must be backed by a real render of the CURRENT code, not
// paper, not the stale :8088, not flutter_test (which never paints the app). This
// drives the built app in a real headless browser and screenshots each ?preview=
// route AFTER it actually paints — so a human / the loop's art-QA eye can judge
// real visual quality (tofu, layout, art cohesion, "is it attractive").
//
// Usage:
//   1. build:  scripts/safe-job.sh webbuild 600 flutter build web --release
//   2. serve:  python3 -m http.server 8099 --directory build/web &
//   3. capture: node scripts/capture_screens.mjs [baseUrl] [route:out ...]
//        default base http://localhost:8099
//        default routes: kotobahome→/tmp/cap_home.png, explore→/tmp/cap_scene.png
//
// Preview routes (lib/app.dart): kotobahome, explore / explore4 / explore3 /
//   explorepre2 / explorepre2plus / explore2 / explorepre1 (the per-grade
//   SceneViews), mock, prologue1/2/5, passmeter, kotobahome, …

import { existsSync } from 'node:fs';
const H = process.env.HOME;
const pwPath = [
  process.env.PLAYWRIGHT_PATH,
  `${H}/dev/ecoauc-resale/node_modules/playwright/index.js`,
  `${H}/dev/airwork-session/node_modules/playwright/index.js`,
].filter(Boolean).find((p) => existsSync(p));
if (!pwPath) { console.error('SKIP: playwright not found'); process.exit(0); }
const pw = await import(pwPath);
const chromium = pw.chromium || (pw.default && pw.default.chromium);

const args = process.argv.slice(2);
const BASE = (args[0] && args[0].startsWith('http')) ? args.shift() : 'http://localhost:8099';
const pairs = args.length
  ? args.map((a) => { const [r, o] = a.split(':'); return { route: r, out: o || `/tmp/cap_${r}.png` }; })
  : [{ route: 'kotobahome', out: '/tmp/cap_home.png' },
     { route: 'explore', out: '/tmp/cap_scene.png' }];

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
  isMobile: true, hasTouch: true,
});
const page = await ctx.newPage();

async function waitSel(sel, ms) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    if (await page.evaluate((s) => !!document.querySelector(s), sel)) return true;
    await page.waitForTimeout(150);
  }
  return false;
}

let fail = 0;
for (const { route, out } of pairs) {
  await page.goto(`${BASE}/?preview=${route}`, { waitUntil: 'load', timeout: 30000 });
  // Drive CanvasKit: click the hidden a11y placeholder so the app paints + the
  // semantics tree builds (verified 2026 best practice for headless Flutter web).
  const booted = await waitSel('flt-semantics-placeholder', 25000);
  if (booted) await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(4000); // let the scene fully paint (saturation, art, banner)
  await page.screenshot({ path: out });
  // A real render is large; a tiny PNG (~boot splash) means it didn't paint.
  const sz = (await import('node:fs')).statSync(out).size;
  const ok = booted && sz > 60000;
  if (!ok) fail++;
  console.log(`${ok ? 'OK ' : 'FAIL'}  ${route} → ${out}  (booted=${booted}, ${sz}B)`);
}
await browser.close();
console.log(fail ? `DONE with ${fail} unpainted` : 'DONE — all rendered');
process.exit(fail ? 1 : 0);
