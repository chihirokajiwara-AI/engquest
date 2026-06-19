// test/features/exam_practice/exam_review_store_test.dart
// #119: spaced repetition in the 英検 vocab flow. Locks that answers are
// scheduled via FSRS and that DUE (previously-missed, now-forgotten) words are
// the ones surfaced — so a session re-teaches what was missed, not random recall.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/features/exam_practice/exam_review_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recordAnswer persists a scheduled card (reps incremented)', () async {
    final store = ExamReviewStore();
    await store.recordAnswer(grade: '5', word: 'Apple', correct: false);
    // A wrong answer schedules the word; it now exists in the deck with reps>0.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('vocab_fsrs_5');
    expect(raw, isNotNull);
    final map = jsonDecode(raw!) as Map<String, dynamic>;
    expect(map.containsKey('apple'), isTrue,
        reason: 'keyed by normalised word');
    final card = FSRSCard.fromJson(map['apple'] as Map<String, dynamic>);
    expect(card.reps, greaterThan(0));
  });

  test('dueReviewKeys returns previously-seen words whose dueDate has passed',
      () async {
    // Seed: one word due in the PAST (forgotten → should re-surface), one due in
    // the FUTURE (recently learned → not yet), one brand-NEW (reps 0 → fill pool).
    final past = DateTime.now().subtract(const Duration(days: 2));
    final future = DateTime.now().add(const Duration(days: 5));
    final seed = {
      'forgot': FSRSCard(vocabId: 'forgot', reps: 2, dueDate: past).toJson(),
      'fresh': FSRSCard(vocabId: 'fresh', reps: 1, dueDate: future).toJson(),
      'newword': FSRSCard(vocabId: 'newword', reps: 0).toJson(),
    };
    SharedPreferences.setMockInitialValues({'vocab_fsrs_5': jsonEncode(seed)});

    final due = await ExamReviewStore().dueReviewKeys('5');
    expect(due, contains('forgot'));
    expect(due, isNot(contains('fresh')), reason: 'future due-date not yet');
    expect(due, isNot(contains('newword')), reason: 'never-seen = fill pool');
  });

  test('a correct unaided answer is NOT immediately due again (good schedule)',
      () async {
    final store = ExamReviewStore();
    await store.recordAnswer(grade: '5', word: 'dog', correct: true);
    final due = await store.dueReviewKeys('5');
    expect(due, isNot(contains('dog')),
        reason:
            'a learned word should be scheduled into the future, not re-shown now');
  });

  test(
      'concurrent fire-and-forget answers do NOT clobber each other (write-race)',
      () async {
    // recordAnswer is called unawaited from the UI; a child answering quickly
    // issues overlapping load→schedule→save cycles. Without serialisation each
    // reads the same baseline blob and the last save wins, silently dropping the
    // other words' schedules (a missed word never re-surfaces; 合格率 inflates).
    // Fire 5 distinct words concurrently and require ALL 5 to persist.
    final store = ExamReviewStore();
    final words = ['alpha', 'bravo', 'charlie', 'delta', 'echo'];
    await Future.wait([
      for (final w in words)
        store.recordAnswer(grade: '5', word: w, correct: false),
    ]);
    final prefs = await SharedPreferences.getInstance();
    final map =
        jsonDecode(prefs.getString('vocab_fsrs_5')!) as Map<String, dynamic>;
    for (final w in words) {
      expect(map.containsKey(w), isTrue,
          reason:
              '$w must survive concurrent writes (no last-write-wins clobber)');
    }
  });

  test('grades are namespaced — 5級 reviews do not leak into 4級', () async {
    final store = ExamReviewStore();
    await store.recordAnswer(grade: '5', word: 'cat', correct: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vocab_fsrs_4'), isNull);
  });

  test(
      'sections are namespaced — wordorder uses its own key, no vocab collision',
      () async {
    // #118: each exam section gets an independent FSRS review schedule, so a
    // missed 語句整序 sentence can re-test without colliding with a vocab word.
    final wo = ExamReviewStore(section: 'wordorder');
    await wo.recordAnswer(grade: '5', word: '彼は古い写真を見せてくれた。', correct: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fsrs_review_wordorder_5'), isNotNull,
        reason: 'wordorder writes to its own namespace');
    expect(prefs.getString('vocab_fsrs_5'), isNull,
        reason: 'and must NOT leak into the legacy vocab key');
    // The default section still uses the ORIGINAL key — existing 大問1 review
    // data is preserved, not orphaned under a new scheme.
    await ExamReviewStore()
        .recordAnswer(grade: '5', word: 'apple', correct: false);
    expect(prefs.getString('vocab_fsrs_5'), isNotNull);
    expect(prefs.getString('fsrs_review_vocab_5'), isNull,
        reason: 'default section keeps the legacy key for backward compat');
  });
}
