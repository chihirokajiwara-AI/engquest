/* ENG Quest — Adaptive Spaced-Repetition Scheduler (web MVP)
 *
 * WHY THIS EXISTS
 * ----------------
 * The previous web scheduler used FIXED intervals (again=1min, hard=1d,
 * good=3d, easy=7d) that never grew. A word answered "good" five times in a
 * row would still resurface every 3 days forever — burning review time on
 * material the child already knows. Since the entire ENG Quest thesis is
 * "L1-L2 boundary elimination at 1/100th the cost", review efficiency *is*
 * the product. Wasted reviews = wasted minutes = a weaker cost story.
 *
 * This module implements a compact, well-understood SM-2-derived algorithm:
 *   - Each card has an `ease` factor (default 2.5, floor 1.3).
 *   - Each card has an `interval` in days that COMPOUNDS on success:
 *       repetition 1: 1 day
 *       repetition 2: ~3 days (tuned for kids; SM-2 default is 6)
 *       repetition n: round(prev_interval * ease)
 *   - "again" lapses the card: repetition -> 0, ease penalised, due in ~10 min
 *     (so a forgotten word comes back inside the same session, then graduates
 *      again). This is the key retention mechanic.
 *   - "hard" advances but with a small interval and an ease penalty.
 *   - "easy" gets an ease bonus and an extra interval multiplier.
 *
 * State shape stored per card (backward-compatible — old fields preserved):
 *   {
 *     dueDate:  ISO string,
 *     grade:    last grade key,
 *     reviews:  total reviews (kept for analytics / existing UI),
 *     ease:     ease factor (number),
 *     interval: current interval in days (number),
 *     reps:     consecutive successful reps since last lapse (number),
 *     lapses:   how many times the card was forgotten (number)
 *   }
 *
 * Environment-agnostic: pure functions over a plain card object. Exposed as a
 * global `EQSrs` in the browser and via module.exports in Node for tests.
 */
(function (root) {
  'use strict';

  var MIN_EASE = 1.3;
  var DEFAULT_EASE = 2.5;
  var MS_PER_DAY = 24 * 60 * 60 * 1000;

  // "again" brings the card back quickly but inside a realistic session window.
  var LAPSE_MINUTES = 10;

  // Ease deltas per grade (SM-2 inspired, tuned gentler for young learners).
  var EASE_DELTA = {
    again: -0.20,
    hard:  -0.15,
    good:   0.0,
    easy:  +0.15
  };

  // Interval multiplier applied on top of ease for non-standard grades.
  var HARD_INTERVAL_FACTOR = 1.2; // hard grows slowly
  var EASY_INTERVAL_BONUS = 1.3;  // easy jumps ahead

  function clampEase(e) {
    if (typeof e !== 'number' || isNaN(e)) return DEFAULT_EASE;
    return Math.max(MIN_EASE, e);
  }

  /** Round to a sane day value (>= 1 day for graduated cards). */
  function roundDays(d) {
    return Math.max(1, Math.round(d));
  }

  /**
   * Compute the next scheduling state for a card given a grade.
   *
   * @param {object|null|undefined} prev  existing card state (may be partial/legacy)
   * @param {string} gradeKey  one of again|hard|good|easy
   * @param {Date}   [now]     current time (injectable for tests)
   * @returns {object} the new card state
   */
  function schedule(prev, gradeKey, now) {
    now = now || new Date();
    prev = prev || {};

    var ease = clampEase(prev.ease);
    var reps = (typeof prev.reps === 'number' && prev.reps >= 0) ? prev.reps : 0;
    var lapses = (typeof prev.lapses === 'number') ? prev.lapses : 0;
    var prevInterval = (typeof prev.interval === 'number' && prev.interval > 0)
      ? prev.interval : 0;
    var totalReviews = (typeof prev.reviews === 'number') ? prev.reviews : 0;

    // Apply ease adjustment (clamped).
    ease = clampEase(ease + (EASE_DELTA[gradeKey] || 0));

    var intervalDays;

    if (gradeKey === 'again') {
      // Lapse: reset reps, count a lapse, short re-show inside the session.
      reps = 0;
      lapses += 1;
      intervalDays = LAPSE_MINUTES / (24 * 60); // fractional day
    } else {
      // Successful recall — advance the repetition chain.
      reps += 1;
      if (reps === 1) {
        intervalDays = 1;
      } else if (reps === 2) {
        intervalDays = 3; // kid-tuned (SM-2 uses 6)
      } else {
        var base = prevInterval > 0 ? prevInterval : 3;
        intervalDays = base * ease;
      }

      if (gradeKey === 'hard') {
        // Hard still advances but conservatively.
        intervalDays = (reps <= 2)
          ? Math.max(1, intervalDays * 0.6)
          : (prevInterval > 0 ? prevInterval : 1) * HARD_INTERVAL_FACTOR;
      } else if (gradeKey === 'easy') {
        intervalDays = intervalDays * EASY_INTERVAL_BONUS;
      }

      intervalDays = roundDays(intervalDays);
    }

    var dueMs = now.getTime() + intervalDays * MS_PER_DAY;

    return {
      dueDate: new Date(dueMs).toISOString(),
      grade: gradeKey,
      reviews: totalReviews + 1,
      ease: Math.round(ease * 1000) / 1000,
      interval: intervalDays,
      reps: reps,
      lapses: lapses
    };
  }

  /** Is this card due for review at `now`? Unseen cards are always due. */
  function isDue(card, now) {
    now = now || new Date();
    if (!card || !card.dueDate) return true;
    return new Date(card.dueDate).getTime() <= now.getTime();
  }

  /**
   * Build a study session: due review cards first, then fresh new cards, capped
   * at `count`. `state` is the { wordId: card } map.
   */
  function buildSession(words, state, count, now) {
    count = count || 10;
    now = now || new Date();
    state = state || {};

    var dueReviews = [];
    var fresh = [];
    for (var i = 0; i < words.length; i++) {
      var w = words[i];
      var card = state[w.id];
      if (!card) {
        fresh.push(w);
      } else if (isDue(card, now)) {
        dueReviews.push(w);
      }
    }

    var session = dueReviews.slice(0, count);
    if (session.length < count) {
      session = session.concat(fresh.slice(0, count - session.length));
    }

    // Never show an empty session — fall back to the first words.
    return session.length > 0 ? session : words.slice(0, count);
  }

  var api = {
    MIN_EASE: MIN_EASE,
    DEFAULT_EASE: DEFAULT_EASE,
    LAPSE_MINUTES: LAPSE_MINUTES,
    schedule: schedule,
    isDue: isDue,
    buildSession: buildSession
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    root.EQSrs = api;
  }
})(typeof self !== 'undefined' ? self : this);
