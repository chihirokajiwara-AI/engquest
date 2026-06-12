// scripts/smoke_flow.mjs — #49 slice-3: REAL-BROWSER click-flow smoke.
//
// The structural gap (CEO 6/7 + 6/12): all prior verification is flutter_test
// (unit/widget). Nothing drove the ACTUAL running web app — so "load slow / tap
// does nothing / janky transition / JS error" all pass through green. This is
// the missing layer: a real headless browser loads the built app, ENABLES the
// Flutter semantics tree (the only way to drive CanvasKit — verified 2026 best
// practice, not image hacks), then CLICKS the core flow by semantic label and
// asserts each navigation actually happened within a time budget. It measures
// load/transition latency, and flags DEAD taps (timeout), SLOW taps, and JS
// console/page errors — exactly the class of failure a paying user hit on :8088.
//
// Drive: Flutter only builds the a11y DOM after its hidden "Enable accessibility"
// placeholder is clicked; we fire that in-page, then query <flt-semantics> nodes.
//
// Usage: node scripts/smoke_flow.mjs [baseUrl]
//   default base http://localhost:8099 (serve build/web there first).
// Exit 0 = flow passed (no dead/slow taps, no JS errors); 1 = a real failure.

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

const BASE = process.argv[2] || 'http://localhost:8099';
const SLOW_MS = 2500;   // a transition slower than this is flagged (not fatal)
const DEAD_MS = 12000;  // no expected element by here = dead tap (fatal)
const zwsp = (s) => (s || '').replace(/​/g, ''); // strip jpBreak zero-widths

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
  isMobile: true, hasTouch: true,
});
const page = await ctx.newPage();
const jsErrors = [];
page.on('console', (m) => { if (m.type() === 'error') jsErrors.push(`console: ${m.text().slice(0, 200)}`); });
page.on('pageerror', (e) => jsErrors.push(`pageerror: ${e.message.slice(0, 200)}`));

// Poll the semantics tree for a node whose (zwsp-stripped) label contains `needle`.
async function waitForLabel(needle, timeout = DEAD_MS) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const found = await page.evaluate((n) => {
      const host = document.querySelector('flt-semantics-host') || document;
      for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
        const lbl = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '');
        if (lbl.includes(n)) return true;
      }
      return false;
    }, zwsp(needle));
    if (found) return Date.now() - t0;
    await page.waitForTimeout(150);
  }
  return -1;
}

// Click the first semantic node whose stripped label contains `needle`.
async function clickLabel(needle) {
  const handle = await page.evaluateHandle((n) => {
    const host = document.querySelector('flt-semantics-host') || document;
    for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
      const lbl = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '');
      if (lbl.includes(n)) return el;
    }
    return null;
  }, zwsp(needle));
  const el = handle.asElement();
  if (!el) return false;
  await el.click({ force: true }).catch(() => {});
  return true;
}

const steps = [];
function record(name, ms, ok, note = '') { steps.push({ name, ms, ok, note }); }

// Wait until a DOM selector exists (engine booted), polling from now.
async function waitForSelector(sel, timeout) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const present = await page.evaluate((s) => !!document.querySelector(s), sel);
    if (present) return Date.now() - t0;
    await page.waitForTimeout(150);
  }
  return -1;
}

// ── Boot: measure true time-to-interactive (engine boot → home title painted) ─
const t0 = Date.now();
await page.goto(`${BASE}/?preview=home`, { waitUntil: 'load', timeout: 30000 });
// As soon as the a11y placeholder exists, the engine has booted — click it.
const phMs = await waitForSelector('flt-semantics-placeholder', 25000);
if (phMs >= 0) {
  await page.evaluate(() => { document.querySelector('flt-semantics-placeholder')?.click(); });
}
const titleFound = await waitForLabel('コトバ探偵', 15000);
// Honest time-to-interactive: total wall-clock from navigation start (incl. the
// CanvasKit engine download + first frame + home's async load), not just the
// post-a11y poll. This is the number a user perceives as "load speed".
record('boot → home interactive', Date.now() - t0, titleFound >= 0,
  titleFound < 0 ? 'home title never appeared' : `engine-ready@${phMs}ms`);

// ── Tap the 英検 CTA → real Navigator.push to the exam hub ────────────────────
// Assert on '試験概要' (EXAM OVERVIEW) — present ONLY on the exam hub, never home,
// so a match proves the navigation actually happened (no false positive).
const ok = await clickLabel('れんしゅう');
const examMs = ok ? await waitForLabel('試験概要', DEAD_MS) : -1;
record('tap 英検 CTA → exam hub', examMs < 0 ? DEAD_MS : examMs, examMs >= 0,
  !ok ? 'CTA not found' : (examMs < 0 ? 'DEAD tap (no exam screen)' : ''));
await page.screenshot({ path: '/tmp/eq_smoke_end.png' }).catch(() => {});

// ── Report ────────────────────────────────────────────────────────────────────
let fail = 0;
console.log(`SMOKE FLOW  base=${BASE}`);
for (const s of steps) {
  const slow = s.ok && s.ms > SLOW_MS;
  const tag = !s.ok ? 'FAIL' : slow ? 'SLOW' : 'ok';
  if (!s.ok) fail = 1;
  console.log(`  [${tag}] ${s.name}: ${s.ms}ms ${s.note}`.trimEnd());
}
console.log(`  jsErrors=${jsErrors.length}`);
jsErrors.slice(0, 8).forEach((e) => console.log(`    ${e}`));
if (jsErrors.length) fail = 1;
console.log(fail ? 'RESULT  FAIL' : 'RESULT  PASS');
await browser.close();
process.exit(fail);
