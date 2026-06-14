// AUTONOMOUS COMPOSITION AUDIT (CEO 1583 — "ゲーム構成の自律監査はあるか").
//
// COMPOSITION-ARCHITECTURE.md is FROZEN (CEO msg 863) but, until now, only PROSE
// + a manual scorecard re-score + a couple of mechanic tests guarded it. Nothing
// AUTO-enforced the load-bearing structural invariants, so the composition could
// silently drift back toward the DQ-hybrid warp the spec corrected. This test
// makes the frozen spec SELF-ENFORCING: a drift away from lean-Layton turns a
// test red instead of shipping quietly. Pure data assertions — no rendering.
//
// Invariants locked (with the spec section each comes from):
//   §1 / §7.3 / §8  the painted SCENE is always the spine — EVERY grade has a
//                   SceneDef, so the home CTA never falls back to the level map.
//   §1             a chapter = one scene with 2–5 ナゾ (英検 items) + the hidden
//                   声の石 (coin) payoff.
//   §7.6           the royalty/conquest thread is REMOVED — the "mandatory
//                   post-edit leakage grep stays in force", now as a real test
//                   over the SHIPPED scene strings (not comments).

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/explore/hotspot.dart';

/// The seven 事件簿 the frozen spec names (§1): 5 → 4 → 3 → 準2 → 準2プラス → 2 → 準1.
/// Hard-coded from the spec (NOT read back from kScenesByGrade) so a removed or
/// renamed scene is actually caught.
const _expectedGrades = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];

/// Royalty / conquest vocabulary the spec removed (§7.6). Japanese kanji match
/// directly; English uses word boundaries so "their" never trips "heir".
final _royaltyJa = ['王様', '王子', '王女', '王都', '王国', '女王', '王家', '👑'];
final _royaltyEn = RegExp(
  r'\b(king|queen|prince|princess|throne|royal|royalty|kingdom|heir)\b',
  caseSensitive: false,
);

/// All player-facing narrative strings of a scene (where a royalty leak would
/// surface): the case title, the cleared line, スラ's arrival, and per-ナゾ the
/// clue / framing lines and the teach card.
Iterable<String> _sceneStrings(SceneDef s) sync* {
  yield s.titleJa;
  if (s.cleared != null) yield s.cleared!;
  if (s.companionArrivalJa != null) yield s.companionArrivalJa!;
  for (final h in s.hotspots) {
    if (h.clueLineJa != null) yield h.clueLineJa!;
    if (h.framingJa != null) yield h.framingJa!;
    final tc = h.teachCard;
    if (tc != null) {
      yield tc.titleJa;
      if (tc.leadJa != null) yield tc.leadJa!;
      for (final it in tc.items) {
        yield it.en;
        yield it.ja;
      }
    }
  }
}

void main() {
  group('Composition conformance — lean-Layton (COMPOSITION-ARCHITECTURE.md)',
      () {
    test(
        '§1/§7.3/§8: EVERY grade has a painted SceneDef — the scene is the spine',
        () {
      for (final g in _expectedGrades) {
        expect(kScenesByGrade.containsKey(g), isTrue,
            reason: 'grade "$g" has no SceneDef → the home CTA warps to the '
                'level map for it (§8: map-traversal-as-spine must stay removed)');
        expect(sceneForGrade(g), isNotNull, reason: 'grade "$g" scene is null');
      }
      // No EXTRA grade keys sneaking the map back in via an unlisted scene.
      expect(kScenesByGrade.length, _expectedGrades.length,
          reason: 'kScenesByGrade has ${kScenesByGrade.length} entries; the '
              'spec names exactly ${_expectedGrades.length} 事件簿');
    });

    test('§1: each chapter (scene) has 2–5 ナゾ + the hidden 声の石 (coin)', () {
      for (final g in _expectedGrades) {
        final scene = sceneForGrade(g)!;
        final nazo =
            scene.hotspots.where((h) => h.kind == HotspotKind.npc).length;
        final coins =
            scene.hotspots.where((h) => h.kind == HotspotKind.coin).length;
        expect(nazo, inInclusiveRange(2, 5),
            reason: 'grade "$g" scene has $nazo ナゾ — the §1 chapter contract '
                'is 2–5 英検-item puzzles per scene');
        expect(coins, greaterThanOrEqualTo(1),
            reason: 'grade "$g" scene has no hidden 声の石/coin payoff (§1)');
      }
    });

    test('§7.6: NO royalty/conquest thread leaks into any shipped scene string',
        () {
      final leaks = <String>[];
      for (final g in _expectedGrades) {
        for (final str in _sceneStrings(sceneForGrade(g)!)) {
          for (final term in _royaltyJa) {
            if (str.contains(term)) leaks.add('grade $g: "$term" in «$str»');
          }
          if (_royaltyEn.hasMatch(str)) {
            leaks.add('grade $g: EN royalty term in «$str»');
          }
        }
      }
      expect(leaks, isEmpty,
          reason: 'royalty/conquest was recast to restoration (§7.6); these '
              'strings re-introduce it:\n${leaks.join('\n')}');
    });
  });
}
