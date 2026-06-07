// lib/features/exam_practice/pass/cse_model.dart
// A-KEN Quest — Per-skill CSE estimator and 合格率 predictor.
//
// SPEC SOURCE: docs/design/EIKEN-MASTERY-AND-GAPS-2026-06-06.json
//   (verified eiken.or.jp + 旺文社英語の友/ESLclub, accessed 2026-06-06)
//
// CSE SCORING — POST-2024 REFORM (技能均等配分):
//   KEY RULE: Each skill (Reading/Listening/Writing/Speaking) is weighted EQUALLY
//   within a grade's total CSE. One weak skill fails you even if others are perfect.
//
//   Grade  | 一次満点 | 一次合格 | 技能満点 (per applicable skill) | 技能
//   -------|---------|---------|--------------------------------|-----
//   5級    |   850   |   419   | R:425(100%)    L:425(100%)      | R, L
//   4級    |  1000   |   622   | R:500(100%)    L:500(100%)      | R, L
//   3級    |  1650   |  1103   | R:550  W:550   L:550           | R, W, L
//   準2級  |  1800   |  1322   | R:600  W:600   L:600           | R, W, L
//   2級    |  1950   |  1520   | R:650  W:650   L:650           | R, W, L (一次)
//   準1級  |  2250   |  1792   | R:750  W:750   L:750           | R, W, L (一次)
//
// NOTE: 一次試験 covers Reading + Writing (where applicable) + Listening.
//       Speaking (二次) is a SEPARATE exam stage; this model covers 一次 only.
//
// 5級/4級 have NO writing section; skill-equal split is R/L only (each 50%).
// 3級/準2級/2級/準1級 have R+W+L; each ~33.3% of 一次 満点.
//
// 技能満点 values are derived:  skillMax = floorToInt(一次満点 / skillCount)
// (fractional remainders assigned to the last skill via [_residual]).
//
// 合格率 is a readiness estimate, not a probabilistic model.
// Algorithm: sum estimated CSE scores across skills → compare to 合格基準スコア.
// readinessPct = clamp(estimatedTotal / passingScore * 100, 0, 100).
// This is appropriate for a child-facing "how close am I" meter.
//
// NO dart:io. No Firebase. No network. Pure-Dart computation only (R4).

/// Which skills a grade tests in the 一次 (written) exam.
enum EikenSkill {
  reading,
  writing,
  listening,
}

/// Accuracy data for a single skill (0.0–1.0).
/// [attempted] = whether the learner has any data for this skill.
/// When [attempted] is false the skill is treated as unknown (0 accuracy)
/// and [estimatedCse] returns 0, which correctly penalises unknown skills
/// in the readiness calculation.
class SkillAccuracy {
  final EikenSkill skill;

  /// Fraction of items answered correctly (0.0–1.0).
  final double accuracy;

  /// Number of items answered so far; 0 = no data.
  final int itemsAttempted;

  const SkillAccuracy({
    required this.skill,
    required this.accuracy,
    this.itemsAttempted = 0,
  });

  bool get attempted => itemsAttempted > 0;
}

/// Per-skill CSE estimate + the whole-exam aggregate.
class CseEstimate {
  /// The 英検 grade key (e.g. '5', '4', '3', 'pre2', '2', 'pre1').
  final String grade;

  /// Per-skill breakdown: {EikenSkill → estimated CSE score for that skill}.
  final Map<EikenSkill, int> skillScores;

  /// Sum of all skill scores (= estimated total 一次 CSE).
  final int totalScore;

  /// The grade's 一次 合格基準スコア (passing threshold).
  final int passingScore;

  /// The grade's 一次 満点 (maximum possible CSE).
  final int maxScore;

  /// Readiness percentage: how close the learner is to passing (0–100).
  /// Formula: clamp(totalScore / passingScore × 100, 0, 100).
  /// When readinessPct >= 100 the learner is predicted to pass.
  final double readinessPct;

  /// The skill with the lowest estimated CSE score (relative to its max).
  /// This is the "weakest skill" the UI highlights as the blocking factor.
  /// null when no skills have data.
  final EikenSkill? limitingSkill;

