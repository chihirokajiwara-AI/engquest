// test/features/exam_practice/choice_shuffle_test.dart
// Guards the positional answer-key bias fix: shuffledChoiceSet must preserve the
// answer STRING while moving its position, and across many runs must NOT always
// land the answer at the same slot (the bug it fixes).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/choice_shuffle.dart';

void main() {
  group('shuffledChoiceSet (#answer-key-bias)', () {
    test('preserves the answer string at the remapped index', () {
      final choices = ['A', 'B', 'C', 'D'];
      for (var seed = 0; seed < 50; seed++) {
        for (var correct = 0; correct < 4; correct++) {
          final s = shuffledChoiceSet(choices, correct, Random(seed));
          expect(s.choices.toSet(), choices.toSet(),
              reason: 'no choice lost or duplicated');
          expect(s.choices[s.correctIdx], choices[correct],
              reason: 'remapped index still points to the same answer');
        }
      }
    });

    test('distributes the answer across positions (kills the slot-1 tell)', () {
      // Authored data is all correctIdx:0; after shuffling many items the answer
      // must NOT stay at 0 every time.
      final rng = Random(7);
      final counts = List<int>.filled(4, 0);
      for (var i = 0; i < 400; i++) {
        final s = shuffledChoiceSet(['w', 'x', 'y', 'z'], 0, rng);
        counts[s.correctIdx]++;
      }
      // Every slot should get a healthy share (~100 each); none should be ~all
      // or ~zero. Loose bounds to stay deterministic-robust.
      for (final c in counts) {
        expect(c, greaterThan(50), reason: 'each slot used: $counts');
        expect(c, lessThan(200), reason: 'no slot dominates: $counts');
      }
    });

    test('handles a 3-choice set', () {
      final s = shuffledChoiceSet(['a', 'b', 'c'], 2, Random(1));
      expect(s.choices.length, 3);
      expect(s.choices[s.correctIdx], 'c');
    });
  });
}
