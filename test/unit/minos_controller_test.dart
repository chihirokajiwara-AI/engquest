// test/unit/minos_controller_test.dart
// Pure-Dart unit tests for MinosController decay logic.

import 'package:test/test.dart';
import 'package:engquest/core/gamification/minos_controller.dart';

void main() {
  group('MinosController', () {
    test('starts at full value', () {
      final c = MinosController(maxValue: 30);
      expect(c.currentValue, 30);
      expect(c.wrongCount, 0);
    });

    test('decays to ⅔ after 1 wrong', () {
      final c = MinosController(maxValue: 30);
      c.onWrong();
      expect(c.currentValue, (30 * 2 / 3).round());
      expect(c.wrongCount, 1);
    });

    test('decays to ⅓ after 2 wrongs', () {
      final c = MinosController(maxValue: 30);
      c.onWrong();
      c.onWrong();
      expect(c.currentValue, (30 * 1 / 3).round());
    });

    test('floors at 40% after 3+ wrongs', () {
      final c = MinosController(maxValue: 30);
      c.onWrong();
      c.onWrong();
      c.onWrong();
      final floor = (30 * 0.4).round();
      expect(c.currentValue, floor);
      // Extra wrongs don't go below floor
      c.onWrong();
      c.onWrong();
      expect(c.currentValue, floor);
    });

    test('earn() returns current value and locks', () {
      final c = MinosController(maxValue: 10);
      c.onWrong(); // 10 * ⅔ = 7
      final earned = c.earn();
      expect(earned, (10 * 2 / 3).round());
      expect(c.isSolved, isTrue);
      // Second earn is no-op
      expect(c.earn(), 0);
    });

    test('floor is never below 1', () {
      // Tiny maxValue edge case
      final c = MinosController(maxValue: 1);
      c.onWrong();
      c.onWrong();
      c.onWrong();
      expect(c.currentValue, greaterThanOrEqualTo(1));
    });

    test('reset() restores full value', () {
      final c = MinosController(maxValue: 20);
      c.onWrong();
      c.onWrong();
      c.reset();
      expect(c.currentValue, 20);
      expect(c.wrongCount, 0);
      expect(c.isSolved, isFalse);
    });

    test('minosMaxForGrade returns expected values', () {
      expect(minosMaxForGrade('5'), 10);
      expect(minosMaxForGrade('4'), 15);
      expect(minosMaxForGrade('3'), 20);
      expect(minosMaxForGrade('pre2'), 25);
      expect(minosMaxForGrade('2'), 35);
      expect(minosMaxForGrade('pre1'), 50);
    });
  });
}
