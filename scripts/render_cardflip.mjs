// scripts/render_cardflip.mjs — flip a battle flashcard and screenshot the BACK,
// to verify the new ひらがな example gloss renders (the static ?preview=battle only
// shows the front). Reuses the smoke_flow semantics-tap pattern.
import { existsSync } from 'node:fs';
const H = process.env.HOME;
const pwPath = [
  process.env.PLAYWRIGHT_PATH,
  `${H}/dev/ecoauc-resale/node_modules/playwright/index.js`,
  `${H}/dev/airwork-session/node_modules/playwright/index.js`,
].find((p) => p && existsSync(p));
if (!pwPath) { console.error('SKIP: playwright not found'); process.exit(0); }
const pw = await import(pwPath);
const chromium = pw.chromium || (pw.default && pw.default.chromium);

const BASE = process.argv[2] || 'http://localhost:8099';
const OUT = '/tmp/screens/cardback.png';
const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
});
const page = await ctx.newPage();
const errs = [];
page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });

await page.goto(`${BASE}/?preview=battle`, { waitUntil: 'load', timeout: 30000 });
// Enable Flutter semantics (CanvasKit exposes the tree only after the placeholder click).
await page.waitForTimeout(3500);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForTimeout(1500);

async function labels() {
  return page.evaluate(() => {
    const host = document.querySelector('flt-semantics-host') || document;
    return [...host.querySelectorAll('flt-semantics, [role], [aria-label]')]
      .map((el) => (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '').trim())
      .filter(Boolean);
  });
}
async function clickLabel(needle) {
  const h = await page.evaluateHandle((n) => {
    const host = document.querySelector('flt-semantics-host') || document;
    for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
      const lbl = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '');
      if (lbl.includes(n)) return el;
    }
    return null;
  }, needle);
  const el = h.asElement();
  if (!el) return false;
  await el.click({ force: true }).catch(() => {});
  return true;
}

const before = await labels();
// The recall-card front is flipped by tapping the card itself (label contains
// 「めくって かくにん」). Try that, then 'こたえ', then a center-screen tap fallback.
let tapped = (await clickLabel('めくって')) || (await clickLabel('こたえ')) || (await clickLabel('みる'));
if (!tapped) { await page.mouse.click(195, 430); tapped = true; }
await page.waitForTimeout(1800);
await page.screenshot({ path: OUT });
const after = await labels();

console.log('TAPPED_CTA:', tapped);
console.log('JS_ERRORS:', errs.length);
console.log('FRONT_LABELS:', JSON.stringify(before.slice(0, 12)));
console.log('BACK_LABELS:', JSON.stringify(after.slice(0, 16)));
console.log('SCREENSHOT:', OUT);
await browser.close();
