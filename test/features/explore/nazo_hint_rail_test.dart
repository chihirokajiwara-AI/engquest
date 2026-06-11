// test/features/explore/nazo_hint_rail_test.dart
// H1 — per-hotspot authored hint-ladder model + anti-cheat rail unit tests.
//
// Tests:
//   1. hintViolatesAnswerRail — answer named in hint → true (violation).
//   2. hintViolatesAnswerRail — distractor named in hint → true.
//   3. hintViolatesAnswerRail — safe pedagogical hint → false.
//   4. hintViolatesAnswerRail — case-insensitive matching.
//   5. NazoHint model — tier + textJa + computed cost match HintCoinService.
//   6. Hotspot.hints field — authored hints surface via _hintLadder logic:
//        a hotspot with authored hints returns them (sorted by tier) when
//        non-null and non-empty; null falls back to defaultHintsForLevel.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/gamification/hint_coin_service.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/quest/quest_data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Anti-cheat rail ─────────────────────────────────────────────────────────

  group('hintViolatesAnswerRail', () {
    const answer = 'are';
    const distractors = ['am', 'is', 'be'];

    test('hint naming the answer → true (violation)', () {
      expect(
        hintViolatesAnswerRail(
          'こたえは are ですよ',
          answer,
          distractors,
        ),
        isTrue,
        reason: 'hint that contains the answer string must be rejected',
      );
    });

    test('hint naming a distractor → true (violation)', () {
      expect(
        hintViolatesAnswerRail(
          '「is」は さんにんしょう のとき つかうよ',
          answer,
          distractors,
        ),
        isTrue,
        reason: 'hint that names a distractor eliminates a choice — illegal',
      );
    });

    test('safe pedagogical hint → false (no violation)', () {
      // The hint below names no option label from the choice list.
      expect(
        hintViolatesAnswerRail(
          '文の おわりを よく みて。しゅごが You のとき、どうし の かたちは かわる。',
          answer,
          distractors,
        ),
        isFalse,
        reason: 'a genuine teaching hint must pass the rail',
      );
    });

    test('case-insensitive: "ARE" in hint → true', () {
      expect(
        hintViolatesAnswerRail(
          'こたえは ARE だよ',
          answer,
          distractors,
        ),
        isTrue,
        reason: 'matching must be case-insensitive',
      );
    });

    test('empty answer + empty distractors → always false', () {
      expect(
        hintViolatesAnswerRail(
          'なんでも OK',
          '',
          [],
        ),
        isFalse,
      );
    });

    test('answer token in longer word is still matched (substring)', () {
      // "are" appears inside "aren't" — substring matching is intentional so
      // that the answer leaks even inside a longer token.
      expect(
        hintViolatesAnswerRail(
          "aren't you?",
          answer,
          distractors,
        ),
        isTrue,
      );
    });
  });

  // ── NazoHint model ──────────────────────────────────────────────────────────

  group('NazoHint model (H1)', () {
    test('tier 1 cost matches HintCoinService.costForTier(1)', () {
      const h = NazoHint(tier: 1, textJa: 'みなおし ヒント');
      expect(h.cost, equals(HintCoinService.costForTier(1)));
      expect(h.cost, equals(1));
    });

    test('tier 2 cost = 2', () {
      const h = NazoHint(tier: 2, textJa: 'いみ ヒント');
      expect(h.cost, equals(2));
    });

    test('tier 3 cost = 3', () {
      const h = NazoHint(tier: 3, textJa: 'きまり ヒント');
      expect(h.cost, equals(3));
    });

    test('NazoHint is const-constructible', () {
      const h = NazoHint(tier: 1, textJa: 'テスト');
      expect(h.textJa, equals('テスト'));
    });
  });

  // ── Hotspot.hints field + _hintLadder branching logic ───────────────────────

  group('Hotspot.hints — authored hint branching (H1)', () {
    // Use the first NPC step from kTown5Scene as a minimal real QuestStep.
    QuestStep npcStep() =>
        kTown5Scene.hotspots.firstWhere((h) => h.kind == HotspotKind.npc).step!;

    test('hints == null → null (fallback branch in _hintLadder)', () {
      final hotspot = Hotspot.npc(
        pos: const Alignment(0, 0),
        step: npcStep(),
      );
      expect(hotspot.hints, isNull,
          reason:
              'no hints supplied → null → fallback to defaultHintsForLevel');
    });

    test('authored hints are stored and sortable by tier', () {
      const authored = [
        NazoHint(tier: 3, textJa: 'きまり: ルールをみよう'),
        NazoHint(tier: 1, textJa: 'みなおし: もういちどよもう'),
        NazoHint(tier: 2, textJa: 'いみ: ことばのいみを かんがえよう'),
      ];
      final hotspot = Hotspot.npc(
        pos: const Alignment(0, 0),
        step: npcStep(),
        hints: authored,
      );
      expect(hotspot.hints, isNotNull);
      expect(hotspot.hints!.length, equals(3));

      // Sort by tier (as _hintLadder does) and verify order.
      final sorted = List<NazoHint>.from(hotspot.hints!)
        ..sort((a, b) => a.tier.compareTo(b.tier));
      expect(sorted[0].tier, equals(1));
      expect(sorted[1].tier, equals(2));
      expect(sorted[2].tier, equals(3));
      expect(sorted[0].textJa, equals('みなおし: もういちどよもう'));
    });

    test('authored hints are returned, not the generic fallback', () {
      const authored = [
        NazoHint(tier: 1, textJa: 'みなおし authored'),
        NazoHint(tier: 2, textJa: 'いみ authored'),
        NazoHint(tier: 3, textJa: 'きまり authored'),
      ];
      final hotspot = Hotspot.npc(
        pos: const Alignment(0, 0),
        step: npcStep(),
        hints: authored,
      );

      // Replicate the branching logic in _hintLadder:
      final authoredHints = hotspot.hints;
      final resolved = (authoredHints != null && authoredHints.isNotEmpty)
          ? (List<NazoHint>.from(authoredHints)
            ..sort((a, b) => a.tier.compareTo(b.tier)))
          : defaultHintsForLevel('5');

      // Must use authored, not the generic 英検5級 defaults.
      expect(resolved[0].textJa, equals('みなおし authored'));
      expect(resolved[1].textJa, equals('いみ authored'));
      expect(resolved[2].textJa, equals('きまり authored'));
    });

    test('null hints → falls back to defaultHintsForLevel', () {
      final hotspot = Hotspot.npc(
        pos: const Alignment(0, 0),
        step: npcStep(),
        // hints not set → null
      );

      final authoredHints = hotspot.hints;
      final resolved = (authoredHints != null && authoredHints.isNotEmpty)
          ? (List<NazoHint>.from(authoredHints)
            ..sort((a, b) => a.tier.compareTo(b.tier)))
          : defaultHintsForLevel('5');

      // Generic fallback starts with 【ヒント T1】.
      expect(resolved[0].textJa, contains('ヒント T1'));
    });

    test('all authored hints pass the rail against the greeting ナゾ answer', () {
      // Greeting ナゾ answer = 'Hello!' (index 1); distractors = others.
      const answer = 'Hello!';
      const distractors = ['Goodbye.', 'Thank you.', 'I am sorry.'];

      const authored = [
        NazoHint(tier: 1, textJa: 'みなおし: あいさつの ことばを おぼえよう'),
        NazoHint(tier: 2, textJa: 'いみ: 「であった とき」に つかう ことば は どれ？'),
        NazoHint(tier: 3, textJa: 'きまり: であった とき の あいさつ は ひとつだよ'),
      ];

      for (final h in authored) {
        expect(
          hintViolatesAnswerRail(h.textJa, answer, distractors),
          isFalse,
          reason:
              'authored hint "${h.textJa}" must not name answer or distractors',
        );
      }
    });
  });
}
