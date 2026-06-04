// Quest data integrity + starting-town logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/quest_data.dart';

void main() {
  group('Quest towns', () {
    test('towns exist and run easiest → hardest', () {
      expect(kQuestTowns, isNotEmpty);
      // 7 towns: 準2級プラス (pre2plus) bridges 準2級→2級 (英検 added it in 2025).
      const order = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];
      expect(kQuestTowns.map((t) => t.eikenLevel).toList(), order);
    });

    test('first town is 英検5級 and playable', () {
      final first = kQuestTowns.first;
      expect(first.eikenLevel, '5');
      expect(first.encounters, isNotEmpty);
    });

    test('every authored quiz is well-formed', () {
      // The 英検5級 town now mixes teach steps (TeachSound/BlendWord/...) with
      // QuestEncounter quizzes; the .npcLine/.choices/.correctIndex contract is
      // Quiz-only, so guard those assertions to QuestEncounter.
      for (final town in kQuestTowns) {
        for (final step in town.encounters) {
          if (step is QuestEncounter) {
            final e = step;
            expect(e.npcLine.trim(), isNotEmpty, reason: town.id);
            expect(e.choices.length, greaterThanOrEqualTo(2), reason: town.id);
            expect(e.correctIndex, inInclusiveRange(0, e.choices.length - 1),
                reason: '${town.id}: ${e.npcLine}');
            expect(e.choices[e.correctIndex].trim(), isNotEmpty);
          }
          expect(step.onCorrect.trim(), isNotEmpty, reason: town.id);
        }
      }
    });

    test('every step (any kind) has well-formed options + a correct one', () {
      for (final town in kQuestTowns) {
        for (final step in town.encounters) {
          expect(step.npcName.trim(), isNotEmpty, reason: town.id);
          expect(step.options.length, greaterThanOrEqualTo(2), reason: town.id);
          expect(step.correctIndex, inInclusiveRange(0, step.options.length - 1),
              reason: town.id);
          expect(step.options[step.correctIndex].label.trim(), isNotEmpty,
              reason: town.id);
          expect(step.options.where((o) => o.isCorrect).length, 1,
              reason: '${town.id}: exactly one correct option');
        }
      }
    });

    test('英検5級 town teaches (phonics) before it quizzes', () {
      final five = kQuestTowns.firstWhere((t) => t.eikenLevel == '5');
      // The opening steps are teach steps, not quizzes.
      expect(five.encounters.first, isA<TeachSound>());
      expect(five.encounters.whereType<TeachSound>(), isNotEmpty);
      expect(five.encounters.whereType<BlendWord>(), isNotEmpty);
      expect(five.encounters.whereType<Phrase>(), isNotEmpty);
      // The grammar quizzes are still present (handed off to at the end).
      expect(five.encounters.whereType<QuestEncounter>(), isNotEmpty);
      // First non-teach (Quiz) step appears AFTER the first teach step.
      final firstQuiz = five.encounters.indexWhere((s) => s is QuestEncounter);
      final firstTeach = five.encounters.indexWhere((s) => s is! QuestEncounter);
      expect(firstTeach, lessThan(firstQuiz));
    });
  });

  group('startingTownIndex', () {
    test('maps a level to its town; a 準2級 holder starts mid-quest', () {
      expect(startingTownIndex('5'), 0);
      expect(startingTownIndex('pre2'), 3);
      expect(startingTownIndex('pre1'), kQuestTowns.length - 1);
    });

    test('unknown level falls back to the first town', () {
      expect(startingTownIndex('zzz'), 0);
    });
  });
}
