// lib/features/explore/scene_solved_store.dart
//
// Persists which explorable-scene ナゾ a child has solved, so the world they
// restored (grey → colour) STAYS restored across sessions (flaw-hunt #115:
// solve-state was StatefulWidget-local only, so the village re-greyed every
// time the child came back — their win silently vanished overnight).
//
// One flat SharedPreferences string-list of "scene:idx" keys (e.g. "5:1"),
// keyed by the scene's 英検 level + the hotspot index. Pure-Dart, web-safe,
// no Firebase. Mirrors the StreakService / TaughtStore persistence pattern.

import 'package:shared_preferences/shared_preferences.dart';

class SceneSolvedStore {
  SceneSolvedStore._();

  static const _prefsKey = 'scene_solved_v1';
  static const _coinsKey = 'scene_coins_v1';
  static const _observedKey = 'scene_observed_v1';
  static const _hintsKey = 'scene_hints_v1';
  static const _minosKeyPrefix = 'scene_minos_';

  /// The solved-hotspot keys for [sceneKey] (e.g. '5') as a set of indices.
  /// Returns an empty set on any error so exploration always works.
  static Future<Set<int>> solvedIndices(String sceneKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = prefs.getStringList(_prefsKey) ?? const [];
      final prefix = '$sceneKey:';
      return all
          .where((e) => e.startsWith(prefix))
          .map((e) => int.tryParse(e.substring(prefix.length)))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  /// Mark hotspot [idx] of [sceneKey] solved (idempotent). Best-effort.
  static Future<void> markSolved(String sceneKey, int idx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
      all.add('$sceneKey:$idx');
      await prefs.setStringList(_prefsKey, all.toList());
    } catch (_) {
      // Non-fatal: the world simply won't remember this solve.
    }
  }

  // ── Collected coins ────────────────────────────────────────────────────────
  // Coin-found state must persist too, or a child can re-enter a scene and
  // re-collect the SAME coin every visit → unlimited hint coins (the exact
  // finite-economy hole R9 closed for the balance, re-opened via re-entry).

  /// The collected-coin hotspot indices for [sceneKey]. Empty set on any error.
  static Future<Set<int>> collectedCoinIndices(String sceneKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = prefs.getStringList(_coinsKey) ?? const [];
      final prefix = '$sceneKey:';
      return all
          .where((e) => e.startsWith(prefix))
          .map((e) => int.tryParse(e.substring(prefix.length)))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  /// Mark coin hotspot [idx] of [sceneKey] collected (idempotent). Best-effort.
  static Future<void> markCoinCollected(String sceneKey, int idx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = (prefs.getStringList(_coinsKey) ?? const <String>[]).toSet();
      all.add('$sceneKey:$idx');
      await prefs.setStringList(_coinsKey, all.toList());
    } catch (_) {
      // Non-fatal: at worst the coin stays collectable (degrades to old bug).
    }
  }

  // ── Investigated observations ──────────────────────────────────────────────
  // The observation hotspots carry the サイレント lore + ことばのしおり fragments
  // (the Layton density beat). Their lore banner is a 4.5s one-shot, so a child
  // who looks away misses it with no trace and no way to know a spot is unread.
  // Persist "seen" so the dot can settle to a 探偵メモ marker (?→✓) and the world
  // reads as responsive across sessions (#124).

  /// The investigated-observation hotspot indices for [sceneKey]. Empty on error.
  static Future<Set<int>> seenObservationIndices(String sceneKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = prefs.getStringList(_observedKey) ?? const [];
      final prefix = '$sceneKey:';
      return all
          .where((e) => e.startsWith(prefix))
          .map((e) => int.tryParse(e.substring(prefix.length)))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  /// Mark observation hotspot [idx] of [sceneKey] investigated (idempotent).
  static Future<void> markObservationSeen(String sceneKey, int idx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all =
          (prefs.getStringList(_observedKey) ?? const <String>[]).toSet();
      all.add('$sceneKey:$idx');
      await prefs.setStringList(_observedKey, all.toList());
    } catch (_) {
      // Non-fatal: at worst the dot stays "unread" (degrades to the old beat).
    }
  }

