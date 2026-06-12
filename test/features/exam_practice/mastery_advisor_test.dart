// Unit tests for adviseProgression (mastery-based adaptive progression, #14).
// Locks the evidence-grounded thresholds: advance ≥70% (over ≥12 attempts),
// review <40%, else keep practicing — with grade-ladder boundary handling.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/mastery_advisor.dart';

SkillAccuracy _acc(double accuracy, int attempts) => SkillAccuracy(
    skill: EikenSkill.reading, accuracy: accuracy, itemsAttempted: attempts);

void main() {
  group('adviseProgression', () {
    test('too few attempts → keepPracticing (no premature advice)', () {
      final r = adviseProgression('5', [_acc(1.0, 5)]); // 5 < 12
      expect(r.advice, ProgressionAdvice.keepPracticing);
      expect(r.suggestedGrade, isNull);
    });

    test('mastery (≥70%) over enough attempts → advance to next grade', () {
      final r = adviseProgression('5', [_acc(0.8, 20)]);
      expect(r.advice, ProgressionAdvice.advance);
      expect(r.suggestedGrade, '4'); // 5 → 4
    });

    test('struggling (<40%) → reviewBasics, suggest easier grade', () {
      final r = adviseProgression('3', [_acc(0.3, 20)]);
      expect(r.advice, ProgressionAdvice.reviewBasics);
      expect(r.suggestedGrade, '4'); // 3 → 4 (easier)
    });

    test('mid accuracy → keepPracticing this grade', () {
      final r = adviseProgression('3', [_acc(0.55, 20)]);
      expect(r.advice, ProgressionAdvice.keepPracticing);
      expect(r.suggestedGrade, isNull);
    });

    test('top grade (pre1) mastery → keepPracticing (cannot advance past top)',
        () {
      final r = adviseProgression('pre1', [_acc(0.95, 30)]);
      expect(r.advice, ProgressionAdvice.keepPracticing);
    });

    test('bottom grade (5) struggling → keepPracticing (no easier grade)', () {
      final r = adviseProgression('5', [_acc(0.2, 30)]);
      expect(r.advice, ProgressionAdvice.keepPracticing);
    });

    test('accuracy is attempt-weighted across skills', () {
      // 18/20 + 2/20 = 20/40 = 50% overall → mid → keepPracticing (not advance).
      final r = adviseProgression('4', [_acc(0.9, 20), _acc(0.1, 20)]);
      expect(r.advice, ProgressionAdvice.keepPracticing);
    });

    test('weighted accuracy crossing the mastery line advances', () {
      // 19/20 + 16/20 = 35/40 = 87.5% → advance.
      final r = adviseProgression('4', [_acc(0.95, 20), _acc(0.8, 20)]);
      expect(r.advice, ProgressionAdvice.advance);
      expect(r.suggestedGrade, '3');
    });

    test('every advice carries a non-empty child-friendly reason', () {
      for (final r in [
        adviseProgression('5', [_acc(0.8, 20)]),
        adviseProgression('3', [_acc(0.3, 20)]),
        adviseProgression('3', [_acc(0.55, 20)]),
      ]) {
        expect(r.reasonJa.trim(), isNotEmpty);
      }
    });
  });
}
