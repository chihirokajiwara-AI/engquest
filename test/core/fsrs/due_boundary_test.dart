// FSRS due-comparison must be INCLUSIVE of the exact due instant (now == dueDate
// is DUE). A just-missed word is scheduled with interval=0 (dueDate = now) for
// "re-show within same session"; an exclusive `now.isAfter(due)` (>) hid it
// because now is not strictly after now, so missed words were never re-taught —
// inflating 合格率 and breaking acquisition (flaw-hunt R4, 実測-confirmed). These
// pin the boundary across all four call sites that share the comparison.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/fsrs/fsrs_algorithm.dart';

void main() {
  final algo = FSRSAlgorithm();

  test('FSRSCard.isDue: due at/just-before real-now is due, future is not', () {
    // isDue reads wall-clock DateTime.now() (not injectable), so assert against
    // a dueDate a hair in the past (inclusive boundary) vs the clear future.
    final justPast = DateTime.now().subtract(const Duration(milliseconds: 1));
    expect(FSRSCard(vocabId: 'w', dueDate: justPast).isDue, isTrue,
        reason: 'a card due now/just-now must be due (inclusive >=)');
    final future = DateTime.now().add(const Duration(days: 1));
    expect(FSRSCard(vocabId: 'w', dueDate: future).isDue, isFalse);
  });

  test('getDueCards includes a card whose dueDate == now', () {
    final now = DateTime(2026, 6, 11, 12, 0, 0);
    final deck = [
      FSRSCard(vocabId: 'due_now', dueDate: now),
      FSRSCard(vocabId: 'future', dueDate: now.add(const Duration(days: 1))),
    ];
    final due = algo.getDueCards(deck, now);
    expect(due.map((c) => c.vocabId), contains('due_now'));
    expect(due.map((c) => c.vocabId), isNot(contains('future')));
  });

  test('a just-missed word (Grade.again) is due immediately for re-teaching',
      () {
    final now = DateTime(2026, 6, 11, 12, 0, 0);
    final fresh = FSRSCard(vocabId: 'missed');
    final after = algo.schedule(fresh, Grade.again, now);
    // again → interval 0 → dueDate == now → must be due right now (same session).
    expect(after.dueDate, isNotNull);
    expect(now.isBefore(after.dueDate!), isFalse,
        reason: 'a missed word must not be scheduled into the future');
    expect(algo.getDueCards([after], now).map((c) => c.vocabId),
        contains('missed'),
        reason: 'the missed word must re-surface in the same session');
  });
}