  // ── Unlocked hint tiers ────────────────────────────────────────────────────
  // Hint reveals are PAID (coins spent durably). The reveal used to live only in
  // NazoScreen state, so a child who bought a hint, closed the unsolved puzzle and
  // reopened it was charged again for the same hint (#155). Scene-session state
  // fixed the within-session reopen; persisting the unlocked tier here closes the
  // same finite-economy fairness hole across a full app-restart (symmetric with
  // the collected-coin persistence above — both protect a paid/finite resource).

  /// Map of hotspot idx → highest unlocked hint tier for [sceneKey]. Empty on error.
  static Future<Map<int, int>> hintTiers(String sceneKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = prefs.getStringList(_hintsKey) ?? const [];
      final prefix = '$sceneKey:';
      final out = <int, int>{};
      for (final e in all) {
        if (!e.startsWith(prefix)) continue;
        final parts = e.substring(prefix.length).split(':'); // "idx:tier"
        if (parts.length != 2) continue;
        final idx = int.tryParse(parts[0]);
        final tier = int.tryParse(parts[1]);
        if (idx == null || tier == null) continue;
        if (tier > (out[idx] ?? 0)) out[idx] = tier;
      }
      return out;
    } catch (_) {
      return <int, int>{};
    }
  }

  /// Persist that hotspot [idx] of [sceneKey] has [tier] hints unlocked. The
  /// HIGHEST tier wins — a paid-for reveal must never regress, even if a lower
  /// tier is reported later. No-op for tier <= 0. Best-effort.
  static Future<void> markHintTier(String sceneKey, int idx, int tier) async {
    if (tier <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = (prefs.getStringList(_hintsKey) ?? const <String>[]).toList();
      final entryPrefix = '$sceneKey:$idx:';
      var existing = 0;
      for (final e in all) {
        if (e.startsWith(entryPrefix)) {
          existing = int.tryParse(e.substring(entryPrefix.length)) ?? 0;
          break;
        }
      }
      if (tier <= existing) return; // keep the higher paid-for tier
      all.removeWhere((e) => e.startsWith(entryPrefix)); // one entry per idx
      all.add('$entryPrefix$tier');
      await prefs.setStringList(_hintsKey, all);
    } catch (_) {
      // Non-fatal: at worst the paid hint relocks on the next cold start.
    }
  }

  // ── Per-case ミノス record ──────────────────────────────────────────────────
  // ミノス earned in a scene session is a running reward-accumulator shown in the
  // scene header (#86). By persisting the BEST (highest) value per grade here, it
  // becomes a durable mastery record visible in the 事件簿 — not just an ephemeral
  // session number. The child's best run is kept: a re-play can never lower their
  // recorded ミノス, only improve it.

  /// Persist the ミノス total for [grade], keeping the child's BEST (highest) run.
  /// A re-play that earns fewer ミノス than the stored record is silently ignored —
  /// one bad run must never erase a peak performance. Best-effort; non-fatal.
  static Future<void> saveMinos(String grade, int minos) async {
    if (minos <= 0) return; // nothing to record yet
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_minosKeyPrefix$grade';
      final stored = prefs.getInt(key) ?? 0;
      if (minos <= stored) return; // keep the higher stored value
      await prefs.setInt(key, minos);
    } catch (_) {
      // Non-fatal: the 事件簿 ミノス chip simply won't update this run.
    }
  }

  /// Load the best-run ミノス total for [grade]. Returns 0 if absent or on error.
  static Future<int> loadMinos(String grade) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_minosKeyPrefix$grade') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Test seam: clear all persisted solve-, coin-, observation-, hint- AND minos-state.
  static Future<void> clearForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_coinsKey);
    await prefs.remove(_observedKey);
    await prefs.remove(_hintsKey);
    // Clear minos for all known grades.
    for (final g in [
      '5',
      '4',
      '3',
      'pre2',
      'pre2plus',
      '2',
      'pre1',
    ]) {
      await prefs.remove('$_minosKeyPrefix$g');
    }
  }
}