  /// Number of CSE points still needed to reach the passing threshold.
  /// 0 when already at or above the passing score.
  final int pointsNeeded;

  /// Applicable skills the learner has NO data for (itemsAttempted == 0). These
  /// score 0 in [skillScores], but that 0 means "not yet measured", NOT "tested
  /// and failed" — the UI must show them as 未測定 so 合格率 is honest. Empty
  /// when every applicable skill has data.
  final Set<EikenSkill> unmeasuredSkills;

  const CseEstimate({
    required this.grade,
    required this.skillScores,
    required this.totalScore,
    required this.passingScore,
    required this.maxScore,
    required this.readinessPct,
    required this.limitingSkill,
    required this.pointsNeeded,
    this.unmeasuredSkills = const {},
  });

  /// True when readinessPct >= 100 (predicted pass).
  bool get isPredictedPass => readinessPct >= 100.0;
}

// ── Grade spec table ──────────────────────────────────────────────────────────

/// Per-grade spec: which skills are in the 一次, their max CSE, and thresholds.
class _GradeSpec {
  final String grade;
  final List<EikenSkill> skills;
  final int firstPassScore; // 一次合格基準
  final int firstMaxScore; // 一次満点

  const _GradeSpec({
    required this.grade,
    required this.skills,
    required this.firstPassScore,
    required this.firstMaxScore,
  });

  /// Each skill's share of the 一次 満点 (技能均等配分).
  /// skillMax(i) = firstMaxScore ÷ skills.length, rounded.
  /// The last skill absorbs any rounding residual.
  Map<EikenSkill, int> get skillMaxScores {
    final n = skills.length;
    final base = firstMaxScore ~/ n;
    final residual = firstMaxScore - base * n;
    final out = <EikenSkill, int>{};
    for (var i = 0; i < n; i++) {
      out[skills[i]] = i == n - 1 ? base + residual : base;
    }
    return out;
  }
}

/// Verified CSE data — source: EIKEN-MASTERY-AND-GAPS-2026-06-06.json
/// (eiken.or.jp + 旺文社英語の友, accessed 2026-06-06).
const Map<String, _GradeSpec> _kGradeSpecs = {
  '5': _GradeSpec(
    grade: '5',
    skills: [EikenSkill.reading, EikenSkill.listening],
    firstPassScore: 419,
    firstMaxScore: 850,
  ),
  '4': _GradeSpec(
    grade: '4',
    skills: [EikenSkill.reading, EikenSkill.listening],
    firstPassScore: 622,
    firstMaxScore: 1000,
  ),
  '3': _GradeSpec(
    grade: '3',
    skills: [EikenSkill.reading, EikenSkill.writing, EikenSkill.listening],
    firstPassScore: 1103,
    firstMaxScore: 1650,
  ),
  // CORRECTED 2026-06-07 (verified eiken.or.jp/cse): firstMaxScore is the 一次
  // max = sum of per-skill CSE maxes (R+W+L) EXCLUDING 二次 speaking. The old
  // 1980/2600/3000 were inflated (they included speaking / wrong scaling), which
  // OVERSTATED 合格率 for borderline learners. Per-skill maxes: 準2級600, 2級650,
  // 準1級750 → 一次満点 1800/1950/2250.
  'pre2': _GradeSpec(
    grade: 'pre2',
    skills: [EikenSkill.reading, EikenSkill.writing, EikenSkill.listening],
    firstPassScore: 1322,
    firstMaxScore: 1800,
  ),
  '2': _GradeSpec(
    grade: '2',
    skills: [EikenSkill.reading, EikenSkill.writing, EikenSkill.listening],
    firstPassScore: 1520,
    firstMaxScore: 1950,
  ),
  'pre1': _GradeSpec(
    grade: 'pre1',
    skills: [EikenSkill.reading, EikenSkill.writing, EikenSkill.listening],
    firstPassScore: 1792,
    firstMaxScore: 2250,
  ),
};

// ── CseEstimator ─────────────────────────────────────────────────────────────

