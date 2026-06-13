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

// Click the MOST SPECIFIC semantic node whose stripped label contains `needle`.
// Flutter nests a full-screen container group (which contains ALL child text) over
// the real leaf widgets, so a naive "first match" clicks the whole screen at its
// centre and hits the wrong target. Prefer role=button; otherwise the smallest-area
// node — that is the actual tappable leaf, not its ancestor.
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
      // Prefer a button; among same kind prefer smaller area (the leaf).
      if ((isBtn && !bestBtn) || (isBtn === bestBtn && area < bestArea)) {
        best = el; bestArea = area; bestBtn = isBtn;
      }
    }
    return best;
  }, zwsp(needle));
  const el = handle.asElement();
  if (!el) return false;
  await el.click({ force: true }).catch(() => {});
  return true;
}

// Tap the ✕ close (an unlabeled ~40×40 button in the top-left). Click the actual
// semantic node (robust across screens/states) rather than a hardcoded coordinate.
async function tapClose() {
  const handle = await page.evaluateHandle(() => {
    const host = document.querySelector('flt-semantics-host') || document;
    let best = null, bestArea = Infinity;
    for (const el of host.querySelectorAll('flt-semantics, [role]')) {
      if (el.getAttribute('role') !== 'button') continue;
      const lbl = (el.getAttribute('aria-label') || el.textContent || '').trim();
      if (lbl.length > 3) continue; // close button has an empty/tiny label
      const r = el.getBoundingClientRect();
      if (r.x > 80 || r.y > 80) continue; // top-left region only
      const area = Math.max(1, r.width * r.height);
      if (area < bestArea) { best = el; bestArea = area; }
    }
    return best;
  });
  const el = handle.asElement();
  if (el) { await el.click({ force: true }).catch(() => {}); return true; }
  await page.mouse.click(24, 24); // fallback
  return false;
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
const okCta = await clickLabel('れんしゅう');
const examMs = okCta ? await waitForLabel('試験概要', DEAD_MS) : -1;
record('tap 英検 CTA → exam hub', examMs < 0 ? DEAD_MS : examMs, examMs >= 0,
  !okCta ? 'CTA not found' : (examMs < 0 ? 'DEAD tap (no exam screen)' : ''));

// ── exam hub → 筆記1 (大問1 vocab) → assert the active question screen ─────────
// '正答' (the score counter) appears ONLY on the live question screen, never on
// the hub button, so a match proves we actually entered the 大問.
const okSec = examMs >= 0 && await clickLabel('筆記1');
const q1Ms = okSec ? await waitForLabel('正答', DEAD_MS) : -1;
record('tap 筆記1 → 大問1 question', q1Ms < 0 ? DEAD_MS : q1Ms, q1Ms >= 0,
  !okSec ? '筆記1 not reached' : (q1Ms < 0 ? 'DEAD tap (no question screen)' : ''));

// ── answer the question → assert the 解説/reveal (the core learning moment) ────
// Tapping a choice must register and reveal the explanation + the 次へ control.
const okAns = q1Ms >= 0 && await clickLabel('1. ');
const revealMs = okAns ? await waitForLabel('次の問題へ', DEAD_MS) : -1;
record('answer → 解説 reveal', revealMs < 0 ? DEAD_MS : revealMs, revealMs >= 0,
  !okAns ? 'no choice to tap' : (revealMs < 0 ? 'DEAD tap (answer did nothing)' : ''));

// ── advance: 次の問題へ → 問2 (the in-大問 next-question transition works) ──────
const okNext = revealMs >= 0 && await clickLabel('次の問題へ');
const q2Ms = okNext ? await waitForLabel('問2', DEAD_MS) : -1;
record('次の問題へ → 問2', q2Ms < 0 ? DEAD_MS : q2Ms, q2Ms >= 0,
  !okNext ? 'no 次へ control' : (q2Ms < 0 ? 'DEAD tap (no Q2)' : ''));

// ── back-nav: tap the ✕ close (unlabeled 40×40 button top-left) → exam hub ─────
// The close has no semantic label, so tap it by position — a real pointer event to
// Flutter's glass pane. Proves the back-navigation a user relies on actually works.
if (q2Ms >= 0) await tapClose();
const backMs = q2Ms >= 0 ? await waitForLabel('試験概要', DEAD_MS) : -1;
record('✕ close → back to hub', backMs < 0 ? DEAD_MS : backMs, backMs >= 0,
  q2Ms < 0 ? 'skipped' : (backMs < 0 ? 'DEAD tap (no hub)' : ''));

// ── 筆記2 (大問2 会話文) loads + is answerable — generalises beyond 大問1 ────────
// Assert '正答' (active-question score counter) — present on the live 大問2 screen
// but NOT on the hub button (whose label merely *contains* '会話文'), avoiding the
// false-positive of matching the hub button text itself.
const okSec2 = backMs >= 0 && await clickLabel('筆記2');
const conv = okSec2 ? await waitForLabel('正答', DEAD_MS) : -1;
record('tap 筆記2 → 大問2 question', conv < 0 ? DEAD_MS : conv, conv >= 0,
  !okSec2 ? '筆記2 not reached' : (conv < 0 ? 'DEAD tap (no question screen)' : ''));
const okAns2 = conv >= 0 && await clickLabel('1. ');
const reveal2 = okAns2 ? await waitForLabel('次の問題へ', DEAD_MS) : -1;
record('筆記2 answer → reveal', reveal2 < 0 ? DEAD_MS : reveal2, reveal2 >= 0,
  !okAns2 ? 'no choice to tap' : (reveal2 < 0 ? 'DEAD tap (answer did nothing)' : ''));

// ── 筆記3 (大問3 語句の並びかえ) loads — the remaining 筆記 大問 ─────────────────
// Back to the hub, then assert the live question screen ('正答', not on the hub).
if (reveal2 >= 0) await tapClose(); // ✕ close → hub
const back2 = reveal2 >= 0 ? await waitForLabel('試験概要', DEAD_MS) : -1;
const okSec3 = back2 >= 0 && await clickLabel('筆記3');
const r3 = okSec3 ? await waitForLabel('正答', DEAD_MS) : -1;
record('tap 筆記3 → 大問3 (語句整序) loads', r3 < 0 ? DEAD_MS : r3, r3 >= 0,
  back2 < 0 ? 'no hub return' : (!okSec3 ? '筆記3 not reached' : (r3 < 0 ? 'DEAD tap (no question screen)' : '')));
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
