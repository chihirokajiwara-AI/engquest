// lib/features/exam_practice/pass/mastery_advisor.dart
// A-KEN Quest — mastery-based progression advice (adaptive difficulty, #14).
//
// Full IRT/per-item adaptive selection needs item-difficulty metadata the pool
// does not yet carry. This is the bounded, evidence-grounded first slice: use the
// child's accumulated per-grade accuracy (SkillAccuracyStore) to advise whether
// to advance a grade, keep practicing, or review easier material — the
// "threshold-accuracy → adjust difficulty" pattern from the 2026 adaptive-learning
// literature (mastery ≈ 70% over enough attempts; struggling < ~40%).
//
// Pure + deterministic (no I/O, no dart:io) so it is fully unit-testable and the
// UI (PassMeter / home) just renders the result.

import 'cse_model.dart';

/// What the learner should do next, based on demonstrated mastery.
enum ProgressionAdvice { advance, keepPracticing, reviewBasics }

/// A progression recommendation for a child at a given grade.
class MasteryRecommendation {
  final ProgressionAdvice advice;

  /// The grade id to move to (next grade for [advance], an easier grade for
  /// [reviewBasics]); null for [keepPracticing] or when already at an end grade.
  final String? suggestedGrade;

  /// Short child-friendly Japanese reason (ひらがな-leaning, font-subset-safe).
  final String reasonJa;

  const MasteryRecommendation({
    required this.advice,
    this.suggestedGrade,
    required this.reasonJa,
  });
}

/// Eiken grade ladder, easiest → hardest (mirrors the home/onboarding order).
const List<String> kGradeLadder = [
  '5',
  '4',
  '3',
  'pre2',
  'pre2plus',
  '2',
  'pre1',
];

// Evidence-grounded thresholds (mastery-based adaptive learning, 2026):
//   advance when sustained accuracy ≥ 70% over enough attempts;
//   review when accuracy < 40%; otherwise keep practicing this grade.
const double kMasteryAccuracy = 0.70;
const double kStruggleAccuracy = 0.40;
const int kMinAttemptsForAdvice = 12;

/// Advise whether the child at [grade] should advance, keep practicing, or
/// review, from their accumulated per-skill [skills] accuracy. Pure function.
MasteryRecommendation adviseProgression(
  String grade,
  List<SkillAccuracy> skills,
) {
  final totalAttempts = skills.fold<int>(0, (sum, a) => sum + a.itemsAttempted);

  // Not enough evidence yet → keep practicing (conservative, no false advice).
  if (totalAttempts < kMinAttemptsForAdvice) {
    return const MasteryRecommendation(
      advice: ProgressionAdvice.keepPracticing,
      reasonJa: 'もうすこし といて、じつりょくを ためしてみよう。',
    );
  }

  // Attempt-weighted overall accuracy: Σ(correct) / Σ(attempts).
  final totalCorrect =
      skills.fold<double>(0, (sum, a) => sum + a.accuracy * a.itemsAttempted);
  final overall = totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts;

  final idx = kGradeLadder.indexOf(grade);
  final atTop = idx < 0 || idx >= kGradeLadder.length - 1;
  final atBottom = idx <= 0;

  if (overall >= kMasteryAccuracy && !atTop) {
    return MasteryRecommendation(
      advice: ProgressionAdvice.advance,
      suggestedGrade: kGradeLadder[idx + 1],
      reasonJa: 'たくさん せいかいできてるね！つぎの きゅうに ちょうせんしてみよう。',
    );
  }

  if (overall < kStruggleAccuracy && !atBottom) {
    return MasteryRecommendation(
      advice: ProgressionAdvice.reviewBasics,
      suggestedGrade: kGradeLadder[idx - 1],
      reasonJa: 'あせらず きそを かためよう。ひとつ やさしい きゅうも れんしゅうに いいよ。',
    );
  }

  return const MasteryRecommendation(
    advice: ProgressionAdvice.keepPracticing,
    reasonJa: 'この きゅうを もうすこし れんしゅう！あと すこしで マスターだよ。',
  );
}
