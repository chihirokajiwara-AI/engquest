#!/usr/bin/env node
/* Adaptive spaced-repetition scheduler tests for ENG Quest (web MVP).
 * Run: node test/web/srs_test.js
 * No external dependencies. Exits non-zero on first failure.
 */
const path = require('path');
const fs = require('fs');

const SRS = require(path.join(__dirname, '..', '..', 'web', 'srs.js'));

let passed = 0;
function assert(cond, msg) {
  if (!cond) {
    console.error('  \u2717 FAIL: ' + msg);
    process.exit(1);
  }
  passed++;
  console.log('  \u2713 ' + msg);
}

const DAY = 24 * 60 * 60 * 1000;
function intervalDaysOf(card, now) {
  return (new Date(card.dueDate).getTime() - now.getTime()) / DAY;
}

const NOW = new Date('2026-05-29T09:00:00Z');

console.log('SRS \u2014 new card first review');
let c = SRS.schedule(undefined, 'good', NOW);
assert(c.reps === 1, 'first good => reps=1');
assert(c.interval === 1, 'first good => 1 day interval');
assert(c.reviews === 1, 'reviews counted');
assert(c.lapses === 0, 'no lapses yet');
assert(Math.abs(intervalDaysOf(c, NOW) - 1) < 0.01, 'due ~1 day out');

console.log('SRS \u2014 intervals COMPOUND across successful reviews (the core fix)');
let card = undefined;
let last = 0;
const intervals = [];
for (let i = 0; i < 6; i++) {
  card = SRS.schedule(card, 'good', NOW);
  intervals.push(card.interval);
}
// 1, 3, then growing by ease (>= prev each step)
assert(intervals[0] === 1, 'rep1 = 1d');
assert(intervals[1] === 3, 'rep2 = 3d');
for (let i = 2; i < intervals.length; i++) {
  assert(intervals[i] > intervals[i - 1], `rep${i + 1} interval (${intervals[i]}d) > rep${i} (${intervals[i - 1]}d)`);
}
assert(intervals[5] >= 15, `by rep6 interval is large (${intervals[5]}d >= 15d) — well-known words stop wasting reviews`);

console.log('SRS \u2014 "again" lapses the card (short re-show + ease penalty)');
let strong = undefined;
for (let i = 0; i < 4; i++) strong = SRS.schedule(strong, 'good', NOW);
const easeBefore = strong.ease;
const lapsed = SRS.schedule(strong, 'again', NOW);
assert(lapsed.reps === 0, 'again resets reps to 0');
assert(lapsed.lapses === 1, 'again increments lapses');
assert(lapsed.ease < easeBefore, 'again penalises ease');
assert(intervalDaysOf(lapsed, NOW) < 0.02, 'again re-shows within ~10 min (same session)');

console.log('SRS \u2014 "easy" outpaces "good" outpaces "hard"');
const baseCard = SRS.schedule(SRS.schedule(undefined, 'good', NOW), 'good', NOW); // reps=2, interval=3
const easy = SRS.schedule(baseCard, 'easy', NOW);
const good = SRS.schedule(baseCard, 'good', NOW);
const hard = SRS.schedule(baseCard, 'hard', NOW);
assert(easy.interval > good.interval, `easy (${easy.interval}d) > good (${good.interval}d)`);
assert(good.interval > hard.interval, `good (${good.interval}d) > hard (${hard.interval}d)`);
assert(easy.ease > good.ease, 'easy raises ease above good');
assert(hard.ease < good.ease, 'hard lowers ease below good');

console.log('SRS \u2014 ease never drops below the floor');
let punished = undefined;
for (let i = 0; i < 20; i++) punished = SRS.schedule(punished, 'again', NOW);
assert(punished.ease >= SRS.MIN_EASE - 1e-9, `ease floored at ${SRS.MIN_EASE} (got ${punished.ease})`);

console.log('SRS \u2014 isDue');
const future = { dueDate: new Date(NOW.getTime() + 5 * DAY).toISOString() };
const past = { dueDate: new Date(NOW.getTime() - 5 * DAY).toISOString() };
assert(SRS.isDue(undefined, NOW) === true, 'unseen card is always due');
assert(SRS.isDue(past, NOW) === true, 'overdue card is due');
assert(SRS.isDue(future, NOW) === false, 'future card is not due');

console.log('SRS \u2014 buildSession prioritises due reviews, then new cards, capped');
const words = [];
for (let i = 1; i <= 20; i++) words.push({ id: 'w' + i, word: 'word' + i });
const state = {
  w1: past, w2: past, w3: past,          // 3 due reviews
  w10: future, w11: future                // 2 not-due (should be skipped)
};
const sess = SRS.buildSession(words, state, 10, NOW);
assert(sess.length === 10, 'session capped at 10');
const ids = sess.map(w => w.id);
assert(ids.slice(0, 3).every(id => ['w1', 'w2', 'w3'].includes(id)), 'due reviews come first');
assert(!ids.includes('w10') && !ids.includes('w11'), 'not-due cards are excluded');
const newIncluded = ids.filter(id => !state[id]);
assert(newIncluded.length === 7, 'remaining 7 slots filled with new cards');

console.log('SRS \u2014 buildSession never returns empty');
const allFuture = {};
words.forEach(w => { allFuture[w.id] = future; });
const fallback = SRS.buildSession(words, allFuture, 10, NOW);
assert(fallback.length > 0, 'falls back to first words when nothing is due');

console.log('SRS \u2014 legacy card state upgrades cleanly');
const legacy = { dueDate: new Date(NOW.getTime() - DAY).toISOString(), grade: 'good', reviews: 4 };
const upgraded = SRS.schedule(legacy, 'good', NOW);
assert(typeof upgraded.ease === 'number' && upgraded.ease >= SRS.MIN_EASE, 'legacy card gains an ease factor');
assert(upgraded.reviews === 5, 'legacy review count is preserved and incremented');
assert(upgraded.reps === 1, 'legacy card (no reps field) starts a fresh rep chain');

console.log('SRS \u2014 web wiring (index.html)');
const html = fs.readFileSync(path.join(__dirname, '..', '..', 'web', 'index.html'), 'utf8');
assert(/<script src=["']srs\.js["']><\/script>/.test(html), 'index loads srs.js');
assert(/EQSrs\.schedule/.test(html), 'gradeCard uses EQSrs.schedule');
assert(/EQSrs\.buildSession/.test(html), 'getSessionCards uses EQSrs.buildSession');
assert(!/const GRADE_INTERVALS = \{ again: 1\/1440, hard: 1, good: 3, easy: 7 \};\n\nfunction gradeCard/.test(html),
  'old fixed-interval GRADE_INTERVALS scheme removed from main path');

console.log('\nAll ' + passed + ' SRS assertions passed \u2705');
