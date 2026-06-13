// lib/core/fsrs/fsrs_algorithm.dart
// ENG Quest — FSRS-4.5 Algorithm (C05)
// Dart port of /root/engquest/src/spikes/fsrs-dart/fsrs_poc.py (Spike S02)
//
// Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
// All formula comments reference the FSRS-4.5 wiki notation.

import 'dart:math' as math;
import 'fsrs_card.dart';

/// FSRS-4.5 scheduler.
///
/// Stateless pure-function implementation — call [schedule] with the current
/// [FSRSCard] and the user's [Grade]; receive back a new [FSRSCard] with
/// updated stability / difficulty / dueDate / state.
class FSRSAlgorithm {
  // ── FSRS-4.5 default weight vector (19 elements) ──────────────────────────
  static const List<double> w = [
    0.4072,
    1.1829,
    3.1262,
    15.4722,
    7.2102,
    0.5316,
    1.0651,
    0.0589,
    1.5330,
    0.1544,
    1.0070,
    1.9290,
    0.1100,
    0.2900,
    2.2700,
    0.2500,
    2.9898,
    0.5100,
    0.3400,
  ];

  // R(t,S) = (1 + FACTOR * t/S)^DECAY
  static const double factor = 19.0 / 81.0; // ≈ 0.2346
  static const double decay = -0.5;

  /// Target retention probability used to compute intervals (90 %)
  static const double targetRetention = 0.9;

  // ── Initial values after first review ────────────────────────────────────

  /// D₀(G) = w₄ − exp(w₅ · (G−1)) + 1
  double initialDifficulty(Grade g) {
    return w[4] - math.exp(w[5] * (g.index1 - 1)) + 1;
  }

  /// S₀(G) = w[G−1]  (1-indexed: again=w[0], hard=w[1], good=w[2], easy=w[3])
  double initialStability(Grade g) {
    return math.max(w[g.index], 0.1);
  }

  // ── Retrievability ────────────────────────────────────────────────────────

  /// R(t, S) = (1 + FACTOR · t/S)^DECAY
  ///
  /// [t] is elapsed time in days since [card.lastReview].
  /// Returns 0 if the card has never been reviewed.
  double retrievability(FSRSCard card, DateTime now) {
    if (card.lastReview == null || card.stability <= 0) return 0.0;
    final t = now.difference(card.lastReview!).inSeconds / 86400.0;
    if (t < 0) return 1.0;
    final base = 1.0 + factor * t / card.stability;
    if (base <= 0) return 0.0;
    return math.pow(base, decay).toDouble();
  }

  // ── Subsequent-review difficulty ──────────────────────────────────────────

  /// D′ = D − w₆·(G−3)  then mean-revert toward D₀(4): D′ + w₇·(D₀(4) − D′).
  /// The published FSRS reversion target is D₀(4) — the EASY-grade initial
  /// difficulty (≈3.28) — NOT the raw weight w[4] (≈7.21 = the Again-grade D₀(1)).
  /// Using w[4] drove well-known cards to D≈7.21, halving the (11−D) stability
  /// factor → intervals ~51% short → mastered vocab over-reviewed ~2× (fix
  /// 2026-06-13, verified vs expertium FSRS spec + a convergence unit test).
  double _nextDifficulty(double d, Grade g) {
    final dPrime = d - w[6] * (g.index1 - 3);
    final target = initialDifficulty(Grade.easy); // D₀(4)
    final reverted = dPrime + w[7] * (target - dPrime);
    return reverted.clamp(1.0, 10.0);
  }

  // ── Stability after successful recall ─────────────────────────────────────

  /// S′ᵣ = S · (exp(w₈) · (11−D) · S^(−w₉) · (exp((1−R)·w₁₀)−1) · hp · eb)
  /// where hp = w₁₅ if hard, eb = w₁₆ if easy, else 1.
  double _nextStabilityRecall(double d, double s, double r, Grade g) {
    final hardPenalty = g == Grade.hard ? w[15] : 1.0;
    final easyBonus = g == Grade.easy ? w[16] : 1.0;
    final rClamped = r.clamp(0.0, 0.999); // avoid exp((1-1)*w10)-1 = 0
    final result = s *
        math.exp(w[8]) *
        (11 - d) *
        math.pow(s, -w[9]) *
        (math.exp((1 - rClamped) * w[10]) - 1) *
        hardPenalty *
        easyBonus;
    return math.max(result.toDouble(), 0.1);
  }

