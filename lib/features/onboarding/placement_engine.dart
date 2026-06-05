// lib/features/onboarding/placement_engine.dart
//
// Adaptive placement engine for A-KEN Quest.
// Pure Dart — NO Flutter import — so this file is fully unit-testable.
//
// Algorithm (spec: docs/design/PLACEMENT-DIAGNOSTIC-PLAN.json §adaptiveSpec)
// ──────────────────────────────────────────────────────────────────────────
//  θ LADDER  0=5級(A1−)  1=4級(A1)  2=3級(A1+)  3=準2級(A2)
//            4=準2級プラス(A2+)  5=2級(B1)  6=準1級(B2)
//
//  1. AGE SEED — biggest item-saver; prevents a 13-yo from seeing dog=いぬ.
//  2. ITEM SELECTION — pick unused item whose grade == round(θ̂).
//  3. EWMA UPDATE — step = max(0.5, 1.5 − 0.25·n); clamp θ to [0, 6].
//  4. NON-DISCOURAGE GUARD — after wrong answer, next grade = floor(θ̂)
//     rather than round; avoids two consecutive items a child just failed.
//  5. STOPPING — min 3 / max 8 items; early stop when ceiling stable.
//  6. RESULT — highest rung with ≥2/3 correct and next failed;
//     barely-cleared (exactly 2/3, volatile) → one rung down;
//     hit max without convergence → low confidence.

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// PlacementItem — mirrors PlacementQuestion but richer (grade + skill).
// ---------------------------------------------------------------------------

class PlacementItem {
  /// θ rung index (0=5級 … 6=準1級).
  final int grade;

  /// 'vocab' | 'grammar' | 'readingGist'
  final String skill;

  /// English stem / question text.
  final String stemEn;

  /// Optional Japanese gloss / translation (may be null for grammar items).
  final String? stemJa;

  /// Four same-type, same-language answer choices.
  final List<String> choices;

  /// Index of the correct choice in [choices].
  final int correctIndex;

  const PlacementItem({
    required this.grade,
    required this.skill,
    required this.stemEn,
    this.stemJa,
    required this.choices,
    required this.correctIndex,
  });
}

// ---------------------------------------------------------------------------
// PlacementOutcome — what the engine returns when done.
// ---------------------------------------------------------------------------

/// Placement confidence level.
enum PlacementConfidence {
  /// Last 3 items converged cleanly (passes r, fails r+1).
  high,

  /// Stopped at max length but θ̂ was reasonably stable.
  medium,

  /// Hit max length with high θ volatility.
  low,
}

class PlacementOutcome {
  /// θ rung (0..6) at which the child is placed.
  final int grade;

  /// Canonical 英検 level string used by QuestMapScreen.startLevel.
  /// One of: '5' | '4' | '3' | 'pre2' | 'pre2plus' | '2' | 'pre1'
  final String eikenLevel;

  /// CEFR band label for display.
  final String cefr;

  /// Confidence in the placement.
  final PlacementConfidence confidence;

  /// Final θ̂ value — persisted so T12 adaptive difficulty can start here.
  final double theta;

  const PlacementOutcome({
    required this.grade,
    required this.eikenLevel,
    required this.cefr,
    required this.confidence,
    required this.theta,
  });
}

// ---------------------------------------------------------------------------
// Grade ↔ string maps
// ---------------------------------------------------------------------------

const List<String> _kEikenLevels = [
  '5',         // rung 0
  '4',         // rung 1
  '3',         // rung 2
  'pre2',      // rung 3
  'pre2plus',  // rung 4
  '2',         // rung 5
  'pre1',      // rung 6
];

const List<String> _kCefrLabels = [
  'A1−',  // 5級
  'A1',   // 4級
  'A1+',  // 3級
  'A2',   // 準2級
  'A2+',  // 準2級プラス
  'B1',   // 2級
  'B2',   // 準1級
];

// ---------------------------------------------------------------------------
// PlacementEngine
// ---------------------------------------------------------------------------

class PlacementEngine {
  /// Current ability estimate (0.0 … 6.0).
  double theta;

  /// Grade (rung) of each item presented, in order.
  final List<int> askedGrades = [];

  /// Ids (indices within the full bank) of items already used, to avoid
  /// exact repetition within one session.
  final Set<int> usedItemIds = {};

  /// Answer history (true = correct).
  final List<bool> answers = [];

  /// Number of items answered so far.
  int get n => answers.length;

  // ── Constructor ───────────────────────────────────────────────────────────

  /// Seed θ from child's age (§1).
  ///
  /// Optional [selfReportShift] (-1/0/+1) from an optional one-tap
  /// "英語を習ったことは？" self-report.  Clamped to [0, 6].
  PlacementEngine.fromAge(int age, {int selfReportShift = 0})
      : theta = (_seed(age) + selfReportShift).clamp(0.0, 6.0);

  // ── §1: Age seed ──────────────────────────────────────────────────────────

  static double _seed(int age) {
    if (age <= 6) return 0.0;
    if (age <= 9) return 1.0;
    if (age <= 12) return 2.0;
    if (age <= 15) return 3.0;
    return 4.0;
  }

  // ── §2 + §3 guard: Which grade to present next ───────────────────────────

