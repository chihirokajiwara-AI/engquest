// scripts/boot_timeline.mjs — measure the REAL first-run boot sequence, precisely.
//
// CEO 2236: do NOT ask the user what they saw — measure it. This drives the app
// ROOT (no ?preview, so the real _AppEntryPoint boot routing runs), captures a
// screenshot timeline at fixed wall-clock marks, timestamps each phase via the
// Flutter semantics tree, and dumps localStorage so we learn the exact
// shared_preferences encoding (to reproduce the skip-title state precisely).
//
// Usage: node scripts/boot_timeline.mjs [baseUrl] [state]
//   state = fresh (default, empty storage) | seed:'k=v;k2=v2' (raw localStorage)
//   Screenshots → /tmp/boot/<state>_<ms>.png ; milestones + storage → stdout.

import { existsSync, mkdirSync } from 'node:fs';
const H = process.env.HOME;
const pwPath = [
  process.env.PLAYWRIGHT_PATH,
  `${H}/dev/ecoauc-resale/node_modules/playwright/index.js`,
  `${H}/dev/airwork-session/node_modules/playwright/index.js`,
].filter(Boolean).find((p) => existsSync(p));
if (!pwPath) { console.error('SKIP: playwright not found'); process.exit(0); }
const pw = await import(pwPath);
const chromium = pw.chromium || (pw.default && pw.default.chromium);

const BASE = process.argv[2] || 'http://178.105.113.79:8088';
const STATE = process.argv[3] || 'fresh';
const OUT = '/tmp/boot';
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
  isMobile: true, hasTouch: true,
});

// Seed localStorage BEFORE any app script runs (addInitScript runs pre-page-JS
// on every navigation in this context). origin must match BASE.
if (STATE.startsWith('seed:')) {
  const pairs = STATE.slice(5).split(';').filter(Boolean).map((p) => {
    const i = p.indexOf('='); return [p.slice(0, i), p.slice(i + 1)];
  });
  await ctx.addInitScript((kv) => {
    for (const [k, v] of kv) localStorage.setItem(k, v);
  }, pairs);
}

const page = await ctx.newPage();
const jsErrors = [];
page.on('console', (m) => { if (m.type() === 'error') jsErrors.push(m.text().slice(0, 160)); });
page.on('pageerror', (e) => jsErrors.push('pageerror: ' + e.message.slice(0, 160)));

const t0 = Date.now();
const now = () => Date.now() - t0;
const shots = [];
async function shot(tag) {
  const ms = now();
  const f = `${OUT}/${STATE.replace(/[^a-z0-9]/gi, '_')}_${String(ms).padStart(5, '0')}_${tag}.png`;
  await page.screenshot({ path: f }).catch(() => {});
  shots.push(`${ms}ms ${tag} → ${f}`);
}

async function hasLabel(needle) {
  return page.evaluate((n) => {
    const host = document.querySelector('flt-semantics-host') || document;
    for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
      const lbl = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '');
      if (lbl.includes(n)) return true;
    }
    return false;
  }, needle).catch(() => false);
}
async function waitLabel(needle, timeout = 15000) {
  const s = Date.now();
  while (Date.now() - s < timeout) {
    if (await hasLabel(needle)) return now();
    await page.waitForTimeout(80);
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
  }, needle);
  const el = handle.asElement();
  if (!el) return false;
  await el.click({ force: true }).catch(() => {});
  return true;
}

console.log(`BOOT TIMELINE  base=${BASE}  state=${STATE}`);
await page.goto(`${BASE}/`, { waitUntil: 'load', timeout: 30000 });

// Engine boot = the a11y placeholder exists; click it to build the semantics DOM.
let engineMs = -1;
{
  const s = Date.now();
  while (Date.now() - s < 25000) {
    const ok = await page.evaluate(() => !!document.querySelector('flt-semantics-placeholder'));
    if (ok) { engineMs = now(); await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); break; }
    await page.waitForTimeout(60);
  }
}

// Fixed wall-clock screenshot timeline (ground truth of what's on screen when).
const marks = [600, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000];
let mi = 0;
// Milestone polls run concurrently with the timeline.
const titleP = waitLabel('はじめる', 15000);
const prologueNeedle = 'きいてみよう';
for (const m of marks) {
  while (now() < m) await page.waitForTimeout(40);
  await shot(`t${m}`);
  mi++;
}
const titleMs = await titleP;
// Classify the FIRST interactive screen by UNIQUE needles (NOT 'はじめる' — the
// home hub has its own start CTA containing はじめる, which false-positives as
// "title"). The de-DQ title (3462f39) uniquely shows the '未解決事件' case-file
// plate; the prologue uniquely shows 'きいてみよう'; neither ⟹ the home hub.
const titleVisible = await hasLabel('未解決事件');
const prologueVisibleEarly = await hasLabel(prologueNeedle);
const firstScreen = titleVisible ? 'TITLE (未解決事件 present)'
  : prologueVisibleEarly ? 'PROLOGUE (title SKIPPED)'
  : 'HOME / other (no title, no prologue)';

// If the title is present, tap はじめる and measure the cross-fade → prologue.
let tapTitleAt = -1, prologueMs = -1;
if (titleVisible) {
  tapTitleAt = now();
  await clickLabel('はじめる');
  prologueMs = await waitLabel(prologueNeedle, 8000);
  await shot('after_start');
}

// Dump the persisted state so we learn the exact encoding for the skip path.
const storage = await page.evaluate(() => {
  const o = {};
  for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); o[k] = localStorage.getItem(k); }
  return o;
});

console.log(`  engine boot (placeholder)      : ${engineMs}ms`);
console.log(`  title interactive (はじめる)     : ${titleMs}ms  visible=${titleVisible}`);
console.log(`  prologue CTA early (きいてみよう) : earlyVisible=${prologueVisibleEarly}`);
console.log(`  FIRST SCREEN                   : ${firstScreen}`);
if (tapTitleAt >= 0) console.log(`  tapped はじめる @${tapTitleAt}ms → prologue painted @${prologueMs >= 0 ? prologueMs + 'ms' : 'NOT FOUND'} (Δ ${prologueMs >= 0 ? prologueMs - tapTitleAt : '?'}ms cross-fade)`);
console.log(`  jsErrors=${jsErrors.length}`); jsErrors.slice(0, 5).forEach((e) => console.log('    ' + e));
console.log('  --- screenshot timeline ---'); shots.forEach((s) => console.log('  ' + s));
console.log('  --- localStorage ---'); for (const [k, v] of Object.entries(storage)) console.log(`  ${k} = ${String(v).slice(0, 60)}`);
await browser.close();
