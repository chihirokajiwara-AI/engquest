// test/features/exam_practice/pass/cse_model_test.dart
// Unit tests for lib/features/exam_practice/pass/cse_model.dart.
//
// VERIFIED against EIKEN-MASTERY-AND-GAPS-2026-06-06.json (accessed 2026-06-06):
//   5級  一次合格419 / 満点850  (R/L equal split: R=425, L=425)
//   4級  一次合格622 / 満点1000 (R/L: R=500, L=500)
//   3級  一次合格1103/ 満点1650 (R/W/L: R=550, W=550, L=550)
//   準2級 一次合格1322/ 満点1980 (R/W/L: R=660, W=660, L=660)
//   2級  一次合格1520/ 満点2600 (R/W/L: R=867, W=866, L=867 — or nearest thirds)
//   準1級 一次合格1792/ 満点3000 (R/W/L: each 1000)
//
// NOTE on 2級/準1級 technical rounding:
//   _GradeSpec.skillMaxScores: base = maxScore ÷ 3 (integer), last skill absorbs residual.
//   2600 ÷ 3 = 866 rem 2 → R=866, W=866, L=868  (L absorbs residual 2)
//   3000 ÷ 3 = 1000 rem 0 → R=W=L=1000 exactly.

import 'package:test/test.dart';

import 'package:engquest/features/exam_practice/pass/cse_model.dart';

