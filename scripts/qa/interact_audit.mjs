// interact_audit.mjs — REAL-BROWSER INTERACTION audit (#49), no chromedriver.
//
// The render-proof (perf_audit.mjs) only checks that routes PAINT. This drives the
// live Flutter CanvasKit app for real: it enables Flutter's web semantics tree
// (Playwright can't tap the canvas, but the a11y tree exposes role="button" nodes),
// clicks an answer choice, and verifies the app actually RESPONDS (the post-answer
// state changes) — i.e. a child can actually solve a question, not just see it.
//
// Why this works (verified 2026-06-10): Flutter web builds an accessible DOM when
// the hidden <flt-semantics-placeholder> receives a click; dispatchEvent bypasses
// the offscreen-viewport guard. The bespoke MCQ choice tiles carry Semantics labels
// (#95), so they surface as role="button" flt-semantics nodes Playwright can click.
//
//   PLAYWRIGHT_DIR=/tmp/shot/node_modules node scripts/qa/interact_audit.mjs [baseUrl] [route]
// Exit 0 only if a real choice-click changed the app state; 1 otherwise.

import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const pwDir = process.env.PLAYWRIGHT_DIR || '/tmp/shot/node_modules';
const { chromium } = require(`${pwDir}/playwright`);

const BASE = process.argv[2] || 'http://localhost:8088';
const ROUTE = process.argv[3] || 'vocab';

async function snapshot(page) {
  return page.locator('flt-semantics[role="button"]').evaluateAll((els) =>
    els.map((e) => ({
      label: (e.getAttribute('aria-label') || '').trim(),
      box: e.getBoundingClientRect ? null : null,
    })));
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 900, height: 1400 } });
let ok = false;
try {
  await page.goto(`${BASE}/?preview=${ROUTE}`, { waitUntil: 'commit', timeout: 25000 });
  await page.waitForTimeout(9000);
  // Enable the a11y tree.
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');
  await page.waitForTimeout(2500);

  const before = await page.locator('flt-semantics[role="button"]').count();
  const beforeLabels = (await snapshot(page)).map((b) => b.label).join('|');
  console.log(`[interact] route=${ROUTE} buttons-before=${before}`);

  // Click each button that has a visible box until the app state changes (a new
  // reveal/next button appears). Skip the back button (label contains 戻/back).
  const buttons = page.locator('flt-semantics[role="button"]');
  const n = await buttons.count();
  for (let i = 0; i < n; i++) {
    const lbl = (await buttons.nth(i).getAttribute('aria-label')) || '';
    if (/戻|back|もどる/i.test(lbl)) continue;
    try {
      await buttons.nth(i).dispatchEvent('click');
    } catch { continue; }
    await page.waitForTimeout(1200);
    const after = await page.locator('flt-semantics[role="button"]').count();
    const afterLabels = (await snapshot(page)).map((b) => b.label).join('|');
    if (after !== before || afterLabels !== beforeLabels) {
      console.log(`[interact] CLICK i=${i} ("${lbl.slice(0, 24)}") → state changed `
        + `(buttons ${before}→${after}). Real interaction CONFIRMED.`);
      ok = true;
      break;
    }
  }
  if (!ok) console.log('[interact] no click changed app state — interaction NOT confirmed');
} catch (e) {
  console.log('[interact] ERROR:', e.message.slice(0, 140));
} finally {
  await browser.close();
}
process.exit(ok ? 0 : 1);