  /// Returns the rung (0..6) whose item should be presented next.
  ///
  /// NON-DISCOURAGE GUARD: after a wrong answer, use floor(θ) instead of
  /// round(θ) so the next item is slightly easier — prevents a failure spiral.
  int nextGrade() {
    if (answers.isNotEmpty && !answers.last) {
      // Last answer wrong → floor (easier)
      return theta.floor().clamp(0, 6);
    }
    return theta.round().clamp(0, 6);
  }

  // ── §3: Record answer + EWMA update ──────────────────────────────────────

  /// Record whether the child answered correctly, update θ̂, and log the
  /// grade of the item just presented.
  void record(bool correct, {required int grade}) {
    final step = math.max(0.5, 1.5 - 0.25 * n);
    theta = (theta + (correct ? step : -step)).clamp(0.0, 6.0);
    answers.add(correct);
    askedGrades.add(grade);
  }

  // ── §4: Stopping rule ─────────────────────────────────────────────────────

  /// Returns true when the engine should stop asking questions.
  bool get done {
    if (n < 3) return false;
    if (n >= 8) return true;
    return _ceilingStable();
  }

  /// Ceiling-stable: last ≥3 items are split across two consecutive rungs r and
  /// r+1, child passes r items and fails r+1 items consistently.
  bool _ceilingStable() {
    if (n < 3) return false;
    // Look at the last 3 items.
    final lastGrades = askedGrades.sublist(n - 3);
    final lastAnswers = answers.sublist(n - 3);

    final uniqueGrades = lastGrades.toSet();
    // Need at most 2 distinct rungs.
    if (uniqueGrades.length > 2) return false;

    if (uniqueGrades.length == 1) {
      // All at the same rung — stable if all passed (ceiling above) or all
      // failed (ceiling below), but we need at least one pass+fail pair to
      // confirm the ceiling, so return false unless consistently all failed
      // (θ has been pushed down, this is stable at rung 0 floor).
      final r = uniqueGrades.first;
      if (r == 0 && lastAnswers.every((a) => !a)) return true;
      // If all passed at the same rung we don't yet know the ceiling.
      return false;
    }

    // Two distinct rungs: check they are consecutive.
    final sortedRungs = uniqueGrades.toList()..sort();
    if (sortedRungs[1] - sortedRungs[0] != 1) return false;

    final lowerRung = sortedRungs[0];
    final upperRung = sortedRungs[1];

    // Lower rung items must all be correct; upper rung items must all be wrong.
    for (var i = 0; i < 3; i++) {
      if (lastGrades[i] == lowerRung && !lastAnswers[i]) return false;
      if (lastGrades[i] == upperRung && lastAnswers[i]) return false;
    }
    return true;
  }

  // ── §5: Final placement ───────────────────────────────────────────────────

  /// Compute the final [PlacementOutcome].
  ///
  /// Algorithm:
  ///   • highest rung r where ≥2/3 of presented r-items are correct
  ///     AND child did NOT pass r+1 items (or none were asked at r+1).
  ///   • barely-cleared (exactly 2/3 of r-items correct) → placed one rung down.
  ///   • hit max length without converging → low confidence.
  PlacementOutcome result() {
    // Build per-rung stats.
    final Map<int, List<bool>> rungAnswers = {};
    for (var i = 0; i < n; i++) {
      rungAnswers.putIfAbsent(askedGrades[i], () => []).add(answers[i]);
    }

    // Find the highest rung r where pass rate ≥ 2/3.
    int placedGrade = 0;
    bool barelyCleared = false;

    for (var r = 6; r >= 0; r--) {
      final ras = rungAnswers[r];
      if (ras == null || ras.isEmpty) continue;
      final correct = ras.where((a) => a).length;
      final total = ras.length;
      if (correct / total >= 2 / 3) {
        placedGrade = r;
        // "barely cleared" = exactly 2/3 (e.g. 2 correct out of 3)
        barelyCleared = (correct == 2 && total == 3) ||
            (correct * 3 == total * 2 && total > 3);
        break;
      }
    }

    // Barely cleared → one rung down (kinder start, builds momentum).
    if (barelyCleared && placedGrade > 0) {
      placedGrade--;
    }

    // Confidence.
    PlacementConfidence confidence;
    if (n >= 8) {
      // Check if θ was volatile (still moving a lot in last 3 items).
      final lastThreeCorrect = answers.sublist(n - 3).where((a) => a).length;
      confidence = (lastThreeCorrect == 0 || lastThreeCorrect == 3)
          ? PlacementConfidence.medium
          : PlacementConfidence.low;
    } else if (_ceilingStable()) {
      confidence = PlacementConfidence.high;
    } else {
      confidence = PlacementConfidence.medium;
    }

    // Low confidence → conservative (already handled by barely-cleared rule,
    // but also pull down one step from volatile max-length stop).
    if (confidence == PlacementConfidence.low && placedGrade > 0) {
      placedGrade--;
    }

    return PlacementOutcome(
      grade: placedGrade,
      eikenLevel: _kEikenLevels[placedGrade],
      cefr: _kCefrLabels[placedGrade],
      confidence: confidence,
      theta: theta,
    );
  }
}
