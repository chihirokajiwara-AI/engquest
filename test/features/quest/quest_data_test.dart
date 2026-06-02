// Quest data integrity + starting-town logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/quest_data.dart';

void main() {
  group('Quest towns', () {
    test('towns exist and run easiest → hardest', () {
      expect(kQuestTowns, isNotEmpty);
      const order = ['5', '4', '3', 'pre2', '2', 'pre1'];
      expect(kQuestTowns.map((t) => t.eikenLevel).toList(), order);
    });

    test('first town is 英検5級 and playable', () {
      final first = kQuestTowns.first;
      expect(first.eikenLevel, '5');
      expect(first.encounters, isNotEmpty);
    });

    test('every authored encounter is well-formed', () {
      for (final town in kQuestTowns) {
        for (final e in town.encounters) {
          expect(e.npcLine.trim(), isNotEmpty, reason: town.id);
          expect(e.choices.length, greaterThanOrEqualTo(2), reason: town.id);
          expect(e.correctIndex, inInclusiveRange(0, e.choices.length - 1),
              reason: '${town.id}: ${e.npcLine}');
          expect(e.choices[e.correctIndex].trim(), isNotEmpty);
          expect(e.onCorrect.trim(), isNotEmpty);
        }
      }
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