/// Converts per-skill accuracy data into a CSE estimate + 合格率 prediction.
///
/// Usage:
/// ```dart
/// final estimate = CseEstimator.estimate(
///   grade: '2',
///   accuracies: [
///     SkillAccuracy(skill: EikenSkill.reading,   accuracy: 0.80, itemsAttempted: 31),
///     SkillAccuracy(skill: EikenSkill.writing,   accuracy: 0.60, itemsAttempted: 2),
///     SkillAccuracy(skill: EikenSkill.listening, accuracy: 0.70, itemsAttempted: 30),
///   ],
/// );
/// print(estimate.readinessPct);   // e.g. 87.3
/// print(estimate.limitingSkill);  // EikenSkill.writing
/// ```
class CseEstimator {
  CseEstimator._();

  /// Returns null when [grade] is not in the spec table.
  static CseEstimate? estimate({
    required String grade,
    required List<SkillAccuracy> accuracies,
  }) {
    final spec = _kGradeSpecs[grade];
    if (spec == null) return null;

    final maxScores = spec.skillMaxScores;
    final skillScores = <EikenSkill, int>{};
    final unmeasured = <EikenSkill>{};

    // Build an accuracy lookup (unrecognised skills are ignored).
    final accMap = {for (final a in accuracies) a.skill: a};

    for (final skill in spec.skills) {
      final acc = accMap[skill];
      final max = maxScores[skill]!;
      if (acc == null || !acc.attempted) {
        // No data for this skill → estimate 0 (conservative/safe) and mark it
        // as unmeasured so the UI shows 未測定 rather than implying a failed 0.
        skillScores[skill] = 0;
        unmeasured.add(skill);
      } else {
        // Clamp accuracy to [0,1] defensively.
        final a = acc.accuracy.clamp(0.0, 1.0);
        skillScores[skill] = (a * max).round();
      }
    }

    final totalScore = skillScores.values.fold(0, (s, v) => s + v);

    // readinessPct: how far toward the passing threshold. Cap at 100.
    final readinessPct =
        (totalScore / spec.firstPassScore * 100.0).clamp(0.0, 100.0);

    final pointsNeeded =
        (spec.firstPassScore - totalScore).clamp(0, spec.firstMaxScore);

    // Limiting skill = the skill with the LOWEST score relative to its own max
    // (ratio = score / skillMax). This correctly identifies the bottleneck even
    // when skill maxes differ slightly due to rounding.
    EikenSkill? limiting;
    double worstRatio = double.infinity;
    for (final skill in spec.skills) {
      final score = skillScores[skill]!;
      final max = maxScores[skill]!;
      final ratio = max == 0 ? 0.0 : score / max;
      if (ratio < worstRatio) {
        worstRatio = ratio;
        limiting = skill;
      }
    }

    return CseEstimate(
      grade: grade,
      skillScores: Map.unmodifiable(skillScores),
      totalScore: totalScore,
      passingScore: spec.firstPassScore,
      maxScore: spec.firstMaxScore,
      readinessPct: readinessPct,
      limitingSkill: limiting,
      unmeasuredSkills: Set.unmodifiable(unmeasured),
      pointsNeeded: pointsNeeded,
    );
  }

  /// Returns the skill-max scores for a grade without needing a full estimate.
  /// Useful for rendering the per-skill bar max in [PassMeterScreen].
  /// Returns null for unknown grades.
  static Map<EikenSkill, int>? skillMaxScores(String grade) =>
      _kGradeSpecs[grade]?.skillMaxScores;

  /// Returns the 一次 skills for a grade.
  static List<EikenSkill>? skillsForGrade(String grade) =>
      _kGradeSpecs[grade]?.skills;

  /// Human-readable Japanese label for a skill (child-facing).
  static String skillLabelJa(EikenSkill skill) {
    switch (skill) {
      case EikenSkill.reading:
        return 'リーディング';
      case EikenSkill.writing:
        return 'ライティング';
      case EikenSkill.listening:
        return 'リスニング';
    }
  }

  /// Short English label for a skill (bilingual UI per CEO directive).
  static String skillLabelEn(EikenSkill skill) {
    switch (skill) {
      case EikenSkill.reading:
        return 'Reading';
      case EikenSkill.writing:
        return 'Writing';
      case EikenSkill.listening:
        return 'Listening';
    }
  }
}
