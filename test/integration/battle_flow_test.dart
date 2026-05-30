// test/integration/battle_flow_test.dart
// ENG Quest — Integration: Battle Session End-to-End Flow
//
// Tests the full battle loop:
//   Start session → show card → grade → FSRS update → next card
//
// Run: dart test test/integration/battle_flow_test.dart

import 'package:test/test.dart';
import 'package:engquest/core/fsrs/fsrs_algorithm.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/data/models/vocab_item.dart';

// ---------------------------------------------------------------------------
// Minimal in-memory battle session (mirrors BattleScreen logic without Flutter)
// ---------------------------------------------------------------------------

class BattleSession {
  final FSRSAlgorithm fsrs = FSRSAlgorithm();
  final List<VocabItem> vocab;
  late List<FSRSCard> deck;
  late List<int> queue;
  int queueIdx = 0;
  final List<({String wordId, Grade grade, FSRSCard before, FSRSCard after})> history = [];

  BattleSession(this.vocab) {
    deck = vocab.map((v) => FSRSCard(vocabId: v.id)).toList();
    final now = DateTime.now();
    final due = fsrs.getDueCards(deck, now);
    queue = due
        .map((c) => deck.indexWhere((d) => d.vocabId == c.vocabId))
        .where((i) => i >= 0)
        .toList();
    queueIdx = 0;
  }

  bool get isComplete => queueIdx >= queue.length;
  int get currentDeckIdx => queue[queueIdx];
  VocabItem get currentVocab => vocab[currentDeckIdx];
  FSRSCard get currentCard => deck[currentDeckIdx];

  /// Grade the current card and advance to the next.
  FSRSCard grade(Grade g) {
    final now = DateTime.now();
    final before = currentCard;
    final after = fsrs.schedule(before, g, now);
    deck[currentDeckIdx] = after;
    history.add((wordId: before.vocabId, grade: g, before: before, after: after));

    // Re-queue learning/relearning cards (same as BattleScreen logic)
    if (after.state == CardState.learning || after.state == CardState.relearning) {
      final insertAt = (queueIdx + 3).clamp(0, queue.length);
      queue.insert(insertAt, currentDeckIdx);
    }
    queueIdx++;
    return after;
  }

  /// Summary statistics for the session.
  Map<Grade, int> get gradeCounts {
    final counts = <Grade, int>{for (final g in Grade.values) g: 0};
    for (final h in history) {
      counts[h.grade] = (counts[h.grade] ?? 0) + 1;
    }
    return counts;
  }
}

// ---------------------------------------------------------------------------
// Test data — 5 A1 words
// ---------------------------------------------------------------------------

const _testVocab = [
  VocabItem(
    id: 'test_001', word: 'cat', reading: 'キャット', jpTranslation: 'ねこ',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],
    exampleSentences: ['I have a cat.'],
  ),
  VocabItem(
    id: 'test_002', word: 'dog', reading: 'ドッグ', jpTranslation: 'いぬ',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],
    exampleSentences: ['My dog is big.'],
  ),
  VocabItem(
    id: 'test_003', word: 'apple', reading: 'アップル', jpTranslation: 'りんご',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],
    exampleSentences: ['I eat an apple.'],
  ),
  VocabItem(
    id: 'test_004', word: 'run', reading: 'ラン', jpTranslation: 'はしる',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['verb'],
    exampleSentences: ['I run every day.'],
  ),
  VocabItem(
    id: 'test_005', word: 'red', reading: 'レッド', jpTranslation: 'あか',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['adjective'],
    exampleSentences: ['The apple is red.'],
  ),
];

// ---------------------------------------------------------------------------
// Integration tests
// ---------------------------------------------------------------------------

