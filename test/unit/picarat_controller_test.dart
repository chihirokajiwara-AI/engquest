// test/unit/picarat_controller_test.dart
// Pure-Dart unit tests for PicaratController decay logic.

import 'package:test/test.dart';
import 'package:engquest/core/gamification/picarat_controller.dart';

void main() {
  group('PicaratController', () {
    test('starts at full value', () {
      final c = PicaratController(maxValue: 30);
      expect(c.currentValue, 30);
      expect(c.wrongCount, 0);
    });

    test('decays to ⅔ after 1 wrong', () {
      final c = PicaratController(maxValue: 30);
      c.onWrong();
      expect(c.currentValue, (30 * 2 / 3).round());
      expect(c.wrongCount, 1);
    });

    test('decays to ⅓ after 2 wrongs', () {
      final c = PicaratController(maxValue: 30);
      c.onWrong();
      c.onWrong();
      expect(c.currentValue, (30 * 1 / 3).round());
    });

    test('floors at 40% after 3+ wrongs', () {
      final c = PicaratController(maxValue: 30);
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
      final c = PicaratController(maxValue: 10);
      c.onWrong(); // 10 * ⅔ = 7
      final earned = c.earn();
      expect(earned, (10 * 2 / 3).round());
      expect(c.isSolved, isTrue);
      // Second earn is no-op
      expect(c.earn(), 0);
    });

    test('floor is never below 1', () {
      // Tiny maxValue edge case
      final c = PicaratController(maxValue: 1);
      c.onWrong();
      c.onWrong();
      c.onWrong();
      expect(c.currentValue, greaterThanOrEqualTo(1));
    });

    test('reset() restores full value', () {
      final c = PicaratController(maxValue: 20);
      c.onWrong();
      c.onWrong();
      c.reset();
      expect(c.currentValue, 20);
      expect(c.wrongCount, 0);
      expect(c.isSolved, isFalse);
    });

    test('picaratMaxForGrade returns expected values', () {
      expect(picaratMaxForGrade('5'), 10);
      expect(picaratMaxForGrade('4'), 15);
      expect(picaratMaxForGrade('3'), 20);
      expect(picaratMaxForGrade('pre2'), 25);
      expect(picaratMaxForGrade('2'), 35);
      expect(picaratMaxForGrade('pre1'), 50);
    });
  });
}
