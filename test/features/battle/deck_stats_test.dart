// Locks the cumulative deck-stat counters that feed achievements + the progress
// record. Regression (flaw-hunt 2026-06-14): the achievement check was fed
// `_sessionResults.length` (THIS session's ~10-20 cards), so the monotonic
// practice progress never reached practice_50/200/500 and those badges could
// never unlock; the Firestore record used the WHOLE grade vocab length,
// over-reporting the other way. Both now use practicedCardCount.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/features/battle/battle_screen.dart';

FSRSCard _card(String id, CardState state) =>
    FSRSCard(vocabId: id, state: state);

void main() {
  group('deck stat counters', () {
    test('mastered = review-state cards only', () {
      final deck = [
        _card('a', CardState.newCard),
        _card('b', CardState.learning),
        _card('c', CardState.review),
        _card('d', CardState.review),
        _card('e', CardState.relearning),
      ];
      expect(masteredCardCount(deck), 2); // c, d
    });

    test('practiced = every card that has left the new state', () {
      final deck = [
        _card('a', CardState.newCard),
        _card('b', CardState.learning),
        _card('c', CardState.review),
        _card('d', CardState.relearning),
      ];
      expect(practicedCardCount(deck), 3); // b, c, d (not a)
    });

    test('a fresh deck (all new) earns NO practice/mastery — no free badges',
        () {
      final deck = List.generate(600, (i) => _card('w$i', CardState.newCard));
      expect(practicedCardCount(deck), 0);
      expect(masteredCardCount(deck), 0);
    });

    test('INVARIANT: mastered <= practiced (review ⊂ not-new)', () {
      final deck = [
        for (var i = 0; i < 20; i++) _card('n$i', CardState.newCard),
        for (var i = 0; i < 15; i++) _card('l$i', CardState.learning),
        for (var i = 0; i < 30; i++) _card('r$i', CardState.review),
      ];
      expect(
          masteredCardCount(deck), lessThanOrEqualTo(practicedCardCount(deck)));
      expect(masteredCardCount(deck), 30);
      expect(practicedCardCount(deck), 45);
    });

    test('cumulative count reaches the practice_50 target (the regression)',
        () {
      // 60 studied cards across sessions → practicedCardCount = 60, which clears
      // practice_50 (target 50). The old per-session count (~10-20) never did.
      final deck = [
        for (var i = 0; i < 60; i++) _card('p$i', CardState.review),
        for (var i = 0; i < 200; i++) _card('new$i', CardState.newCard),
      ];
      expect(practicedCardCount(deck), 60);
      expect(practicedCardCount(deck), greaterThanOrEqualTo(50));
    });
  });
}
