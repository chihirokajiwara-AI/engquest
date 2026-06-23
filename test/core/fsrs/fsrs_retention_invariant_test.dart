// FSRS correctness gate (8-pillar cycle-1, pillar ① 英検合格エンジン).
//
// The scheduler's entire promise is that a card falls due exactly when its
// retrievability has decayed to the target (90%). That promise only holds if
// retrievability(), nextInterval(), the factor/decay constants, and
// targetRetention all agree with each other. If any one drifts, the spacing —
// and therefore the honest 合格率 estimate built on it — silently over- or
// under-reviews, and the ¥999 "we actually get you to 合格" claim quietly breaks.
//
// These invariants lock that agreement. NOTE: difficulty mean-reversion toward
// D₀(4) is locked separately in fsrs_difficulty_reversion_test.dart and is NOT
// duplicated here.
//
// Key fact the assertions rely on: factor = 19/81 = 0.9^(1/decay) − 1 exactly,
// so R(t = S, S) = (1 + factor)^decay = 0.9 for ANY stability, and
// nextInterval(S) = round(S) (min 1). The ±0.025 bands below therefore absorb
// only integer-day interval rounding (worst case Hard: S≈1.18 → 1 day → R≈0.913);
// a genuinely broken scheduler (interval ≈ S/2 or ≈ 2S) lands far outside.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/fsrs/fsrs_algorithm.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';

void main() {
  final fsrs = FSRSAlgorithm();
  final t0 = DateTime.utc(2026, 1, 1, 12);

  FSRSCard reviewed(double s) => FSRSCard(
        vocabId: 'w',
        state: CardState.review,
        stability: s,
        difficulty: 5.0,
        reps: 1,
        lastReview: t0,
      );

  group('FSRS retention invariants', () {
    test('R(t = S days, S) == targetRetention exactly — formula⇄constant lock',
        () {
      for (final s in <double>[0.5, 1.0, 3.1262, 15.4722, 50.0, 365.0]) {
        final at = t0.add(Duration(seconds: (s * 86400).round()));
        expect(
          fsrs.retrievability(reviewed(s), at),
          closeTo(FSRSAlgorithm.targetRetention, 1e-4),
          reason: 'R at t=S must equal the target for S=$s',
        );
      }
    });

    test('nextInterval(S) == round(S) (min 1) — solves R=target for t', () {
      for (final s in <double>[0.4, 1.1829, 3.1262, 7.0, 15.4722, 49.6]) {
        expect(fsrs.nextInterval(s), math.max(1, s.round()),
            reason: 'interval must be the rounded R=target solution for S=$s');
      }
    });

    test('first Good/Hard/Easy review comes due at R≈target (day-rounded)', () {
      for (final g in <Grade>[Grade.good, Grade.hard, Grade.easy]) {
        final card = fsrs.schedule(const FSRSCard(vocabId: 'w'), g, t0);
        expect(card.state, CardState.review);
        expect(card.dueDate, isNotNull);
        final rAtDue = fsrs.retrievability(card, card.dueDate!);
        expect(
          rAtDue,
          closeTo(FSRSAlgorithm.targetRetention, 0.025),
          reason: '$g first-review due-date retrievability was $rAtDue',
        );
      }
    });

    test('5 on-time Good reviews each keep the next due-date at R≈target', () {
      var card = const FSRSCard(vocabId: 'w');
      var when = t0;
      for (var cycle = 0; cycle < 5; cycle++) {
        card = fsrs.schedule(card, Grade.good, when);
        final due = card.dueDate!;
        expect(
          fsrs.retrievability(card, due),
          closeTo(FSRSAlgorithm.targetRetention, 0.025),
          reason: 'cycle $cycle due-date retrievability drifted',
        );
        // Spacing must keep expanding as the memory strengthens (no collapse).
        expect(due.isAfter(when), isTrue,
            reason: 'interval must grow each on-time Good (cycle $cycle)');
        when = due; // next review exactly on time
      }
    });

    test('retrievability decays monotonically with elapsed time', () {
      final card = reviewed(10);
      var prev = 1.1;
      for (final days in <int>[0, 1, 3, 7, 14, 30, 90]) {
        final r = fsrs.retrievability(card, t0.add(Duration(days: days)));
        expect(r, lessThan(prev), reason: 'R must fall as t grows (t=$days)');
        prev = r;
      }
    });

    // Regression: a review-state card with stability 0 (a missing/corrupt
    // Firestore field defaults to 0) must NOT produce NaN/Infinity in the recall
    // stability update — that would crash NaN.round() on the native VM and cause
    // an infinite 1-day over-drill on web.
    test('review card with stability 0 (data gap) never yields NaN stability',
        () {
      final gap = FSRSCard(
        vocabId: 'gap',
        state: CardState.review,
        stability: 0.0,
        difficulty: 5.0,
        reps: 3,
        lastReview: t0,
        dueDate: t0,
      );
      for (final g in <Grade>[Grade.hard, Grade.good, Grade.easy]) {
        final out = fsrs.schedule(gap, g, t0);
        expect(out.stability.isFinite, isTrue,
            reason: '$g on a stability-0 review card must stay finite');
        expect(out.stability, greaterThan(0.0));
        expect(out.dueDate, isNotNull);
      }
    });
  });
}