  // ── Stability after forgetting (Again) ───────────────────────────────────

  /// S′f = w₁₁ · D^(−w₁₂) · ((S+1)^w₁₃ − 1) · exp((1−R)·w₁₄)
  double _nextStabilityForget(double d, double s, double r) {
    final sSafe = math.max(s, 0.01);
    final result = w[11] *
        math.pow(d, -w[12]) *
        (math.pow(sSafe + 1, w[13]) - 1) *
        math.exp((1 - r) * w[14]);
    return math.max(result.toDouble(), 0.1);
  }

  // ── Short-term stability (learning/relearning step) ───────────────────────

  /// S_short = S · exp(w₁₇ · (G−3+w₁₈))
  double _shortTermStability(double s, Grade g) {
    final result = s * math.exp(w[17] * (g.index1 - 3 + w[18]));
    return math.max(result.toDouble(), 0.1);
  }

  // ── Interval computation ──────────────────────────────────────────────────

  /// Solve R(t,S) = targetRetention for t:
  ///   t = S / FACTOR · (R^(1/DECAY) − 1)
  ///
  /// At FSRS-4.5 defaults with R=0.9, t ≈ S (days).
  int nextInterval(double stability) {
    final interval =
        stability / factor * (math.pow(targetRetention, 1.0 / decay) - 1);
    return math.max(1, interval.round());
  }

  // ── Main scheduler ────────────────────────────────────────────────────────

  /// Apply [grade] to [card] at [now] and return a new [FSRSCard].
  ///
  /// State-machine:
  ///   NEW       → first review; sets initial D + S; goes to LEARNING or REVIEW
  ///   LEARNING / RELEARNING → short-term step; promotes to REVIEW if grade ≠ again
  ///   REVIEW    → full recall/forget update
  FSRSCard schedule(FSRSCard card, Grade grade, DateTime now) {
    double newDifficulty;
    double newStability;
    CardState newState;
    int lapses = card.lapses;
    int interval;

    switch (card.state) {
      // ── First exposure ─────────────────────────────────────────────────────
      case CardState.newCard:
        newDifficulty = initialDifficulty(grade);
        newStability = initialStability(grade);
        if (grade == Grade.again) {
          newState = CardState.learning;
          interval = 0; // re-show within same session
        } else {
          newState = CardState.review;
          interval = nextInterval(newStability);
        }

      // ── In learning / relearning ──────────────────────────────────────────
      case CardState.learning:
      case CardState.relearning:
        newDifficulty = _nextDifficulty(card.difficulty, grade);
        newStability = _shortTermStability(
          math.max(card.stability, 0.1),
          grade,
        );
        if (grade == Grade.again) {
          newState = card.state; // stay in learning/relearning
          interval = 0;
        } else {
          newState = CardState.review;
          interval = nextInterval(newStability);
        }

      // ── Scheduled review ──────────────────────────────────────────────────
      case CardState.review:
        final r = retrievability(card, now);
        newDifficulty = _nextDifficulty(card.difficulty, grade);
        if (grade == Grade.again) {
          lapses = lapses + 1;
          newStability = _nextStabilityForget(newDifficulty, card.stability, r);
          newState = CardState.relearning;
          interval = 0;
        } else {
          newStability =
              _nextStabilityRecall(newDifficulty, card.stability, r, grade);
          newState = CardState.review;
          interval = nextInterval(newStability);
        }
    }

    final due = interval == 0
        ? now // re-show immediately (same session)
        : now.add(Duration(days: interval));

    return card.copyWith(
      state: newState,
      difficulty: newDifficulty,
      stability: newStability,
      lapses: lapses,
      reps: card.reps + 1,
      lastReview: now,
      dueDate: due,
    );
  }

  // ── Deck helpers ──────────────────────────────────────────────────────────

  /// All cards where [FSRSCard.isDue] is true at [now].
  List<FSRSCard> getDueCards(List<FSRSCard> deck, DateTime now) {
    return deck
        .where((c) => c.dueDate == null || !now.isBefore(c.dueDate!))
        .toList();
  }

  /// Build a fresh [FSRSCard] for every vocab ID in [vocabIds].
  /// Useful for creating an initial deck from [kVocabA1].
  static List<FSRSCard> buildDeck(List<String> vocabIds) {
    return vocabIds.map((id) => FSRSCard(vocabId: id)).toList();
  }
}
