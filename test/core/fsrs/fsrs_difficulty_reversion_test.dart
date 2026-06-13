// FSRS correctness gate (flaw-hunt 2026-06-13): difficulty must mean-revert toward
// D₀(4) — the Easy-grade initial difficulty (≈3.28) — per the published FSRS-4.5/5
// algorithm (D' = w₇·D₀(4) + (1−w₇)·next_d). A prior bug reverted toward the raw
// weight w[4] (≈7.21 = the Again-grade D₀(1)), driving well-known cards to D≈7.21,
// which halves the (11−D) stability factor → intervals ~51% too short → mastered
// vocab resurfaces ~2× too often. This locks the correct convergence.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/fsrs/fsrs_algorithm.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';

void main() {
  test('difficulty mean-reverts toward D₀(4) (~3.28), not w[4] (~7.21)', () {
    final fsrs = FSRSAlgorithm();
    final d0easy = fsrs.initialDifficulty(Grade.easy); // ≈ 3.28
    expect(d0easy, lessThan(5.0), reason: 'D₀(4) is the easy end of 1–10');

    var card = const FSRSCard(
      vocabId: 'x',
      state: CardState.review,
      stability: 10,
      difficulty: 8.0, // start high
      reps: 1,
    ).copyWith(lastReview: DateTime(2026, 1, 1));

    var now = DateTime(2026, 1, 1);
    for (var i = 0; i < 50; i++) {
      now = now.add(const Duration(days: 1));
      card = fsrs.schedule(card, Grade.good, now);
    }

    // Converges to the Easy-initial target, NOT the buggy 7.21 fixed point.
    expect(card.difficulty, closeTo(d0easy, 0.5),
        reason: 'repeated Good must settle difficulty at D₀(4), not w[4]');
    expect(card.difficulty, lessThan(5.0),
        reason: 'a mastered card must not be stuck at high difficulty (~7.21)');
  });
}
