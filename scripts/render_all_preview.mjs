// scripts/render_all_preview.mjs — screenshot EVERY ?preview= screen for the
// standing per-screen visual audit (CEO 2132: audit every page one-by-one).
// One running build serves all routes; this loads each ?preview=<route>, boots
// CanvasKit, waits for paint, and writes /tmp/screens/<route>.png.
//
// Usage: node scripts/render_all_preview.mjs [baseUrl] [comma,separated,routes]
//   default base http://localhost:8099 ; default routes = the full set below.
import { existsSync, mkdirSync } from 'node:fs';

const H = process.env.HOME;
const pwPath = [
  `${H}/dev/ecoauc-resale/node_modules/playwright/index.js`,
  `${H}/dev/airwork-session/node_modules/playwright/index.js`,
].find(existsSync);
if (!pwPath) { console.error('SKIP: playwright not found'); process.exit(0); }
const pw = await import(pwPath);
const chromium = pw.chromium || (pw.default && pw.default.chromium);

const BASE = process.argv[2] || 'http://localhost:8099';
const ALL = [
  'title', 'onboarding', 'placement', 'worldmap', 'home', 'kotobahome', 'questmap',
  'prologue1', 'prologue2', 'prologue3', 'prologue4', 'prologue5',
  'explore', 'exploresolved', 'nazo', 'chaptermap',
  'explore4', 'explore3', 'explorepre2', 'explorepre2plus', 'explore2', 'explorepre1',
  'mock', 'mockpre2plus', 'quest5', 'quest4', 'quest3', 'quest2',
  'battle', 'silentbattle', 'dialog', 'voice',
  'exam', 'exam3', 'exam4', 'exampre1', 'vocab',
  'writing', 'writing2', 'writingp1',
  'listening', 'listening4', 'listening3', 'listening2', 'listeningp2',
  'passmeter', 'passmetermissing', 'passprogress',
  'speaking', 'speakingconsent', 'achievements', 'parent', 'parentlogin', 'caselog',
  'wordorder', 'conversation', 'conversation4', 'conversationpre2',
  'reading', 'reading3', 'readingpre2', 'reading2', 'reading2fill',
];
const ROUTES = (process.argv[3] ? process.argv[3].split(',') : ALL).map((s) => s.trim()).filter(Boolean);

mkdirSync('/tmp/screens', { recursive: true });
const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
});
const page = await ctx.newPage();
const errs = {};
page.on('pageerror', (e) => { const r = page._curRoute; (errs[r] ||= []).push(e.message.slice(0, 120)); });

async function waitSel(sel, timeout) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (await page.evaluate((s) => !!document.querySelector(s), sel)) return true;
    await page.waitForTimeout(150);
  }
  return false;
}

for (const route of ROUTES) {
  page._curRoute = route;
  try {
    await page.goto(`${BASE}/?preview=${route}`, { waitUntil: 'load', timeout: 30000 });
    const booted = await waitSel('flt-semantics-placeholder', 25000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(2200); // let the specific screen paint/settle
    await page.screenshot({ path: `/tmp/screens/${route}.png` });
    const e = (errs[route] || []).length;
    console.log(`${booted ? 'OK ' : 'NOBOOT'} ${route}${e ? '  JSERR=' + e : ''} -> /tmp/screens/${route}.png`);
  } catch (err) {
    console.log(`FAIL ${route}: ${String(err).slice(0, 100)}`);
  }
}
await browser.close();
console.log('done; routes=', ROUTES.length);
