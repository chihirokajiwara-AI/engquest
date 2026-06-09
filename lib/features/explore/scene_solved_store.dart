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

  /// Test seam: clear all persisted solve-state.
  static Future<void> clearForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
