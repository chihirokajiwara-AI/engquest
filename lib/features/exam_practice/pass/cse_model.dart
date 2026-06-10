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
//   準2級+ |  1875   |  1402   | R:625  W:625   L:625           | R, W, L (2025新設)
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
// 合格率 is a 目安 (rough readiness guide), NOT a probabilistic or precise model.
//
// HONEST READINESS MODEL (corrected 2026-06-09, flaw-hunt #113 — expert-with-
// latest, 14 dated sources incl. eiken.or.jp/cse, ESLclub 2026-05-17, eigoful
// 2025-11-30, samuraienglish 2025):
//   The OLD model did `skillCSE = rawAccuracy × skillMaxCSE` then
//   `readiness = totalCSE / passingCSE`. That is WRONG: 英検 CSE is IRT-equated
//   and NON-LINEAR vs raw accuracy. The official 一次 passing CSE fraction
//   (e.g. 準1 1792/2250 = 79.6%) is NOT a raw-accuracy requirement — empirically
//   a 準1 candidate passes at ~65–70% RAW (協会: 1級/準1≈各技能7割, 2級以下≈6割;
//   the IRT curve compresses raw→CSE in the mid-range). The linear model
//   therefore told passing children "まだ合格圏外" and could pass under-prepared
//   ones. FIX: readiness is the child's RAW accuracy relative to the published
//   per-grade passing raw-accuracy 目安 (0.60 for 5級–2級, 0.70 for 準1級), with
//   each skill's contribution CAPPED at the target (so one strong skill can't
//   over-bank a missing one). Everything is labelled 目安; we never claim a
//   precise pass probability or a "あと N CSEポイント" gap (raw→CSE tables are
//   non-public and change every administration).
//
//   passTargetRaw — 目安 only (協会 2016 raw-rate note + 2025/26 塾 estimates):
//     5級/4級/3級/準2級/準2級プラス/2級 → 0.60   準1級 → 0.70
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

  /// Readiness toward the passing raw-accuracy 目安 (0–100). Each applicable
  /// skill contributes min(rawAccuracy, [passTargetRaw]); readinessPct =
  /// Σcontributions / (skillCount × passTargetRaw) × 100. 100 means every
  /// measured skill has reached the grade's 目安 line. This is a 目安, NOT a
  /// precise pass probability.
  final double readinessPct;

  /// The grade's passing raw-accuracy 目安 (e.g. 0.60 / 0.70) — the line each
  /// skill's accuracy is measured against. Disclosed so the UI can show it.
  final double passTargetRaw;

  /// The skill with the lowest raw accuracy (the bottleneck the UI highlights).
  /// null when no skills have data.
  final EikenSkill? limitingSkill;

  /// Applicable skills the learner has NO data for (itemsAttempted == 0). These
  /// score 0 in [skillScores], but that 0 means "not yet measured", NOT "tested
  /// and failed" — the UI must show them as 未測定 so 合格率 is honest. Empty
  /// when every applicable skill has data.
  final Set<EikenSkill> unmeasuredSkills;

  /// Per-skill number of questions the estimate is built on
  /// ({EikenSkill → itemsAttempted}). The 合格率 must DISCLOSE its basis — a 92%
  /// built on 2 writing items is not the same as one built on 200. The UI shows
  /// these counts (and a "rough estimate" caption when the sample is thin) so the
  /// number is credible rather than reading as fabricated.
  final Map<EikenSkill, int> itemsAttempted;

  const CseEstimate({
    required this.grade,
    required this.skillScores,
    required this.totalScore,
    required this.passingScore,
    required this.maxScore,
    required this.readinessPct,
    required this.passTargetRaw,
    required this.limitingSkill,
    this.unmeasuredSkills = const {},
    this.itemsAttempted = const {},
  });

  /// Total questions answered across all skills — the overall basis of the %.
  int get totalItemsAttempted => itemsAttempted.values.fold(0, (s, v) => s + v);

  /// True when every applicable skill has reached the passing raw-accuracy 目安
  /// AND every applicable skill has been measured. Framed as 「合格圏の目安に到達」
  /// — NOT a guaranteed pass (英検 scoring is IRT-equated + compensatory; this is
  /// a guide). Capping each skill at the target means readinessPct can only reach
  /// 100 when no skill is below the 目安 and none is 未測定.
  bool get reachedPassMeyasu =>
      readinessPct >= 100.0 && unmeasuredSkills.isEmpty;

  /// Back-compat alias for existing UI; reframed as 目安-reached, not a hard pass.
  bool get isPredictedPass => reachedPassMeyasu;
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
  // 準2級プラス (2025 new grade). Verified eiken.or.jp 2025newgrade (2026-06-07):
  // per-skill 一次 CSE max 625 → 一次満点 625×3 = 1875; 一次合格基準 1402.
  'pre2plus': _GradeSpec(
    grade: 'pre2plus',
    skills: [EikenSkill.reading, EikenSkill.writing, EikenSkill.listening],
    firstPassScore: 1402,
    firstMaxScore: 1875,
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

/// Passing raw-accuracy 目安 per grade (flaw-hunt #113, expert-with-latest
/// 2026-06-09). 協会: 1級/準1≈各技能7割, 2級以下≈各技能6割 (eiken.or.jp 合否判定,
/// a 2016 statement — 目安 only); corroborated by 2025/26 塾 raw→CSE tables
/// (準1 passes at ~65–70% raw, NOT the 79.6% CSE fraction). Default 0.60.
const Map<String, double> _kPassTargetRaw = {
  '5': 0.60,
  '4': 0.60,
  '3': 0.60,
  'pre2': 0.60,
  'pre2plus': 0.60,
  '2': 0.60,
  'pre1': 0.70,
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
    final attempted = <EikenSkill, int>{};

    // Build an accuracy lookup (unrecognised skills are ignored).
    final accMap = {for (final a in accuracies) a.skill: a};

    for (final skill in spec.skills) {
      final acc = accMap[skill];
      final max = maxScores[skill]!;
      attempted[skill] = acc?.itemsAttempted ?? 0;
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

    // HONEST readiness (#113): the child's RAW accuracy vs the published passing
    // raw-accuracy 目安 — NOT the CSE fraction. Each applicable skill contributes
    // min(rawAccuracy, target); unmeasured skills contribute 0 (you haven't
    // banked them). Capping at the target prevents one strong skill from
    // over-banking a missing/weak one, so readinessPct can reach 100 ONLY when
    // every measured skill is at the 目安 and none is 未測定. This bakes the
    // raw→CSE non-linearity into the empirical target instead of a linear CSE sum.
    final target = _kPassTargetRaw[grade] ?? 0.60;
    double banked = 0.0;
    for (final skill in spec.skills) {
      final acc = accMap[skill];
      if (acc != null && acc.attempted) {
        banked += acc.accuracy.clamp(0.0, target);
      }
    }
    final denom = spec.skills.length * target;
    final readinessPct =
        (denom == 0 ? 0.0 : banked / denom * 100.0).clamp(0.0, 100.0);

    // Limiting skill = the skill with the LOWEST raw accuracy (the bottleneck).
    // Ratio = score / skillMax = rawAccuracy (skillMax is constant per skill), so
    // this is equivalently the lowest-accuracy skill.
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
      passTargetRaw: target,
      limitingSkill: limiting,
      unmeasuredSkills: Set.unmodifiable(unmeasured),
      itemsAttempted: Map.unmodifiable(attempted),
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

  /// Honest "how close am I" line for the meter (no fabricated CSE-point gap).
  /// Bands per the expert design (#113): 未測定あり / 合格圏の目安 / あと少し / コツコツ.
  static String readinessMessageJa(CseEstimate est) {
    if (est.unmeasuredSkills.isNotEmpty) {
      return 'まだ れんしゅうしていない ぎのうが あるよ';
    }
    if (est.reachedPassMeyasu) return '合格圏（ごうかくけん）の目安（めやす）に とどいた！';
    if (est.readinessPct >= 65) return '合格（ごうかく）の目安（めやす）まで あと少（すこ）し！';
    return 'コツコツ つづけよう';
  }

  /// Standing honesty disclaimer shown beside any readiness number (#113).
  static const String meyasuDisclaimerJa =
      '※これは目安（めやす）です。本番（ほんばん）のスコアは IRT という方法（ほうほう）で'
      '計算（けいさん）され、回（かい）ごとに変（か）わります。';

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