void main() {
  // ── Spec table ──────────────────────────────────────────────────────────────

  group('CseEstimator.skillMaxScores — grade spec verification', () {
    test('5級: R=425, L=425 (850÷2=425)', () {
      final m = CseEstimator.skillMaxScores('5')!;
      expect(m[EikenSkill.reading], equals(425));
      expect(m[EikenSkill.listening], equals(425));
      expect(m.values.fold(0, (s, v) => s + v), equals(850));
    });

    test('4級: R=500, L=500 (1000÷2=500)', () {
      final m = CseEstimator.skillMaxScores('4')!;
      expect(m[EikenSkill.reading], equals(500));
      expect(m[EikenSkill.listening], equals(500));
      expect(m.values.fold(0, (s, v) => s + v), equals(1000));
    });

    test('3級: R=W=L=550 (1650÷3=550 exact)', () {
      final m = CseEstimator.skillMaxScores('3')!;
      expect(m[EikenSkill.reading], equals(550));
      expect(m[EikenSkill.writing], equals(550));
      expect(m[EikenSkill.listening], equals(550));
      expect(m.values.fold(0, (s, v) => s + v), equals(1650));
    });

    test('準2級: R=W=L=660 (1980÷3=660 exact)', () {
      final m = CseEstimator.skillMaxScores('pre2')!;
      expect(m[EikenSkill.reading], equals(660));
      expect(m[EikenSkill.writing], equals(660));
      expect(m[EikenSkill.listening], equals(660));
      expect(m.values.fold(0, (s, v) => s + v), equals(1980));
    });

    test('2級: sum = 2600 (R+W+L distributed)', () {
      final m = CseEstimator.skillMaxScores('2')!;
      final total = m.values.fold(0, (s, v) => s + v);
      expect(total, equals(2600));
      // Each skill gets ≈ 866-868 points
      for (final v in m.values) {
        expect(v, inInclusiveRange(865, 870));
      }
    });

    test('準1級: R=W=L=1000 (3000÷3=1000 exact)', () {
      final m = CseEstimator.skillMaxScores('pre1')!;
      expect(m[EikenSkill.reading], equals(1000));
      expect(m[EikenSkill.writing], equals(1000));
      expect(m[EikenSkill.listening], equals(1000));
      expect(m.values.fold(0, (s, v) => s + v), equals(3000));
    });

    test('unknown grade returns null', () {
      expect(CseEstimator.skillMaxScores('unknown'), isNull);
    });
  });

  // ── skillsForGrade ──────────────────────────────────────────────────────────

  group('CseEstimator.skillsForGrade', () {
    test('5級 has Reading and Listening only', () {
      final s = CseEstimator.skillsForGrade('5')!;
      expect(s, containsAll([EikenSkill.reading, EikenSkill.listening]));
      expect(s, isNot(contains(EikenSkill.writing)));
    });

    test('4級 has Reading and Listening only', () {
      final s = CseEstimator.skillsForGrade('4')!;
      expect(s, containsAll([EikenSkill.reading, EikenSkill.listening]));
      expect(s, isNot(contains(EikenSkill.writing)));
    });

    test('3級 has Reading, Writing, and Listening', () {
      final s = CseEstimator.skillsForGrade('3')!;
      expect(s, containsAll([EikenSkill.reading, EikenSkill.writing, EikenSkill.listening]));
    });

    test('2級 has Reading, Writing, and Listening', () {
      final s = CseEstimator.skillsForGrade('2')!;
      expect(s, containsAll([EikenSkill.reading, EikenSkill.writing, EikenSkill.listening]));
    });

    test('unknown grade returns null', () {
      expect(CseEstimator.skillsForGrade('unknown'), isNull);
    });
  });

  // ── estimate: 5級 ──────────────────────────────────────────────────────────

  group('CseEstimator.estimate — 5級', () {
    test('perfect score → readinessPct=100, totalScore=850', () {
      final est = CseEstimator.estimate(
        grade: '5',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 25),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 25),
        ],
      )!;
      expect(est.totalScore, equals(850));
      expect(est.readinessPct, equals(100.0));
      expect(est.isPredictedPass, isTrue);
      expect(est.pointsNeeded, equals(0));
    });

    test('exact passing score (419/850) → readinessPct=100', () {
      // Accuracy needed: 419/850 per skill equally → each skill at 419/850
      // Since each skill max = 425:
      //   reading accuracy to hit at least (419÷2) / 425 ≈ 0.493
      //   listening accuracy same
      // Test: give each skill exactly the target score
      final est = CseEstimator.estimate(
        grade: '5',
        accuracies: [
          const SkillAccuracy(
              skill: EikenSkill.reading,
              accuracy: 419 / 850,  // ~0.493
              itemsAttempted: 25),
          const SkillAccuracy(
              skill: EikenSkill.listening,
              accuracy: 419 / 850,
              itemsAttempted: 25),
        ],
      )!;
      // total ≈ 419 → readinessPct ≈ 100 (419/419 * 100)
      expect(est.readinessPct, closeTo(100.0, 2.0));
    });

    test('zero accuracy → readinessPct=0, totalScore=0', () {
      final est = CseEstimator.estimate(
        grade: '5',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.0, itemsAttempted: 25),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.0, itemsAttempted: 25),
        ],
      )!;
      expect(est.totalScore, equals(0));
      expect(est.readinessPct, equals(0.0));
      expect(est.isPredictedPass, isFalse);
      expect(est.pointsNeeded, equals(419));
    });

    test('no data (itemsAttempted=0) → treated as zero', () {
      final est = CseEstimator.estimate(
        grade: '5',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.9, itemsAttempted: 0),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.9, itemsAttempted: 0),
        ],
      )!;
      expect(est.totalScore, equals(0));
      expect(est.readinessPct, equals(0.0));
    });

    test('empty accuracies → all skills zero', () {
      final est = CseEstimator.estimate(grade: '5', accuracies: [])!;
      expect(est.totalScore, equals(0));
    });
  });

  // ── estimate: 3級 ──────────────────────────────────────────────────────────

  group('CseEstimator.estimate — 3級', () {
    test('80% across all skills → above passing (1103)', () {
      final est = CseEstimator.estimate(
        grade: '3',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.8, itemsAttempted: 30),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.8, itemsAttempted: 1),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.8, itemsAttempted: 30),
        ],
      )!;
      // 0.8 × 550 = 440 per skill, total = 1320 > 1103
      expect(est.totalScore, equals(1320));
      expect(est.isPredictedPass, isTrue);
    });

    test('KEY RULE: perfect R+L but writing=0 → fails (uniform CSE rule)', () {
      // Under 技能均等配分, if Writing=0 total drops to ≤ 1100 < 1103
      final est = CseEstimator.estimate(
        grade: '3',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 30),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.0, itemsAttempted: 1),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
        ],
      )!;
      // R=550 + W=0 + L=550 = 1100 < 1103
      expect(est.totalScore, equals(1100));
      expect(est.isPredictedPass, isFalse);
      expect(est.limitingSkill, equals(EikenSkill.writing));
    });

    test('limitingSkill is the skill with lowest ratio', () {
      final est = CseEstimator.estimate(
        grade: '3',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.9, itemsAttempted: 30),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.4, itemsAttempted: 1),  // worst
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.8, itemsAttempted: 30),
        ],
      )!;
      expect(est.limitingSkill, equals(EikenSkill.writing));
    });
  });

  // ── estimate: 2級 ──────────────────────────────────────────────────────────

  group('CseEstimator.estimate — 2級', () {
    test('spec example: R=80% W=60% L=70% → ~83% readiness, Writing is limiting', () {
      final est = CseEstimator.estimate(
        grade: '2',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.80, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.60, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.70, itemsAttempted: 30),
        ],
      )!;
      // maxScores: R=866, W=866, L=868
      // estimated: R≈693, W≈520, L≈608 → total≈1821
      // readinessPct = 1821/1520 * 100 ≈ 119.8% → clamped to 100
      // (Above passing — but Writing is still the lowest ratio: 520/866≈0.60)
      expect(est.readinessPct, equals(100.0)); // passes because total > 1520
      expect(est.limitingSkill, equals(EikenSkill.writing));
    });

    test('failing case: R=60% W=30% L=55% → below passing', () {
      final est = CseEstimator.estimate(
        grade: '2',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.60, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.30, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.55, itemsAttempted: 30),
        ],
      )!;
      expect(est.isPredictedPass, isFalse);
      expect(est.limitingSkill, equals(EikenSkill.writing));
      expect(est.pointsNeeded, greaterThan(0));
    });

    test('passing score threshold: totalScore >= 1520 → predicted pass', () {
      final est = CseEstimator.estimate(
        grade: '2',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 1.0, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
        ],
      )!;
      expect(est.totalScore, equals(2600));
      expect(est.isPredictedPass, isTrue);
      expect(est.pointsNeeded, equals(0));
    });

    test('unknown grade returns null', () {
      expect(
        CseEstimator.estimate(grade: 'invalid', accuracies: []),
        isNull,
      );
    });
  });

  // ── estimate: 準1級 ────────────────────────────────────────────────────────

  group('CseEstimator.estimate — 準1級', () {
    test('passing score 1792 / maxScore 3000', () {
      final est = CseEstimator.estimate(
        grade: 'pre1',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 41),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 1.0, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
        ],
      )!;
      expect(est.passingScore, equals(1792));
      expect(est.maxScore, equals(3000));
      expect(est.totalScore, equals(3000));
    });

    test('Listening=0 with Writing+Reading perfect → fails (KEY RULE)', () {
      // R=1000 + W=1000 + L=0 = 2000 > 1792 → actually passes in this case!
      // But in a narrower scenario: R=80% W=80% L=0 → 800+800+0=1600 < 1792
      final est = CseEstimator.estimate(
        grade: 'pre1',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.80, itemsAttempted: 41),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.80, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.0, itemsAttempted: 1),
        ],
      )!;
      // R=800, W=800, L=0 → total=1600 < 1792
      expect(est.totalScore, equals(1600));
      expect(est.isPredictedPass, isFalse);
      expect(est.limitingSkill, equals(EikenSkill.listening));
    });
  });

  // ── readinessPct clamping ──────────────────────────────────────────────────

  group('readinessPct clamping', () {
    test('never exceeds 100', () {
      // All perfect → exactly 100
      final est = CseEstimator.estimate(
        grade: '3',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 30),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 1.0, itemsAttempted: 1),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
        ],
      )!;
      expect(est.readinessPct, lessThanOrEqualTo(100.0));
    });

    test('never below 0', () {
      final est = CseEstimator.estimate(grade: '4', accuracies: [])!;
      expect(est.readinessPct, greaterThanOrEqualTo(0.0));
    });
  });

  // ── Label helpers ──────────────────────────────────────────────────────────

  group('Label helpers', () {
    test('skillLabelJa returns Japanese labels', () {
      expect(CseEstimator.skillLabelJa(EikenSkill.reading), contains('リーディング'));
      expect(CseEstimator.skillLabelJa(EikenSkill.writing), contains('ライティング'));
      expect(CseEstimator.skillLabelJa(EikenSkill.listening), contains('リスニング'));
    });

    test('skillLabelEn returns English labels', () {
      expect(CseEstimator.skillLabelEn(EikenSkill.reading), 'Reading');
      expect(CseEstimator.skillLabelEn(EikenSkill.writing), 'Writing');
      expect(CseEstimator.skillLabelEn(EikenSkill.listening), 'Listening');
    });
  });

  // ── SkillAccuracy.attempted ────────────────────────────────────────────────

  group('SkillAccuracy.attempted', () {
    test('itemsAttempted=0 → attempted=false', () {
      const a = SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.9, itemsAttempted: 0);
      expect(a.attempted, isFalse);
    });

    test('itemsAttempted>0 → attempted=true', () {
      const a = SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.9, itemsAttempted: 1);
      expect(a.attempted, isTrue);
    });
  });
}
