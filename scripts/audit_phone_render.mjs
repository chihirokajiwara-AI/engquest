// scripts/audit_phone_render.mjs — #49 slice-2b: PHONE-ACCURATE render audit.
//
// audit_live_render.sh shoots headless Chrome at --window-size, which does NOT
// propagate to Flutter web's logical viewport (Flutter boots at a default ~600px
// width and ignores the OS window), so narrow-width "overflow" in that tool is a
// FALSE artifact — it cannot reproduce true phone reflow. (Verified 2026-06-12.)
//
// Playwright's device emulation sets the real visualViewport + devicePixelRatio
// that Flutter web reads at boot, so this RENDERS exactly as a phone does. Use it
// to catch genuine phone-width layout bugs (CJK clip, overflow) before a user does.
//
// Usage: NODE_PATH=$HOME/node_modules node scripts/audit_phone_render.mjs \
//          <baseUrl> <preview> [outDir]
//   e.g. ... http://localhost:8099 home /tmp
// Shoots three real phone widths (320/390/430) so reflow is visible.

// Resolve Playwright (not installed in this repo) from a known location. Browsers
// live in the shared ~/Library/Caches/ms-playwright, so any sibling install works.
import { existsSync } from 'node:fs';
const H = process.env.HOME;
const candidates = [
  process.env.PLAYWRIGHT_PATH,
  `${H}/dev/ecoauc-resale/node_modules/playwright/index.js`,
  `${H}/dev/airwork-session/node_modules/playwright/index.js`,
  `${H}/node_modules/playwright/index.js`,
].filter(Boolean);
const pwPath = candidates.find((p) => existsSync(p));
if (!pwPath) {
  console.error('SKIP: playwright not found in', candidates);
  process.exit(0);
}
const pw = await import(pwPath);
const chromium = pw.chromium || (pw.default && pw.default.chromium);

const BASE = process.argv[2] || 'http://localhost:8099';
const PREVIEW = process.argv[3] || 'home';
const OUT = process.argv[4] || '/tmp';

// Real phone CSS widths: small Android, iPhone 12/13/14, iPhone Pro Max.
const DEVICES = [
  { name: 'w320', width: 320, height: 720, dpr: 2 },
  { name: 'w390', width: 390, height: 844, dpr: 3 },
  { name: 'w430', width: 430, height: 932, dpr: 3 },
];

const browser = await chromium.launch();
let fail = 0;
for (const d of DEVICES) {
  const ctx = await browser.newContext({
    viewport: { width: d.width, height: d.height },
    deviceScaleFactor: d.dpr,
    isMobile: true,
    hasTouch: true,
  });
  const page = await ctx.newPage();
  const url = `${BASE}/?preview=${PREVIEW}`;
  await page.goto(url, { waitUntil: 'load', timeout: 30000 });
  // Give CanvasKit time to download the engine + first paint.
  await page.waitForTimeout(9000);

  // Detect horizontal overflow: does the document scroll wider than the viewport?
  const metrics = await page.evaluate(() => ({
    innerWidth: window.innerWidth,
    scrollWidth: document.documentElement.scrollWidth,
    bodyScrollWidth: document.body ? document.body.scrollWidth : 0,
  }));
  const overflow = metrics.scrollWidth - metrics.innerWidth;
  const out = `${OUT}/eq_phone_${PREVIEW}_${d.name}.png`;
  await page.screenshot({ path: out });
  const flag = overflow > 2 ? `OVERFLOW +${overflow}px` : 'ok';
  if (overflow > 2) fail = 1;
  console.log(
    `${d.name} vw=${metrics.innerWidth} scrollW=${metrics.scrollWidth} → ${flag}  ${out}`,
  );
  await ctx.close();
}
await browser.close();
process.exit(fail);
