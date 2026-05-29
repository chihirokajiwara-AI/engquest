/* ENG Quest — Weekly XP Leaderboard (P2.8)
 *
 * MVP-grade, server-free weekly ranking. All state lives in localStorage so the
 * child can chase a target every week without any backend.
 *
 * Design:
 *   - The player's XP for the *current ISO week* is tracked in `eq_weekly_xp`,
 *     a { weekKey: xp } map. When the week rolls over the old entry stays as
 *     history but the leaderboard always reads the current week.
 *   - A small roster of persistent "rivals" (friendly named avatars) is seeded
 *     once into `eq_rivals`. Each rival earns a deterministic-but-varied amount
 *     of XP per week so there is always someone just ahead and someone just
 *     behind — the proven pattern for retention without real opponents.
 *   - The board is the player + rivals, sorted by weekly XP descending.
 *
 * This module is environment-agnostic: it accepts a `store` object that
 * implements getItem/setItem (localStorage in the browser, a stub in tests).
 *
 * Exposed as a global `EQLeaderboard` in the browser and via module.exports in
 * Node for unit testing.
 */
(function (root) {
  'use strict';

  var WEEKLY_KEY = 'eq_weekly_xp';
  var RIVALS_KEY = 'eq_rivals';
  var PLAYER_NAME = 'きみ';

  // Friendly rival roster. Each has a base weekly XP "pace" — some are easy to
  // beat, some are a stretch goal, so the player always has a target.
  var RIVAL_SEED = [
    { id: 'r_sora',  name: 'ソラ',    emoji: '🦊', pace: 120 },
    { id: 'r_hina',  name: 'ヒナ',    emoji: '🐰', pace: 85 },
    { id: 'r_riku',  name: 'リク',    emoji: '🐲', pace: 200 },
    { id: 'r_mei',   name: 'メイ',    emoji: '🐱', pace: 55 },
    { id: 'r_taiga', name: 'タイガ',  emoji: '🐯', pace: 160 },
    { id: 'r_yuki',  name: 'ユキ',    emoji: '🐧', pace: 30 }
  ];

  /** ISO-8601 week key, e.g. "2026-W22". Stable Mon–Sun boundary. */
  function isoWeekKey(date) {
    var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    var day = d.getUTCDay() || 7; // Mon=1..Sun=7
    d.setUTCDate(d.getUTCDate() + 4 - day); // nearest Thursday
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    var weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    return d.getUTCFullYear() + '-W' + (weekNo < 10 ? '0' + weekNo : '' + weekNo);
  }

  function readJSON(store, key, fallback) {
    try {
      var raw = store.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch (e) {
      return fallback;
    }
  }

  function writeJSON(store, key, value) {
    store.setItem(key, JSON.stringify(value));
  }

  /** Small deterministic hash → 0..1 so a rival's weekly XP is stable per week. */
  function seededFraction(str) {
    var h = 2166136261;
    for (var i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    // map to 0..1
    return ((h >>> 0) % 1000) / 1000;
  }

  /** Ensure the rival roster exists; returns it. */
  function getRivals(store) {
    var rivals = readJSON(store, RIVALS_KEY, null);
    if (!rivals || !Array.isArray(rivals) || rivals.length === 0) {
      rivals = RIVAL_SEED.slice();
      writeJSON(store, RIVALS_KEY, rivals);
    }
    return rivals;
  }

  /** Deterministic weekly XP for a rival: pace ± up to ~40%, stable per week. */
  function rivalWeeklyXP(rival, weekKey) {
    var frac = seededFraction(rival.id + ':' + weekKey); // 0..1
    var spread = 0.6 + frac * 0.8; // 0.6 .. 1.4
    return Math.round(rival.pace * spread);
  }

  /** Add XP to the current week's player total. Returns new weekly total. */
  function addWeeklyXP(store, amount, now) {
    now = now || new Date();
    var key = isoWeekKey(now);
    var map = readJSON(store, WEEKLY_KEY, {});
    map[key] = (map[key] || 0) + amount;
    writeJSON(store, WEEKLY_KEY, map);
    return map[key];
  }

  /** Player's XP for the current week. */
  function getPlayerWeeklyXP(store, now) {
    now = now || new Date();
    var map = readJSON(store, WEEKLY_KEY, {});
    return map[isoWeekKey(now)] || 0;
  }

  /**
   * Build the ranked board for the current week.
   * Returns array of { id, name, emoji, xp, isPlayer, rank } sorted desc.
   */
  function getLeaderboard(store, now) {
    now = now || new Date();
    var weekKey = isoWeekKey(now);
    var entries = getRivals(store).map(function (r) {
      return { id: r.id, name: r.name, emoji: r.emoji, xp: rivalWeeklyXP(r, weekKey), isPlayer: false };
    });
    entries.push({
      id: 'player',
      name: PLAYER_NAME,
      emoji: '⭐',
      xp: getPlayerWeeklyXP(store, now),
      isPlayer: true
    });
    // Sort by XP desc; ties: player wins (encouraging), then name.
    entries.sort(function (a, b) {
      if (b.xp !== a.xp) return b.xp - a.xp;
      if (a.isPlayer) return -1;
      if (b.isPlayer) return 1;
      return a.name.localeCompare(b.name);
    });
    entries.forEach(function (e, i) { e.rank = i + 1; });
    return entries;
  }

  /** XP gap to the rival immediately above the player (0 if 1st). */
  function xpToNextRank(store, now) {
    var board = getLeaderboard(store, now);
    var idx = board.findIndex(function (e) { return e.isPlayer; });
    if (idx <= 0) return 0;
    return board[idx - 1].xp - board[idx].xp;
  }

  var api = {
    WEEKLY_KEY: WEEKLY_KEY,
    RIVALS_KEY: RIVALS_KEY,
    isoWeekKey: isoWeekKey,
    getRivals: getRivals,
    rivalWeeklyXP: rivalWeeklyXP,
    addWeeklyXP: addWeeklyXP,
    getPlayerWeeklyXP: getPlayerWeeklyXP,
    getLeaderboard: getLeaderboard,
    xpToNextRank: xpToNextRank
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    root.EQLeaderboard = api;
  }
})(typeof self !== 'undefined' ? self : this);
