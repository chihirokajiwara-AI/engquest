// Locks the two HONESTY invariants of the 合格率 readiness formula (cse_model.dart)
// — the guarantees a paying parent relies on, that a refactor must never silently
// break (an inflated readiness would tell an under-prepared child they are 合格圏).
//
//   (1) CAP: each skill contributes min(rawAccuracy, target), so one strong skill
//       can NOT over-bank a weak one — readiness reflects the weakest measured skill.
//   (2) UNMEASURED: a skill with no data contributes 0 but stays in the denominator,
//       so readiness can reach 100 ONLY when every applicable skill is measured AND
//       at/above the passing 目安.
//
// 5級 applies Reading + Listening, passing 目安 = 0.60.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';

CseEstimate _est(List<SkillAccuracy> accs) =>
    CseEstimator.estimate(grade: '5', accuracies: accs)!;

void main() {
  group('合格率 readiness — cap invariant (no over-banking)', () {
    test('a maxed Reading can NOT mask a weak Listening', () {
      final e = _est(const [
        SkillAccuracy(
            skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 10),
        SkillAccuracy(
            skill: EikenSkill.listening, accuracy: 0.20, itemsAttempted: 10),
      ]);
      // reading min(1.0,0.6)=0.6, listening min(0.2,0.6)=0.2 → 0.8 / (2×0.6).
      expect(e.readinessPct, closeTo(66.67, 0.5));
      expect(e.readinessPct, lessThan(100),
          reason: 'one strong skill must not inflate readiness to passing');
    });

    test('100 requires EVERY measured skill at/above the 目安', () {
      final justBelow = _est(const [
        SkillAccuracy(
            skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 10),
        SkillAccuracy(
            skill: EikenSkill.listening, accuracy: 0.59, itemsAttempted: 10),
      ]);
      expect(justBelow.readinessPct, lessThan(100),
          reason: 'a skill below the 目安 must keep readiness under 100');

      final atTarget = _est(const [
        SkillAccuracy(
            skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 10),
        SkillAccuracy(
            skill: EikenSkill.listening, accuracy: 0.60, itemsAttempted: 10),
      ]);
      expect(atTarget.readinessPct, closeTo(100, 0.01),
          reason: 'all measured skills at the 目安 → exactly 100');
    });
  });

  group('合格率 readiness — unmeasured penalty', () {
    test('an unmeasured skill caps readiness below 100', () {
      final e = _est(const [
        SkillAccuracy(
            skill: EikenSkill.reading, accuracy: 1.0, itemsAttempted: 10),
        // Listening omitted entirely → unmeasured.
      ]);
      expect(e.unmeasuredSkills, contains(EikenSkill.listening));
      // reading caps at 0.6; listening contributes 0 → 0.6 / (2×0.6) = 50%.
      expect(e.readinessPct, closeTo(50, 0.5));
      expect(e.readinessPct, lessThan(100),
          reason: 'readiness must not reach 100 while a skill is 未測定');
    });
  });
}
