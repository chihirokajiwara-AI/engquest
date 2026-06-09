// test/features/exam_practice/pass/cse_model_test.dart
// Unit tests for lib/features/exam_practice/pass/cse_model.dart.
//
// VERIFIED against EIKEN-MASTERY-AND-GAPS-2026-06-06.json (accessed 2026-06-06):
//   5級  一次合格419 / 満点850  (R/L equal split: R=425, L=425)
//   4級  一次合格622 / 満点1000 (R/L: R=500, L=500)
//   3級  一次合格1103/ 満点1650 (R/W/L: R=550, W=550, L=550)
//   準2級 一次合格1322/ 満点1800 (R/W/L: R=600, W=600, L=600)
//   2級  一次合格1520/ 満点1950 (R/W/L: R=650, W=650, L=650)
//   準1級 一次合格1792/ 満点2250 (R/W/L: each 750)
//
// CORRECTED 2026-06-07 (verified eiken.or.jp/cse): prior 1980/2600/3000 were
// inflated (per-skill 660/867/1000 wrongly included 二次/scaling). The 一次満点 =
// sum of per-skill 一次 CSE maxes (600/650/750), each divides exactly by 3.

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

    test('準2級: R=W=L=600 (1800÷3=600 exact)', () {
      final m = CseEstimator.skillMaxScores('pre2')!;
      expect(m[EikenSkill.reading], equals(600));
      expect(m[EikenSkill.writing], equals(600));
      expect(m[EikenSkill.listening], equals(600));
      expect(m.values.fold(0, (s, v) => s + v), equals(1800));
    });

    test('2級: R=W=L=650 (1950÷3=650 exact)', () {
      final m = CseEstimator.skillMaxScores('2')!;
      expect(m[EikenSkill.reading], equals(650));
      expect(m[EikenSkill.writing], equals(650));
      expect(m[EikenSkill.listening], equals(650));
      expect(m.values.fold(0, (s, v) => s + v), equals(1950));
    });

    test('準2級プラス: R=W=L=625 (1875÷3=625 exact)', () {
      final m = CseEstimator.skillMaxScores('pre2plus')!;
      expect(m[EikenSkill.reading], equals(625));
      expect(m[EikenSkill.writing], equals(625));
      expect(m[EikenSkill.listening], equals(625));
      expect(m.values.fold(0, (s, v) => s + v), equals(1875));
    });

    test('準1級: R=W=L=750 (2250÷3=750 exact)', () {
      final m = CseEstimator.skillMaxScores('pre1')!;
      expect(m[EikenSkill.reading], equals(750));
      expect(m[EikenSkill.writing], equals(750));
      expect(m[EikenSkill.listening], equals(750));
      expect(m.values.fold(0, (s, v) => s + v), equals(2250));
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
    });

    test('HONEST (#113): 49% raw (the old "CSE-passing") is BELOW the 60% 目安', () {
      // The OLD model treated the CSE passing FRACTION (419/850 = 49.3%) as the
      // raw target → showed 100% "passing" at 49% raw. That was the bug: 英検 CSE
      // is IRT non-linear, and the empirical passing raw 目安 is ~60%. So 49% raw
      // is honestly NOT at the 目安: readiness ≈ 49.3/60 ≈ 82%, not predicted pass.
      final est = CseEstimator.estimate(
        grade: '5',
        accuracies: [
          const SkillAccuracy(
              skill: EikenSkill.reading,
              accuracy: 419 / 850, // ~0.493
              itemsAttempted: 25),
          const SkillAccuracy(
              skill: EikenSkill.listening,
              accuracy: 419 / 850,
              itemsAttempted: 25),
        ],
      )!;
      expect(est.readinessPct, closeTo(82.2, 1.5));
      expect(est.isPredictedPass, isFalse);
      expect(est.passTargetRaw, equals(0.60));
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
    test('HONEST (#113): R=80% W=60% L=70% — all ≥ 6割 目安 → REACHES 目安', () {
      // This is the headline fix. The OLD linear model said this profile was
      // "89.8%, NOT passing" — but every skill is at/above the published 2級 raw
      // 目安 (6割), so a candidate here passes (1級/準1=7割, 2級以下=6割 — 協会).
      // Honest model: each skill capped at 0.60 → all reach it → readiness 100,
      // 目安 reached. Writing (0.60, the lowest) is still the limiting skill.
      final est = CseEstimator.estimate(
        grade: '2',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.80, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.60, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.70, itemsAttempted: 30),
        ],
      )!;
      expect(est.totalScore, equals(1365)); // CSE bars unchanged
      expect(est.readinessPct, equals(100.0));
      expect(est.isPredictedPass, isTrue);
      expect(est.limitingSkill, equals(EikenSkill.writing));
    });

    test('HONEST (#113): a below-目安 skill caps readiness (no over-banking)', () {
      // R=100% L=100% but W=0% (measured): strong skills must NOT over-bank the
      // failing one. Capped contribution = 0.6+0.6+0 = 1.2 / 1.8 = 66.7%.
      final est = CseEstimator.estimate(
        grade: '2',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.0, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
        ],
      )!;
      expect(est.readinessPct, closeTo(66.7, 0.5));
      expect(est.isPredictedPass, isFalse);
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
      expect(est.readinessPct, lessThan(100.0));
    });

    test('all skills at/above 目安 → predicted pass (目安 reached)', () {
      final est = CseEstimator.estimate(
        grade: '2',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 1.0, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
        ],
      )!;
      expect(est.totalScore, equals(1950));
      expect(est.readinessPct, equals(100.0));
      expect(est.isPredictedPass, isTrue);
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
    test('passing score 1792 / maxScore 2250', () {
      final est = CseEstimator.estimate(
        grade: 'pre1',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 1.0, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 29),
        ],
      )!;
      expect(est.passingScore, equals(1792));
      expect(est.maxScore, equals(2250));
      expect(est.totalScore, equals(2250));
    });

    test('Listening=0 with Writing+Reading strong → fails (KEY RULE)', () {
      // 技能均等: a zeroed skill caps the total. R=80% W=80% L=0 at 750/skill →
      // 600+600+0 = 1200 < 1792.
      final est = CseEstimator.estimate(
        grade: 'pre1',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.80, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.80, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.0, itemsAttempted: 1),
        ],
      )!;
      // R=600, W=600, L=0 → total=1200 < 1792
      expect(est.totalScore, equals(1200));
      expect(est.isPredictedPass, isFalse);
      expect(est.limitingSkill, equals(EikenSkill.listening));
    });
  });

  // ── estimate: 準2級プラス ───────────────────────────────────────────────────

  group('CseEstimator.estimate — 準2級プラス', () {
    test('passing score 1402 / maxScore 1875; perfect → pass', () {
      final est = CseEstimator.estimate(
        grade: 'pre2plus',
        accuracies: [
          const SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 31),
          const SkillAccuracy(skill: EikenSkill.writing, accuracy: 1.0, itemsAttempted: 2),
          const SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
        ],
      )!;
      expect(est.passingScore, equals(1402));
      expect(est.maxScore, equals(1875));
      expect(est.totalScore, equals(1875));
      expect(est.isPredictedPass, isTrue);
    });

    test('no data → all skills 未測定, readiness 0', () {
      final est = CseEstimator.estimate(grade: 'pre2plus', accuracies: [])!;
      expect(est.readinessPct, equals(0.0));
      expect(est.unmeasuredSkills, containsAll(<EikenSkill>[
        EikenSkill.reading,
        EikenSkill.writing,
        EikenSkill.listening,
      ]));
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

  // ── 未測定 honesty: banked readiness never false-100 while untested (#36) ────
  group('CseEstimator.estimate — unmeasured-skill honesty', () {
    test('3級: strong R+L but writing 未測定 → 未測定 flag, NOT a green 100%', () {
      final est = CseEstimator.estimate(
        grade: '3',
        accuracies: const [
          SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.8, itemsAttempted: 30),
          SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.8, itemsAttempted: 30),
          // writing never practiced → itemsAttempted 0 → 未測定 (not a failed 0)
          SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.0, itemsAttempted: 0),
        ],
      )!;
      // Honest model (#113): R,L capped at the 0.60 目安 = 0.6+0.6; W 未測定 = 0;
      // readiness = 1.2 / (3×0.6) = 66.7%. Writing is flagged 未測定 (the UI shows
      // it as such, not a fail). The headline must NOT read 100% / predict a pass
      // while a required skill is untested.
      expect(est.unmeasuredSkills, contains(EikenSkill.writing));
      expect(est.readinessPct, closeTo(66.7, 0.5));
      expect(est.readinessPct, lessThan(100.0));
      expect(est.isPredictedPass, isFalse);
    });

    test('未測定 vs measured-0: same banked %, but the 未測定 flag differs', () {
      // The honest distinction is the flag (display), not the number.
      final unmeasured = CseEstimator.estimate(
        grade: '3',
        accuracies: const [
          SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 30),
          SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
          SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.0, itemsAttempted: 0),
        ],
      )!;
      final measuredZero = CseEstimator.estimate(
        grade: '3',
        accuracies: const [
          SkillAccuracy(skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 30),
          SkillAccuracy(skill: EikenSkill.listening, accuracy: 1.0, itemsAttempted: 30),
          SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.0, itemsAttempted: 2),
        ],
      )!;
      expect(unmeasured.readinessPct, equals(measuredZero.readinessPct));
      expect(unmeasured.unmeasuredSkills, contains(EikenSkill.writing));
      expect(measuredZero.unmeasuredSkills, isNot(contains(EikenSkill.writing)));
      // Neither predicts a pass (R+L=1100 < 1103); writing is the bottleneck.
      expect(unmeasured.isPredictedPass, isFalse);
      expect(measuredZero.isPredictedPass, isFalse);
    });

    test('a genuine fully-measured pass is still predicted', () {
      final est = CseEstimator.estimate(
        grade: '3',
        accuracies: const [
          SkillAccuracy(skill: EikenSkill.reading, accuracy: 0.9, itemsAttempted: 30),
          SkillAccuracy(skill: EikenSkill.writing, accuracy: 0.9, itemsAttempted: 2),
          SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.9, itemsAttempted: 30),
        ],
      )!;
      expect(est.unmeasuredSkills, isEmpty);
      expect(est.isPredictedPass, isTrue);
    });
  });
}
