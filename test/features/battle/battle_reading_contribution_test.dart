// Guards #35: the daily vocab Battle bridges into 合格率 as bounded, conservative
// reading-skill evidence (battleReadingContribution).

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/features/battle/battle_screen.dart';

void main() {
  group('battleReadingContribution', () {
    test('empty session contributes nothing', () {
      final c = battleReadingContribution(const []);
      expect(c.correct, 0);
      expect(c.total, 0);
    });

    test('correct = Good|Easy only (Hard/Again are not-yet-mastered)', () {
      final c = battleReadingContribution(
        const [Grade.good, Grade.easy, Grade.hard, Grade.again],
      );
      expect(c.total, 4);
      expect(c.correct, 2); // good + easy
    });

    test('under the cap, contribution is the raw session', () {
      final c = battleReadingContribution(
        List.filled(8, Grade.good),
        cap: 10,
      );
      expect(c.total, 8);
      expect(c.correct, 8);
    });

    test('over the cap, contribution is bounded but preserves accuracy ratio',
        () {
      // 30 cards, 24 correct (80%) → capped to 10 total, 8 correct.
      final grades = [
        ...List.filled(24, Grade.good),
        ...List.filled(6, Grade.again),
      ];
      final c = battleReadingContribution(grades, cap: 10);
      expect(c.total, 10);
      expect(c.correct, 8); // round(24 * 10 / 30) = 8
    });

    test('a long binge of easy reviews cannot swamp the bucket', () {
      final c =
          battleReadingContribution(List.filled(200, Grade.easy), cap: 10);
      expect(c.total, 10); // bounded — not 200
      expect(c.correct, 10);
    });
  });
}
