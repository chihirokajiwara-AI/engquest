// scripts/first_run_walkthrough.mjs — walk the REAL first-run journey as a brand
// new user from a CLEAN state, end-to-end. PHASE-AWARE: at each step it reads the
// on-screen semantics, decides which phase it's in (prologue / onboarding /
// placement / home / scene / ナゾ), takes the natural next action, screenshots,
// and logs. Captures /tmp/firstrun/NN_*.png for a diverse-values harsh panel.
//
// Usage: node scripts/first_run_walkthrough.mjs [baseUrl]   (default :8099)
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
const OUT = '/tmp/firstrun';
mkdirSync(OUT, { recursive: true });
const zwsp = (s) => (s || '').replace(/​/g, '');
const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
});
const page = await ctx.newPage();
const jsErrors = [];
page.on('pageerror', (e) => jsErrors.push(e.message.slice(0, 140)));

async function waitSel(sel, timeout) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (await page.evaluate((s) => !!document.querySelector(s), sel)) return true;
    await page.waitForTimeout(150);
  }
  return false;
}
function labels() {
  return page.evaluate(() => {
    const host = document.querySelector('flt-semantics-host') || document;
    const out = [];
    for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
      const l = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '').trim();
      if (l) out.push(l.replace(/\s+/g, ' ').slice(0, 70));
    }
    return [...new Set(out)];
  });
}
async function clickLabel(needle) {
  const n = zwsp(needle);
  const h = await page.evaluateHandle((nn) => {
    const host = document.querySelector('flt-semantics-host') || document;
    let best = null, bestArea = Infinity, bestBtn = false;
    for (const el of host.querySelectorAll('flt-semantics, [role], [aria-label]')) {
      const l = (el.getAttribute('aria-label') || el.textContent || '').replace(/​/g, '');
      if (!l.includes(nn)) continue;
      const isBtn = el.getAttribute('role') === 'button';
      const r = el.getBoundingClientRect();
      const area = Math.max(1, r.width * r.height);
      if ((isBtn && !bestBtn) || (isBtn === bestBtn && area < bestArea)) { best = el; bestArea = area; bestBtn = isBtn; }
    }
    return best;
  }, n);
  const el = h.asElement();
  if (!el) return false;
  await el.click({ force: true }).catch(() => {});
  return true;
}
const has = (ls, s) => ls.some((l) => l.includes(s));
async function tapAny(cands) { for (const c of cands) if (await clickLabel(c)) return c; return null; }

let step = 0;
async function shot(phase) {
  step++;
  await page.screenshot({ path: `${OUT}/${String(step).padStart(2, '0')}_${phase}.png` });
}

await page.goto(`${BASE}/`, { waitUntil: 'load', timeout: 30000 });
await waitSel('flt-semantics-placeholder', 25000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForTimeout(2500);

let reachedNazo = false;
let prevPhase = '';
for (let i = 0; i < 26 && !reachedNazo; i++) {
  await page.waitForTimeout(700);
  const ls = await labels();
  let phase = 'unknown', action = null;

  if (has(ls, 'まなびのとき') || has(ls, 'おぼえた') || has(ls, 'えいごで いうと')) {
    phase = 'NAZO'; reachedNazo = true;
  } else if (has(ls, 'ナゾの ぬし') || has(ls, 'ナゾを みる') || has(ls, '対決') || has(ls, 'はなしかける')) {
    phase = 'scene'; action = await tapAny(['ナゾを みる', '対決', 'ナゾの ぬし', 'はなしかける']);
  } else if (has(ls, 'Placement') || has(ls, 'えいごチェック') || has(ls, 'せんたくちゅう')) {
    // Placement quiz appeared — a real-user would answer. Tap the first choice + continue.
    phase = 'PLACEMENT';
    action = await tapAny(['せんたくちゅう', '1.', 'sun', 'are', 'read']) ||
             await tapAny(['つぎへ', 'けってい', 'すすむ', '次へ']);
  } else if (has(ls, 'ようこそ') || has(ls, 'AGE') || has(ls, 'YOUR ENGLISH') || has(ls, 'ねんれい')) {
    phase = 'ONBOARD';
    // Brand-new child: pick はじめて (never studied) then advance.
    await tapAny(['はじめて']);
    await page.waitForTimeout(250);
    action = 'はじめて+' + (await tapAny(['つぎへ', 'けってい', 'はじめる', 'すすむ', 'Next']) || '?');
  } else if (has(ls, 'はじめる / Start') || has(ls, 'つづきから') || has(ls, 'A-KEN QUEST')) {
    // TITLE screen — a brand-new user taps はじめる / Start.
    phase = 'TITLE';
    action = await tapAny(['はじめる / Start', 'はじめる', 'Start']);
  } else if (has(ls, 'ランプ') || has(ls, 'サイレント') || has(ls, 'きえた ことば') ||
             has(ls, 'スキップ') || has(ls, 'おして') || has(ls, 'きいてみよう') || has(ls, 'ともった')) {
    phase = 'PROLOGUE';
    action = await tapAny(['つぎへ', 'おして、きいてみよう', 'きいてみよう', 'おして', '▶ はじめる', 'はじめる']);
    if (!action) action = await tapAny(['スキップ']); // last resort to not stall
  } else if (has(ls, 'きょうの') || has(ls, 'ことば') || has(ls, '合格') || has(ls, 'ぼうけん') || has(ls, 'さいしょの')) {
    phase = 'HOME';
    action = await tapAny(['さいしょの', 'ことばを おぼえよう', 'きょうの ナゾ', 'ぼうけん', 'スタート', 'まなび']);
  } else {
    phase = 'unknown';
    action = await tapAny(['つぎへ', 'はじめる', '▶', 'スタート', 'OK']);
  }

  if (phase !== prevPhase) { await shot(phase); prevPhase = phase; }
  console.log(`#${i} [${phase}] action=${action || '—'} | ${ls.slice(0, 8).join(' | ')}`);
}
await shot(reachedNazo ? 'NAZO_reached' : 'END_stuck');
console.log('\nreachedNazo:', reachedNazo, '| jsErrors:', jsErrors.length, jsErrors.slice(0, 4));
await browser.close();
