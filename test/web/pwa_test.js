#!/usr/bin/env node
/* PWA integrity tests for ENG Quest web app (P1.4 — Offline PWA).
 * Run: node test/web/pwa_test.js
 * No external dependencies. Exits non-zero on first failure.
 */
const fs = require('fs');
const path = require('path');

const WEB = path.join(__dirname, '..', '..', 'web');
let passed = 0;
function assert(cond, msg) {
  if (!cond) {
    console.error('  ✗ FAIL: ' + msg);
    process.exit(1);
  }
  passed++;
  console.log('  ✓ ' + msg);
}
function read(rel) {
  const p = path.join(WEB, rel);
  assert(fs.existsSync(p), `file exists: web/${rel}`);
  return fs.readFileSync(p, 'utf8');
}

console.log('PWA — manifest.json');
const manifest = JSON.parse(read('manifest.json'));
assert(manifest.name && manifest.short_name, 'manifest has name + short_name');
assert(manifest.start_url === './index.html', 'manifest start_url is ./index.html');
assert(manifest.display === 'standalone', 'manifest display is standalone');
assert(manifest.theme_color === '#0F0E17', 'manifest theme_color matches brand');
assert(Array.isArray(manifest.icons) && manifest.icons.length >= 3, 'manifest declares >=3 icons');
const hasMaskable = manifest.icons.some((i) => i.purpose && i.purpose.includes('maskable'));
assert(hasMaskable, 'manifest includes a maskable icon');
for (const icon of manifest.icons) {
  assert(fs.existsSync(path.join(WEB, icon.src)), `icon asset exists: web/${icon.src}`);
}

console.log('PWA — service worker (sw.js)');
const sw = read('sw.js');
assert(/CACHE_VERSION\s*=\s*['"]/.test(sw), 'sw defines CACHE_VERSION');
assert(/addEventListener\(['"]install['"]/.test(sw), 'sw handles install event');
assert(/addEventListener\(['"]activate['"]/.test(sw), 'sw handles activate event');
assert(/addEventListener\(['"]fetch['"]/.test(sw), 'sw handles fetch event');
assert(/cache\.addAll\(/.test(sw), 'sw pre-caches app shell via addAll');
assert(/\.mp3/.test(sw), 'sw has runtime caching path for audio (.mp3)');
assert(/caches\.delete/.test(sw), 'sw cleans up stale caches on activate');
assert(/skipWaiting/.test(sw) && /clients\.claim/.test(sw), 'sw takes control immediately');

console.log('PWA — index.html wiring');
const html = read('index.html');
assert(/<link[^>]+rel=["']manifest["'][^>]+href=["']manifest\.json["']/.test(html), 'index links manifest.json');
assert(/apple-touch-icon/.test(html), 'index has apple-touch-icon for iOS install');
assert(/navigator\.serviceWorker\.register\(['"]sw\.js['"]\)/.test(html), 'index registers sw.js');
assert(/'serviceWorker'\s+in\s+navigator/.test(html), 'index feature-detects serviceWorker support');

console.log('PWA — app shell cache list resolves');
const shellMatch = sw.match(/APP_SHELL\s*=\s*\[([\s\S]*?)\]/);
assert(shellMatch, 'sw exposes APP_SHELL array');
const shellEntries = [...shellMatch[1].matchAll(/['"]([^'"]+)['"]/g)].map((m) => m[1]);
for (const entry of shellEntries) {
  if (entry === './' || entry === './index.html') continue;
  const rel = entry.replace(/^\.\//, '');
  assert(fs.existsSync(path.join(WEB, rel)), `APP_SHELL entry resolves: web/${rel}`);
}

console.log(`\nAll ${passed} PWA assertions passed.`);
