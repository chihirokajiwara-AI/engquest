// scripts/render_nazo.mjs — drive explore → NPC → ナゾ and screenshot the REAL
// NazoScreen (the explore puzzle screen). The ナゾ screen is the Layton-quality
// target (CEO 1904) but has no ?preview route, so we drive the running app via
// the Flutter semantics tree (the only way to tap CanvasKit; see smoke_flow.mjs).
//
// Usage: node scripts/render_nazo.mjs [baseUrl]   (default http://localhost:8099)
// Writes /tmp/nazo_teach.png (teach-first card) + /tmp/nazo_quiz.png (the quiz).
import { existsSync } from 'node:fs';

const H = process.env.HOME;
const pwPath = [
  `${H}/dev/ecoauc-resale/node_modules/playwright/index.js`,
  `${H}/dev/airwork-session/node_modules/playwright/index.js`,
].find(existsSync);
if (!pwPath) { console.error('SKIP: playwright not found'); process.exit(0); }
const pw = await import(pwPath);
const chromium = pw.chromium || (pw.default && pw.default.chromium);

const BASE = process.argv[2] || 'http://localhost:8099';
const zwsp = (s) => (s || '').replace(/​/g, '');
const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
});
const page = await ctx.newPage();
const jsErrors = [];
page.on('pageerror', (e) => jsErrors.push(e.message.slice(0, 160)));

async function waitForLabel(needle, timeout = 12000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const ok = await page.evaluate((n) => {
      const host = document.querySelector('flt-semantics-host') || document;
      for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
        const lbl = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '');
        if (lbl.includes(n)) return true;
      }
      return false;
    }, zwsp(needle));
    if (ok) return Date.now() - t0;
    await page.waitForTimeout(150);
  }
  return -1;
}
async function clickLabel(needle) {
  const handle = await page.evaluateHandle((n) => {
    const host = document.querySelector('flt-semantics-host') || document;
    let best = null, bestArea = Infinity, bestBtn = false;
    for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
      const lbl = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '');
      if (!lbl.includes(n)) continue;
      const isBtn = el.getAttribute('role') === 'button';
      const r = el.getBoundingClientRect();
      const area = Math.max(1, r.width * r.height);
      if ((isBtn && !bestBtn) || (isBtn === bestBtn && area < bestArea)) { best = el; bestArea = area; bestBtn = isBtn; }
    }
    return best;
  }, zwsp(needle));
  const el = handle.asElement();
  if (!el) return false;
  await el.click({ force: true }).catch(() => {});
  return true;
}
async function waitForSelector(sel, timeout) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (await page.evaluate((s) => !!document.querySelector(s), sel)) return Date.now() - t0;
    await page.waitForTimeout(150);
  }
  return -1;
}

await page.goto(`${BASE}/?preview=explore`, { waitUntil: 'load', timeout: 30000 });
await waitForSelector('flt-semantics-placeholder', 25000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
// Scene ready → tap the first unsolved NPC, then its 「ナゾをみる」 bubble.
const npc = await waitForLabel('ナゾの ぬし', 15000);
console.log('scene NPC found@', npc, 'ms');
await clickLabel('ナゾの ぬし');
const bubble = await waitForLabel('ナゾを みる', 8000);
console.log('bubble found@', bubble, 'ms');
await clickLabel('ナゾを みる');
// NazoScreen open → teach-first card present (セル has kArticleTeach).
// Teach advance button is now 「おぼえた！ ナゾへ ▶」 (retrieval-gap, 7ef8889).
const teach = await waitForLabel('おぼえた', 8000);
await page.waitForTimeout(500);
await page.screenshot({ path: '/tmp/nazo_teach.png' });
console.log('teach card@', teach, '→ /tmp/nazo_teach.png');
// Advance teach → the NEW retrieval-gap (recall) screen, then → quiz.
if (teach >= 0) {
  await clickLabel('おぼえた');
  await page.waitForTimeout(600);
  await page.screenshot({ path: '/tmp/nazo_recall.png' });
  console.log('→ /tmp/nazo_recall.png (recall cover card: EN + いみは？)');
  // Active cover-and-reveal (34a29b0): reveal the JA meaning, then advance cues.
  await clickLabel('いみは');
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/nazo_recall_revealed.png' });
  console.log('→ /tmp/nazo_recall_revealed.png (JA revealed)');
  // Walk through all cues to the quiz (reveal + つぎへ; last cue = ナゾへ).
  for (let k = 0; k < 6; k++) {
    await clickLabel('いみは');
    await clickLabel('つぎへ');
    await clickLabel('ナゾへ');
    await page.waitForTimeout(300);
  }
  await page.waitForTimeout(600);
  await page.screenshot({ path: '/tmp/nazo_quiz.png' });
  console.log('→ /tmp/nazo_quiz.png');
  // Solve (correct = 'Hello!') → ナゾ reveal (~1.4s auto-finish) → pop to scene
  // → 250ms → HELD RESTORATION HERO FRAME (scale-up 420ms + hold 900ms). Grab a
  // few frames across the hold since the exact timing varies.
  await clickLabel('Hello');
  await page.waitForTimeout(2000);
  await page.screenshot({ path: '/tmp/nazo_hero_2000.png' });
  console.log('→ /tmp/nazo_hero_2000.png');
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/nazo_hero_2500.png' });
  console.log('→ /tmp/nazo_hero_2500.png');
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/nazo_hero_3000.png' });
  console.log('→ /tmp/nazo_hero_3000.png');
  // Forward-pull beat (#3) fires AFTER hero+lore (~3000ms post-solve, dismisses
  // ~3.5s later) — grab the window: 「あと Nつ！…」 タロ companion line.
  await page.waitForTimeout(1500);
  await page.screenshot({ path: '/tmp/nazo_fwdpull_4500.png' });
  console.log('→ /tmp/nazo_fwdpull_4500.png');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: '/tmp/nazo_fwdpull_5700.png' });
  console.log('→ /tmp/nazo_fwdpull_5700.png');
}
console.log('jsErrors:', jsErrors.length, jsErrors.slice(0, 3));
await browser.close();
