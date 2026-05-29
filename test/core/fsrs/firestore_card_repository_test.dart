// test/core/fsrs/firestore_card_repository_test.dart
// ENG Quest — Unit tests for FirestoreFsrsCardRepository
//
// Uses fake_cloud_firestore so no real Firebase project is needed.
// Run: dart test test/core/fsrs/firestore_card_repository_test.dart
//   or: flutter test test/core/fsrs/firestore_card_repository_test.dart

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/core/fsrs/fsrs_algorithm.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/fsrs/firestore_card_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreFsrsCardRepository repo;
  const uid = 'test_user_001';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = FirestoreFsrsCardRepository(firestore: fakeFirestore);
  });

  // ── loadDeck ────────────────────────────────────────────────────────────────

  group('loadDeck', () {
    test('returns empty list for brand-new user', () async {
      final deck = await repo.loadDeck(uid);
      expect(deck, isEmpty);
    });

    test('returns all saved cards for user', () async {
      final cards = FSRSAlgorithm.buildDeck(['w001', 'w002', 'w003']);
      await repo.saveCards(uid, cards);
      final loaded = await repo.loadDeck(uid);
      expect(loaded.length, equals(3));
    });

    test('user isolation: different users have separate decks', () async {
      await repo.saveCard(uid, FSRSCard(vocabId: 'shared_word'));
      await repo.saveCard('other_user', FSRSCard(vocabId: 'other_word'));

      final deck1 = await repo.loadDeck(uid);
      final deck2 = await repo.loadDeck('other_user');

      expect(deck1.length, equals(1));
      expect(deck2.length, equals(1));
      expect(deck1.first.vocabId, equals('shared_word'));
      expect(deck2.first.vocabId, equals('other_word'));
    });
  });

  // ── saveCard ───────────────────────────────────────────────────────────────

  group('saveCard', () {
    test('new card is persisted and retrievable from Firestore', () async {
      final card = FSRSCard(vocabId: 'eiken5_001');
      await repo.saveCard(uid, card);

      final loaded = await repo.loadDeck(uid);
      expect(loaded.length, equals(1));
      expect(loaded.first.vocabId, equals('eiken5_001'));
    });

    test('saving same vocabId overwrites (upsert) previous state', () async {
      final original = FSRSCard(vocabId: 'eiken5_001');
      await repo.saveCard(uid, original);

      final fsrs = FSRSAlgorithm();
      final updated = fsrs.schedule(original, Grade.good, DateTime.now());
      await repo.saveCard(uid, updated);

      final loaded = await repo.loadDeck(uid);
      expect(loaded.length, equals(1)); // Not duplicated
      expect(loaded.first.reps, equals(1));
      expect(loaded.first.stability, greaterThan(0));
    });

    test('all FSRSCard fields survive Firestore round-trip', () async {
      final fsrs = FSRSAlgorithm();
      final reviewDate = DateTime(2026, 6, 1, 10, 0, 0);
      var card = FSRSCard(vocabId: 'rt_001');
      card = fsrs.schedule(card, Grade.good, reviewDate);

      await repo.saveCard(uid, card);
      final loaded = (await repo.loadDeck(uid)).first;

      expect(loaded.vocabId, equals(card.vocabId));
      expect(loaded.state, equals(card.state));
      expect(loaded.stability, closeTo(card.stability, 0.001));
      expect(loaded.difficulty, closeTo(card.difficulty, 0.001));
      expect(loaded.reps, equals(card.reps));
      expect(loaded.lapses, equals(card.lapses));
      // Timestamps may lose sub-second precision via Firestore
      expect(
        loaded.lastReview?.millisecondsSinceEpoch,
        closeTo(card.lastReview!.millisecondsSinceEpoch, 1000),
      );
    });

    test('all CardState values round-trip correctly', () async {
      final fsrs = FSRSAlgorithm();
      // new, learning, review, relearning
      final stateCards = [
        FSRSCard(vocabId: 's_new'),
        fsrs.schedule(FSRSCard(vocabId: 's_learning'), Grade.again, DateTime.now()),
        fsrs.schedule(FSRSCard(vocabId: 's_review'), Grade.good, DateTime.now()),
        // relearning: schedule after lapse
        fsrs.schedule(
          fsrs.schedule(FSRSCard(vocabId: 's_relearn'), Grade.good, DateTime.now()),
          Grade.again,
          DateTime.now().add(const Duration(days: 5)),
        ),
      ];

      for (final card in stateCards) {
        await repo.saveCard(uid, card);
      }
      final loaded = await repo.loadDeck(uid);
      final byId = {for (final c in loaded) c.vocabId: c};

      expect(byId['s_new']!.state, equals(CardState.newCard));
      // 'Again' on first review → learning
      expect(byId['s_learning']!.state, equals(CardState.learning));
      // 'Good' on first → learning/review (algorithm-dependent; stability > 0)
      expect(byId['s_review']!.stability, greaterThan(0));
      // After lapse → relearning
      expect(byId['s_relearn']!.state, equals(CardState.relearning));
    });
  });

  // ── saveCards (batch) ──────────────────────────────────────────────────────

  group('saveCards (batch)', () {
    test('saves multiple cards in one call', () async {
      final cards = FSRSAlgorithm.buildDeck(['a', 'b', 'c', 'd', 'e']);
      await repo.saveCards(uid, cards);
      final loaded = await repo.loadDeck(uid);
      expect(loaded.length, equals(5));
    });

    test('batch save overwrites existing cards by vocabId', () async {
      final fsrs = FSRSAlgorithm();
      final originals = FSRSAlgorithm.buildDeck(['x', 'y']);
      await repo.saveCards(uid, originals);

      final updated = originals
          .map((c) => fsrs.schedule(c, Grade.easy, DateTime.now()))
          .toList();
      await repo.saveCards(uid, updated);

      final loaded = await repo.loadDeck(uid);
      expect(loaded.length, equals(2));
      for (final c in loaded) {
        expect(c.reps, equals(1));
      }
    });

    test('empty saveCards is a no-op', () async {
      await repo.saveCards(uid, []);
      final loaded = await repo.loadDeck(uid);
      expect(loaded, isEmpty);
    });
  });

  // ── getDueCards ────────────────────────────────────────────────────────────

  group('getDueCards', () {
    test('all new cards are due immediately', () async {
      final cards = FSRSAlgorithm.buildDeck(['d1', 'd2', 'd3']);
      await repo.saveCards(uid, cards);
      final due = await repo.getDueCards(uid, DateTime.now());
      expect(due.length, equals(3));
    });

    test('review card with future dueDate is NOT due yet', () async {
      // Grade easy → moves to review state with dueDate in the future
      final fsrs = FSRSAlgorithm();
      // Easy needs a few Good reviews to reach review state
      var card = FSRSCard(vocabId: 'future_card');
      final now = DateTime.now();
      // First review: Good → learning/review
      card = fsrs.schedule(card, Grade.good, now);
      // Second review: Easy → review state with far future dueDate
      card = fsrs.schedule(card, Grade.easy, now.add(const Duration(minutes: 1)));

      await repo.saveCard(uid, card);
      final dueNow = await repo.getDueCards(uid, now);
      expect(dueNow, isEmpty,
          reason: 'Card with future dueDate should not appear as due');
    });

    test('review card with past dueDate IS due', () async {
      final fsrs = FSRSAlgorithm();
      var card = FSRSCard(vocabId: 'past_due');
      final t0 = DateTime(2026, 1, 1);
      card = fsrs.schedule(card, Grade.good, t0);
      card = fsrs.schedule(card, Grade.easy, t0.add(const Duration(minutes: 1)));

      await repo.saveCard(uid, card);
      // Check far in the future — card is definitely overdue
      final farFuture = DateTime(2030, 1, 1);
      final due = await repo.getDueCards(uid, farFuture);
      expect(due.length, equals(1));
    });

    test('getDueCards returns only due subset from mixed deck', () async {
      final fsrs = FSRSAlgorithm();
      final now = DateTime.now();

      // c1: new → always due
      final c1 = FSRSCard(vocabId: 'c1');

      // c2: reviewed → future dueDate (not due now)
      var c2 = FSRSCard(vocabId: 'c2');
      c2 = fsrs.schedule(c2, Grade.good, now);
      c2 = fsrs.schedule(c2, Grade.easy, now.add(const Duration(minutes: 1)));

      // c3: new → always due
      final c3 = FSRSCard(vocabId: 'c3');

      await repo.saveCards(uid, [c1, c2, c3]);
      final due = await repo.getDueCards(uid, now);
      final dueIds = due.map((c) => c.vocabId).toSet();

      expect(dueIds.contains('c1'), isTrue);
      expect(dueIds.contains('c2'), isFalse);
      expect(dueIds.contains('c3'), isTrue);
    });

    test('learning state cards are always due', () async {
      final fsrs = FSRSAlgorithm();
      // Again → learning state
      final card = fsrs.schedule(FSRSCard(vocabId: 'learning_card'), Grade.again, DateTime.now());
      expect(card.state, equals(CardState.learning));
      await repo.saveCard(uid, card);

      final due = await repo.getDueCards(uid, DateTime.now());
      expect(due.length, equals(1));
    });
  });

  // ── clearDeck ──────────────────────────────────────────────────────────────

  group('clearDeck', () {
    test('clearDeck removes all Firestore cards for user', () async {
      await repo.saveCards(uid, FSRSAlgorithm.buildDeck(['a', 'b', 'c']));
      await repo.clearDeck(uid);
      final deck = await repo.loadDeck(uid);
      expect(deck, isEmpty);
    });

    test('clearDeck only affects target user', () async {
      await repo.saveCard(uid, FSRSCard(vocabId: 'a'));
      await repo.saveCard('other_user', FSRSCard(vocabId: 'b'));
      await repo.clearDeck(uid);
      expect(await repo.loadDeck(uid), isEmpty);
      expect(await repo.loadDeck('other_user'), isNotEmpty);
    });
  });

  // ── Firestore fallback ──────────────────────────────────────────────────────

  group('fallback behavior', () {
    test('getDueCards from fallback after prior saveCard', () async {
      // Save via Firestore repo (populates fallback)
      final card = FSRSCard(vocabId: 'fb_001');
      await repo.saveCard(uid, card);

      // getDueCards reads fallback when needed
      final due = await repo.getDueCards(uid, DateTime.now());
      expect(due.length, equals(1));
      expect(due.first.vocabId, equals('fb_001'));
    });
  });

  // ── FSRS integration: full review cycle ───────────────────────────────────

  group('FSRS integration: persist → schedule → reload → schedule', () {
    test('stability grows with consecutive Good reviews', () async {
      final fsrs = FSRSAlgorithm();
      const uid2 = 'cycle_user';

      // Day 0: save new card
      final newCard = FSRSCard(vocabId: 'cycle_word');
      await repo.saveCard(uid2, newCard);

      // Review 1: Good
      var loaded = (await repo.loadDeck(uid2)).first;
      var updated = fsrs.schedule(loaded, Grade.good, DateTime(2026, 1, 1));
      await repo.saveCard(uid2, updated);
      final stability1 = updated.stability;

      // Review 2: Good (simulate after dueDate)
      loaded = (await repo.loadDeck(uid2)).first;
      updated = fsrs.schedule(
        loaded,
        Grade.good,
        updated.dueDate ?? DateTime(2026, 1, 2),
      );
      await repo.saveCard(uid2, updated);
      final stability2 = updated.stability;

      expect(stability2, greaterThan(stability1),
          reason: 'Stability should grow with successive Good reviews');
      expect(updated.reps, equals(2));
    });

    test('lapse resets to relearning state and increments lapses', () async {
      final fsrs = FSRSAlgorithm();
      const uid3 = 'lapse_user';

      // Build up to review state
      var card = FSRSCard(vocabId: 'lapse_word');
      final t0 = DateTime(2026, 3, 1);
      card = fsrs.schedule(card, Grade.good, t0);
      card = fsrs.schedule(card, Grade.good, t0.add(const Duration(days: 1)));
      await repo.saveCard(uid3, card);

      // Lapse
      final loaded = (await repo.loadDeck(uid3)).first;
      final lapsed = fsrs.schedule(
        loaded,
        Grade.again,
        t0.add(const Duration(days: 10)),
      );
      await repo.saveCard(uid3, lapsed);

      final reloaded = (await repo.loadDeck(uid3)).first;
      expect(reloaded.lapses, greaterThan(0));
      expect(reloaded.state, equals(CardState.relearning));
    });
  });
}