void main() {
  group('BattleSession — start session', () {
    test('all 5 new cards are due on first run', () {
      final session = BattleSession(_testVocab);
      expect(session.queue.length, equals(5));
      expect(session.isComplete, isFalse);
    });

    test('initial card state is newCard', () {
      final session = BattleSession(_testVocab);
      expect(session.currentCard.state, equals(CardState.newCard));
      expect(session.currentCard.reps, equals(0));
    });

    test('deck has exactly one FSRSCard per vocab item', () {
      final session = BattleSession(_testVocab);
      expect(session.deck.length, equals(_testVocab.length));
      for (var i = 0; i < _testVocab.length; i++) {
        expect(session.deck[i].vocabId, equals(_testVocab[i].id));
      }
    });
  });

  group('BattleSession — grade card', () {
    test('grading Good advances card to Learning state', () {
      final session = BattleSession(_testVocab);
      final after = session.grade(Grade.good);
      expect(after.state, equals(CardState.learning));
      expect(after.reps, equals(1));
      expect(after.stability, greaterThan(0));
    });

    test('grading Easy produces highest stability', () {
      final fsrs = FSRSAlgorithm();
      final card = FSRSCard(vocabId: 'x');
      final now = DateTime.now();
      final cardEasy = fsrs.schedule(card, Grade.easy, now);
      final cardGood = fsrs.schedule(card, Grade.good, now);
      final cardHard = fsrs.schedule(card, Grade.hard, now);
      final cardAgain = fsrs.schedule(card, Grade.again, now);
      expect(cardEasy.stability, greaterThan(cardGood.stability));
      expect(cardGood.stability, greaterThan(cardHard.stability));
      expect(cardHard.stability, greaterThan(cardAgain.stability));
    });

    test('grading Again re-queues card for re-study', () {
      final session = BattleSession(_testVocab);
      final initialQueueLength = session.queue.length;
      session.grade(Grade.again); // Again → state = learning → re-queued
      // Queue should grow by 1 (card re-inserted)
      expect(session.queue.length, greaterThan(initialQueueLength));
    });

    test('grading Good does not re-queue card immediately', () {
      final session = BattleSession(_testVocab);
      final initialQueueLength = session.queue.length;
      session.grade(Grade.good);
      // After Good → moves to review, no re-insertion in first session
      // Queue length stays same (card consumed, not re-added)
      expect(session.queue.length, equals(initialQueueLength));
    });

    test('queue index advances after each grade', () {
      final session = BattleSession(_testVocab);
      expect(session.queueIdx, equals(0));
      session.grade(Grade.good);
      expect(session.queueIdx, equals(1));
      session.grade(Grade.good);
      expect(session.queueIdx, equals(2));
    });
  });

  group('BattleSession — FSRS state update', () {
    test('FSRS card updates persist in deck across grades', () {
      final session = BattleSession(_testVocab);
      final firstIdx = session.currentDeckIdx;
      final before = session.deck[firstIdx];
      session.grade(Grade.good);
      final after = session.deck[firstIdx];
      // Card should have been updated
      expect(after.reps, greaterThan(before.reps));
      expect(after.stability, isNot(equals(before.stability)));
    });

    test('graded card has a future dueDate', () {
      final session = BattleSession(_testVocab);
      session.grade(Grade.good);
      final graded = session.history.first.after;
      expect(graded.dueDate, isNotNull);
      expect(graded.dueDate!.isAfter(DateTime.now()), isTrue);
    });

    test('lastReview is set to approximately now', () {
      final before = DateTime.now();
      final session = BattleSession(_testVocab);
      session.grade(Grade.good);
      final after = DateTime.now();
      final graded = session.history.first.after;
      expect(graded.lastReview, isNotNull);
      expect(graded.lastReview!.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(graded.lastReview!.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('BattleSession — next card', () {
    test('session advances to next card after grading', () {
      final session = BattleSession(_testVocab);
      // Verify session has a valid card before grading
      expect(session.currentVocab.word, isNotEmpty);
      session.grade(Grade.good);
      // Should show a different card (assuming queue order differs)
      expect(session.isComplete, isFalse);
      // If queue is a permutation, next card has different deck idx
      // (or same — it's shuffled, so just verify we advanced)
      expect(session.queueIdx, equals(1));
    });

    test('session completes after all cards graded with Good', () {
      final session = BattleSession(_testVocab);
      final total = session.queue.length;
      for (var i = 0; i < total; i++) {
        expect(session.isComplete, isFalse);
        session.grade(Grade.good);
      }
      expect(session.isComplete, isTrue);
    });
  });

  group('BattleSession — session summary', () {
    test('history records every graded card', () {
      final session = BattleSession(_testVocab);
      final total = session.queue.length;
      for (var i = 0; i < total; i++) {
        if (session.isComplete) break;
        session.grade(Grade.good);
      }
      expect(session.history.length, equals(total));
    });

    test('grade counts sum to total history entries', () {
      final session = BattleSession(_testVocab);
      final grades = [Grade.again, Grade.hard, Grade.good, Grade.easy, Grade.good];
      for (var i = 0; i < session.queue.length && i < grades.length; i++) {
        if (session.isComplete) break;
        session.grade(grades[i]);
      }
      final counts = session.gradeCounts;
      final total = counts.values.fold(0, (a, b) => a + b);
      expect(total, equals(session.history.length));
    });

    test('average retrievability after Good grades is above 0.5', () {
      final session = BattleSession(_testVocab);
      for (var i = 0; i < session.queue.length; i++) {
        if (session.isComplete) break;
        session.grade(Grade.good);
      }
      final now = DateTime.now();
      final avgR = session.deck
          .where((c) => c.reps > 0)
          .map((c) => session.fsrs.retrievability(c, now))
          .fold(0.0, (a, b) => a + b) /
          session.deck.where((c) => c.reps > 0).length;
      expect(avgR, greaterThan(0.5));
    });
  });
}
