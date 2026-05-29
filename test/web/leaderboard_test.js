#!/usr/bin/env node
/* Weekly XP Leaderboard tests for ENG Quest (P2.8).
 * Run: node test/web/leaderboard_test.js
 * No external dependencies. Exits non-zero on first failure.
 */
const path = require('path');
const fs = require('fs');

const LB = require(path.join(__dirname, '..', '..', 'web', 'leaderboard.js'));

let passed = 0;
function assert(cond, msg) {
  if (!cond) {
    console.error('  \u2717 FAIL: ' + msg);
    process.exit(1);
  }
  passed++;
  console.log('  \u2713 ' + msg);
}

// In-memory localStorage stub
function makeStore(initial) {
  const data = Object.assign({}, initial);
  return {
    getItem: (k) => (k in data ? data[k] : null),
    setItem: (k, v) => { data[k] = String(v); },
    _data: data
  };
}

console.log('Leaderboard \u2014 ISO week key');
const monday = new Date(2026, 4, 25); // Mon May 25 2026
const sunday = new Date(2026, 4, 31); // Sun May 31 2026 (same ISO week)
const nextMon = new Date(2026, 5, 1); // Mon Jun 1 2026 (next ISO week)
assert(LB.isoWeekKey(monday) === LB.isoWeekKey(sunday), 'Mon and Sun of same week share a key');
assert(LB.isoWeekKey(monday) !== LB.isoWeekKey(nextMon), 'crossing into next Monday yields a new week key');
assert(/^\d{4}-W\d{2}$/.test(LB.isoWeekKey(monday)), 'week key is ISO format YYYY-Www');

console.log('Leaderboard \u2014 rival roster seeding');
const s1 = makeStore();
const rivals = LB.getRivals(s1);
assert(rivals.length >= 5, 'seeds >=5 rivals');
assert(s1.getItem(LB.RIVALS_KEY) !== null, 'persists rivals to store');
assert(rivals.every(r => r.id && r.name && r.emoji && r.pace > 0), 'each rival has id/name/emoji/pace');

console.log('Leaderboard \u2014 rival weekly XP is deterministic per week');
const wk = LB.isoWeekKey(monday);
const a = LB.rivalWeeklyXP(rivals[0], wk);
const b = LB.rivalWeeklyXP(rivals[0], wk);
assert(a === b, 'same rival + same week => identical XP (deterministic)');
const c = LB.rivalWeeklyXP(rivals[0], LB.isoWeekKey(nextMon));
assert(typeof c === 'number' && c > 0, 'XP is a positive number');
// Different rivals generally differ
const distinct = new Set(rivals.map(r => LB.rivalWeeklyXP(r, wk)));
assert(distinct.size >= 3, 'rivals produce varied XP values');

console.log('Leaderboard \u2014 player weekly XP accrual');
const s2 = makeStore();
assert(LB.getPlayerWeeklyXP(s2, monday) === 0, 'starts at 0');
LB.addWeeklyXP(s2, 30, monday);
LB.addWeeklyXP(s2, 20, sunday);
assert(LB.getPlayerWeeklyXP(s2, monday) === 50, 'accumulates within the same week (30+20=50)');
assert(LB.getPlayerWeeklyXP(s2, nextMon) === 0, 'resets to 0 in the next week');
LB.addWeeklyXP(s2, 5, nextMon);
assert(LB.getPlayerWeeklyXP(s2, nextMon) === 5, 'new week tracks independently');
assert(LB.getPlayerWeeklyXP(s2, monday) === 50, 'previous week total is preserved as history');

console.log('Leaderboard \u2014 ranking + player inclusion');
const s3 = makeStore();
const board0 = LB.getLeaderboard(s3, monday);
assert(board0.some(e => e.isPlayer), 'board always includes the player');
assert(board0.length === rivals.length + 1, 'board = rivals + player');
// ranks are 1..N contiguous and sorted desc
for (let i = 0; i < board0.length; i++) {
  assert(board0[i].rank === i + 1, 'rank ' + (i + 1) + ' assigned in order');
  if (i > 0) assert(board0[i - 1].xp >= board0[i].xp, 'sorted by XP descending');
}

console.log('Leaderboard \u2014 player can climb the board');
const s4 = makeStore();
const before = LB.getLeaderboard(s4, monday).find(e => e.isPlayer).rank;
LB.addWeeklyXP(s4, 99999, monday); // crush everyone
const after = LB.getLeaderboard(s4, monday);
assert(after[0].isPlayer && after[0].rank === 1, 'huge XP puts player at rank 1');
assert(LB.xpToNextRank(s4, monday) === 0, 'rank 1 has 0 gap to next');
assert(after.find(e => e.isPlayer).rank <= before, 'earning XP never lowers your rank');

console.log('Leaderboard \u2014 xpToNextRank reflects the gap above');
const s5 = makeStore();
const board5 = LB.getLeaderboard(s5, monday);
const meIdx = board5.findIndex(e => e.isPlayer);
if (meIdx > 0) {
  const expectedGap = board5[meIdx - 1].xp - board5[meIdx].xp;
  assert(LB.xpToNextRank(s5, monday) === expectedGap, 'gap equals XP difference to rival above');
}

console.log('Leaderboard \u2014 web wiring (index.html)');
const html = fs.readFileSync(path.join(__dirname, '..', '..', 'web', 'index.html'), 'utf8');
assert(/<script src=["']leaderboard\.js["']><\/script>/.test(html), 'index loads leaderboard.js');
assert(/id=["']leaderboard["']/.test(html), 'index has #leaderboard container');
assert(/EQLeaderboard\.addWeeklyXP/.test(html), 'addXP feeds weekly XP into leaderboard');
assert(/function renderLeaderboard\(/.test(html), 'index defines renderLeaderboard');
assert(/renderLeaderboard\(\);/.test(html), 'renderLeaderboard is invoked');

console.log('\nAll ' + passed + ' leaderboard assertions passed \u2705');
