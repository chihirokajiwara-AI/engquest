// test/core/fsrs/fsrs_card_repository_test.dart
// ENG Quest — Unit tests for InMemoryFsrsCardRepository
//
// Run: dart test test/core/fsrs/fsrs_card_repository_test.dart

import 'package:test/test.dart';
import 'package:engquest/core/fsrs/fsrs_algorithm.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';

void main() {
  late InMemoryFsrsCardRepository repo;
  const userId = 'user_test_001';

  setUp(() {
    repo = InMemoryFsrsCardRepository();
  });

  group('loadDeck', () {
    test('returns empty list for new user', () async {
      final deck = await repo.loadDeck(userId);
      expect(deck, isEmpty);
    });

    test('returns all saved cards for user', () async {
      final cards = FSRSAlgorithm.buildDeck(['w001', 'w002', 'w003']);
      await repo.saveCards(userId, cards);
      final loaded = await repo.loadDeck(userId);
      expect(loaded.length, equals(3));
    });

    test('user isolation: different users have separate decks', () async {
      await repo.saveCard(userId, FSRSCard(vocabId: 'w001'));
      await repo.saveCard('other_user', FSRSCard(vocabId: 'w002'));
      final deck1 = await repo.loadDeck(userId);
      final deck2 = await repo.loadDeck('other_user');
      expect(deck1.length, equals(1));
      expect(deck2.length, equals(1));
      expect(deck1.first.vocabId, equals('w001'));
      expect(deck2.first.vocabId, equals('w002'));
    });
  });

  group('saveCard', () {
    test('new card is persisted and retrievable', () async {
      final card = FSRSCard(vocabId: 'vocab_001');
      await repo.saveCard(userId, card);
      final loaded = await repo.loadDeck(userId);
      expect(loaded.length, equals(1));
      expect(loaded.first.vocabId, equals('vocab_001'));
    });

    test('saving same vocabId overwrites previous state', () async {
      final original = FSRSCard(vocabId: 'vocab_001');
      await repo.saveCard(userId, original);

      final fsrs = FSRSAlgorithm();
      final updated = fsrs.schedule(original, Grade.good, DateTime.now());
      await repo.saveCard(userId, updated);

      final loaded = await repo.loadDeck(userId);
      expect(loaded.length, equals(1)); // not duplicated
      expect(loaded.first.reps, equals(1));
      expect(loaded.first.stability, greaterThan(0));
    });

    test('all FSRSCard fields survive JSON round-trip', () async {
      final fsrs = FSRSAlgorithm();
      var card = FSRSCard(vocabId: 'rtt_001');
      card = fsrs.schedule(card, Grade.good, DateTime.now());
      await repo.saveCard(userId, card);
      final loaded = (await repo.loadDeck(userId)).first;

      expect(loaded.vocabId, equals(card.vocabId));
      expect(loaded.state, equals(card.state));
      expect(loaded.stability, closeTo(card.stability, 0.0001));
      expect(loaded.difficulty, closeTo(card.difficulty, 0.0001));
      expect(loaded.reps, equals(card.reps));
      expect(loaded.lapses, equals(card.lapses));
      expect(loaded.dueDate?.toIso8601String(),
          equals(card.dueDate?.toIso8601String()));
      expect(loaded.lastReview?.toIso8601String(),
          equals(card.lastReview?.toIso8601String()));
    });

    test('all CardState values survive round-trip', () async {
      final states = CardState.values;
      for (final state in states) {
        await repo.clearDeck(userId);
        final card = FSRSCard(vocabId: 'state_test', state: state);
        await repo.saveCard(userId, card);
        final loaded = (await repo.loadDeck(userId)).first;
        expect(loaded.state, equals(state), reason: 'state=$state failed');
      }
    });
  });

  group('saveCards (batch)', () {
    test('saves multiple cards in one call', () async {
      final cards = FSRSAlgorithm.buildDeck(['a', 'b', 'c', 'd', 'e']);
      await repo.saveCards(userId, cards);
      final loaded = await repo.loadDeck(userId);
      expect(loaded.length, equals(5));
    });

    test('batch save overwrites existing cards by vocabId', () async {
      final fsrs = FSRSAlgorithm();
      final originals = FSRSAlgorithm.buildDeck(['x', 'y']);
      await repo.saveCards(userId, originals);

      final updated = originals
          .map((c) => fsrs.schedule(c, Grade.easy, DateTime.now()))
          .toList();
      await repo.saveCards(userId, updated);

      final loaded = await repo.loadDeck(userId);
      expect(loaded.length, equals(2));
      for (final c in loaded) {
        expect(c.reps, equals(1));
      }
    });
  });

  group('getDueCards', () {
    test('all new cards are due immediately', () async {
      final cards = FSRSAlgorithm.buildDeck(['d1', 'd2', 'd3']);
      await repo.saveCards(userId, cards);
      final due = await repo.getDueCards(userId, DateTime.now());
      expect(due.length, equals(3));
    });

    test('card with future dueDate is not due yet', () async {
      final fsrs = FSRSAlgorithm();
      final card = fsrs.schedule(
        FSRSCard(vocabId: 'future'),
        Grade.easy,
        DateTime.now(),
      );
      // Easy → dueDate will be days in the future
      await repo.saveCard(userId, card);
      final dueNow = await repo.getDueCards(userId, DateTime.now());
      expect(dueNow, isEmpty);
    });

    test('card becomes due after its dueDate passes', () async {
      final fsrs = FSRSAlgorithm();
      final card = fsrs.schedule(
        FSRSCard(vocabId: 'past_due'),
        Grade.easy,
        DateTime.now(),
      );
      await repo.saveCard(userId, card);
      // Simulate checking far in the future
      final farFuture = DateTime.now().add(const Duration(days: 365));
      final due = await repo.getDueCards(userId, farFuture);
      expect(due.length, equals(1));
    });

    test('getDueCards returns only due subset', () async {
      final fsrs = FSRSAlgorithm();
      final now = DateTime.now();
      // Card 1: new → due now
      final c1 = FSRSCard(vocabId: 'c1');
      // Card 2: graded Easy → due in the future
      final c2 = fsrs.schedule(FSRSCard(vocabId: 'c2'), Grade.easy, now);
      // Card 3: new → due now
      final c3 = FSRSCard(vocabId: 'c3');

      await repo.saveCards(userId, [c1, c2, c3]);
      final due = await repo.getDueCards(userId, now);
      final dueIds = due.map((c) => c.vocabId).toSet();
      expect(dueIds.contains('c1'), isTrue);
      expect(dueIds.contains('c2'), isFalse);
      expect(dueIds.contains('c3'), isTrue);
    });
  });

  group('clearDeck', () {
    test('clearDeck removes all cards for user', () async {
      await repo.saveCards(userId, FSRSAlgorithm.buildDeck(['a', 'b', 'c']));
      await repo.clearDeck(userId);
      final deck = await repo.loadDeck(userId);
      expect(deck, isEmpty);
    });

    test('clearDeck only affects target user', () async {
      await repo.saveCard(userId, FSRSCard(vocabId: 'a'));
      await repo.saveCard('other_user', FSRSCard(vocabId: 'b'));
      await repo.clearDeck(userId);
      expect(await repo.loadDeck(userId), isEmpty);
      expect(await repo.loadDeck('other_user'), isNotEmpty);
    });
  });

  group('FSRS integration: persist → schedule → reload', () {
    test('full review cycle: new → schedule → persist → reload → next interval grows', () async {
      final fsrs = FSRSAlgorithm();
      final userId2 = 'user_cycle_test';

      // Day 0: new card
      final newCard = FSRSCard(vocabId: 'cycle_word');
      await repo.saveCard(userId2, newCard);

      // Review 1: Good
      var loaded = (await repo.loadDeck(userId2)).first;
      var updated = fsrs.schedule(loaded, Grade.good, DateTime(2026, 1, 1));
      await repo.saveCard(userId2, updated);
      final stability1 = updated.stability;

      // Review 2: Good (simulate day after due)
      loaded = (await repo.loadDeck(userId2)).first;
      updated = fsrs.schedule(loaded, Grade.good, updated.dueDate!);
      await repo.saveCard(userId2, updated);
      final stability2 = updated.stability;

      // Stability should grow with each successful review
      expect(stability2, greaterThan(stability1));
    });
  });
}
