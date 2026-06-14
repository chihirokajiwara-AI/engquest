// Locks the parent-dashboard category-mastery fix (flaw-hunt 2026-06-14).
// The old builder inferred category from the vocabId's sequence number (seq<=30
// Animals, <=60 Food, …), which mislabeled every word past seq 60 and collapsed
// seq 151-600 into "Other" — a wrong category breakdown shown to a paying parent.
// The fix groups by the REAL vocab category (resolved from the vocab DB).

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/analytics/progress_service.dart';

Map<String, dynamic> _card(String id, String state) =>
    {'id': id, 'state': state};

void main() {
  group('vocabGradeFromId', () {
    test('maps each grade prefix (including the irregular ones)', () {
      expect(vocabGradeFromId('eiken5_001'), '5');
      expect(vocabGradeFromId('eiken4_001'), '4');
      expect(vocabGradeFromId('eiken3_0001'), '3');
      expect(vocabGradeFromId('eikenpre2_001'), 'pre2');
      expect(vocabGradeFromId('pre2plus_0001'), 'pre2plus');
      expect(vocabGradeFromId('eiken2_001'), '2');
      expect(vocabGradeFromId('eiken_pre1_0001'), 'pre1');
    });

    test('prefixes do not collide — eiken2_ never matches pre2/pre1 ids', () {
      // The dangerous overlaps: ensure each resolves to its OWN grade.
      expect(vocabGradeFromId('eikenpre2_009'), 'pre2'); // not '2'
      expect(vocabGradeFromId('eiken_pre1_009'), 'pre1'); // not '2'
      expect(vocabGradeFromId('eiken2_009'), '2');
    });

    test('unrecognised id → null', () {
      expect(vocabGradeFromId('foo_123'), isNull);
      expect(vocabGradeFromId(''), isNull);
    });
  });

  group('aggregateCategoryMastery', () {
    test('groups by the REAL category from the map, not seq inference', () {
      // eiken5_091 is really "Colors & Shapes"; the old code would have called
      // it "Numbers & Time" (seq 91). The map drives the result now.
      final cards = [
        _card('eiken5_091', 'review'),
        _card('eiken5_092', 'new'),
      ];
      final map = {
        'eiken5_091': 'Colors & Shapes',
        'eiken5_092': 'Colors & Shapes',
      };
      final result = aggregateCategoryMastery(cards, map);
      expect(result.length, 1);
      expect(result.first.name, 'Colors & Shapes');
      expect(result.first.totalCount, 2);
      expect(result.first.masteredCount, 1); // only the 'review' card
    });

    test('only review-state counts as mastered', () {
      final cards = [
        _card('a', 'review'),
        _card('b', 'learning'),
        _card('c', 'relearning'),
        _card('d', 'new'),
      ];
      final map = {
        for (final c in ['a', 'b', 'c', 'd']) c: 'Animals'
      };
      final result = aggregateCategoryMastery(cards, map);
      expect(result.first.totalCount, 4);
      expect(result.first.masteredCount, 1);
    });

    test('a vocabId absent from the map falls back to Other', () {
      final result =
          aggregateCategoryMastery([_card('mystery_1', 'review')], {});
      expect(result.first.name, contains('Other'));
    });

    test('sorted by mastery ratio (highest first)', () {
      final cards = [
        _card('x1', 'review'), // Food 1/1 = 1.0
        _card('y1', 'review'), _card('y2', 'new'), // Animals 1/2 = 0.5
      ];
      final map = {'x1': 'Food', 'y1': 'Animals', 'y2': 'Animals'};
      final result = aggregateCategoryMastery(cards, map);
      expect(result.first.name, 'Food');
      expect(result.last.name, 'Animals');
    });

    test('empty cards → empty list (honest no-data)', () {
      expect(aggregateCategoryMastery([], {}), isEmpty);
    });
  });
}
