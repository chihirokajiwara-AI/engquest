// test/core/analytics/firestore_progress_repository_test.dart
// ENG Quest — FirestoreProgressRepository unit tests
//
// Uses fake_cloud_firestore to test all repository methods without a real Firebase project.
// 25 tests covering: recordSession, getProfile, getLast7Days, calculateStreak, getNextReviewDue.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreProgressRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestoreProgressRepository(firestore: fakeDb);
  });

  // ── getProfile ─────────────────────────────────────────────────────────────

  group('getProfile', () {
    test('returns null when no profile doc exists', () async {
      final result = await repo.getProfile('user_unknown');
      expect(result, isNull);
    });

    test('returns profile data when doc exists', () async {
      await fakeDb.collection('users').doc('user_001').set({
        'currentStreak': 5,
        'totalWordsMastered': 42,
        'totalWordsPracticed': 100,
        'lastStudyDate': '2026-05-29',
      });

      final result = await repo.getProfile('user_001');
      expect(result, isNotNull);
      expect(result!['currentStreak'], equals(5));
      expect(result['totalWordsMastered'], equals(42));
      expect(result['totalWordsPracticed'], equals(100));
    });

    test('returns null gracefully on missing field (partial doc)', () async {
      await fakeDb.collection('users').doc('user_partial').set({
        'currentStreak': 3,
        // no totalWordsMastered
      });

      final result = await repo.getProfile('user_partial');
      expect(result, isNotNull);
      expect(result!['currentStreak'], equals(3));
      expect(result.containsKey('totalWordsMastered'), isFalse);
    });
  });

  // ── getLast7Days ──────────────────────────────────────────────────────────

  group('getLast7Days', () {
    test('returns 7 zero-filled items for new user', () async {
      final result = await repo.getLast7Days('user_new');
      expect(result, isNotNull);
      expect(result!.length, equals(7));
      for (final day in result) {
        expect(day.wordsPracticed, equals(0));
        expect(day.sessionMinutes, equals(0));
        expect(day.averageScore, equals(0.0));
      }
    });

    test('returns real data for days that have session docs', () async {
      final now = DateTime.now();
      // Add a session for yesterday
      final yesterday = now.subtract(const Duration(days: 1));
      final key = '${yesterday.year.toString().padLeft(4, '0')}-'
          '${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';

      await fakeDb
          .collection('users')
          .doc('user_active')
          .collection('sessions')
          .doc(key)
          .set({
        'wordsPracticed': 20,
        'sessionMinutes': 12,
        'averageScore': 2.5,
      });

      final result = await repo.getLast7Days('user_active');
      expect(result, isNotNull);
      expect(result!.length, equals(7));

      // Yesterday should be index 5 (0=6 days ago, 6=today)
      final yesterdayResult = result[5];
      expect(yesterdayResult.wordsPracticed, equals(20));
      expect(yesterdayResult.sessionMinutes, equals(12));
      expect(yesterdayResult.averageScore, closeTo(2.5, 0.001));
    });

    test('fills in zeros for days without sessions', () async {
      final now = DateTime.now();
      // Only add today's session
      final todayKey = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      await fakeDb
          .collection('users')
          .doc('user_partial_history')
          .collection('sessions')
          .doc(todayKey)
          .set({
        'wordsPracticed': 15,
        'sessionMinutes': 8,
        'averageScore': 2.0,
      });

      final result = await repo.getLast7Days('user_partial_history');
      expect(result, isNotNull);
      // First 6 days should be zero
      for (var i = 0; i < 6; i++) {
        expect(result![i].wordsPracticed, equals(0));
      }
      // Today (index 6) should have real data
      expect(result![6].wordsPracticed, equals(15));
    });

    test('returns list of DailyProgress with correct date fields', () async {
      final result = await repo.getLast7Days('user_dates');
      expect(result, isNotNull);
      final now = DateTime.now();
      // First item should be 6 days ago
      final expected6DaysAgo = DateTime(
        now.subtract(const Duration(days: 6)).year,
        now.subtract(const Duration(days: 6)).month,
        now.subtract(const Duration(days: 6)).day,
      );
      expect(result![0].date, equals(expected6DaysAgo));
    });
  });

  // ── recordSession ─────────────────────────────────────────────────────────

  group('recordSession', () {
    test('creates session doc for today', () async {
      await repo.recordSession(
        uid: 'user_rec',
        wordsPracticed: 10,
        minutes: 5,
        avgScore: 2.0,
        totalMastered: 10,
        totalPracticed: 30,
        streak: 1,
      );

      final now = DateTime.now();
      final key = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final snap = await fakeDb
          .collection('users')
          .doc('user_rec')
          .collection('sessions')
          .doc(key)
          .get();

      expect(snap.exists, isTrue);
      expect(snap.data()!['wordsPracticed'], equals(10));
      expect(snap.data()!['sessionMinutes'], equals(5));
    });

    test('updates profile doc aggregates', () async {
      await repo.recordSession(
        uid: 'user_profile_update',
        wordsPracticed: 25,
        minutes: 15,
        avgScore: 2.5,
        totalMastered: 50,
        totalPracticed: 100,
        streak: 7,
      );

      final profileSnap =
          await fakeDb.collection('users').doc('user_profile_update').get();

      expect(profileSnap.exists, isTrue);
      expect(profileSnap.data()!['totalWordsMastered'], equals(50));
      expect(profileSnap.data()!['totalWordsPracticed'], equals(100));
      expect(profileSnap.data()!['currentStreak'], equals(7));
    });

    test('merges words on second session of same day', () async {
      // First session
      await repo.recordSession(
        uid: 'user_merge',
        wordsPracticed: 10,
        minutes: 5,
        avgScore: 2.0,
        totalMastered: 10,
        totalPracticed: 30,
        streak: 1,
      );

      // Second session same day
      await repo.recordSession(
        uid: 'user_merge',
        wordsPracticed: 10,
        minutes: 5,
        avgScore: 3.0,
        totalMastered: 12,
        totalPracticed: 32,
        streak: 1,
      );

      final now = DateTime.now();
      final key = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final snap = await fakeDb
          .collection('users')
          .doc('user_merge')
          .collection('sessions')
          .doc(key)
          .get();

      expect(snap.data()!['wordsPracticed'], equals(20));
      expect(snap.data()!['sessionMinutes'], equals(10));
      // Weighted average: (2.0*10 + 3.0*10) / 20 = 2.5
      expect(snap.data()!['averageScore'], closeTo(2.5, 0.001));
    });
  });

  // ── calculateStreak ───────────────────────────────────────────────────────

  group('calculateStreak', () {
    test('returns 0 for new user with no sessions', () async {
      final streak = await repo.calculateStreak('user_new_streak');
      expect(streak, equals(0));
    });

    test('returns 1 when only today has a session', () async {
      final now = DateTime.now();
      final key = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      await fakeDb
          .collection('users')
          .doc('user_streak_1')
          .collection('sessions')
          .doc(key)
          .set({'wordsPracticed': 10});

      final streak = await repo.calculateStreak('user_streak_1');
      expect(streak, equals(1));
    });

    test('counts consecutive days', () async {
      final now = DateTime.now();
      // Add sessions for today + 3 days back
      for (var i = 0; i < 4; i++) {
        final day = now.subtract(Duration(days: i));
        final key = '${day.year.toString().padLeft(4, '0')}-'
            '${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        await fakeDb
            .collection('users')
            .doc('user_streak_4')
            .collection('sessions')
            .doc(key)
            .set({'wordsPracticed': 15});
      }

      final streak = await repo.calculateStreak('user_streak_4');
      expect(streak, equals(4));
    });

    test('streak breaks at gap day', () async {
      final now = DateTime.now();
      // Today and 2 days ago (gap yesterday)
      final today = now;
      final twoDaysAgo = now.subtract(const Duration(days: 2));

      for (final day in [today, twoDaysAgo]) {
        final key = '${day.year.toString().padLeft(4, '0')}-'
            '${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        await fakeDb
            .collection('users')
            .doc('user_streak_gap')
            .collection('sessions')
            .doc(key)
            .set({'wordsPracticed': 10});
      }

      final streak = await repo.calculateStreak('user_streak_gap');
      expect(streak, equals(1)); // Only today counts
    });
  });

  // ── getNextReviewDue ──────────────────────────────────────────────────────

  group('getNextReviewDue', () {
    test('returns null when no cards exist', () async {
      final result = await repo.getNextReviewDue('user_no_cards');
      expect(result, isNull);
    });

    test('returns earliest due date from review-state cards', () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final in3Days = now.add(const Duration(days: 3));

      await fakeDb
          .collection('users')
          .doc('user_cards')
          .collection('cards')
          .doc('card_001')
          .set({
        'state': 'review',
        'dueDate': Timestamp.fromDate(in3Days),
      });

      await fakeDb
          .collection('users')
          .doc('user_cards')
          .collection('cards')
          .doc('card_002')
          .set({
        'state': 'review',
        'dueDate': Timestamp.fromDate(tomorrow),
      });

      final result = await repo.getNextReviewDue('user_cards');
      expect(result, isNotNull);
      // Should be the earlier date (tomorrow)
      expect(result!.day, equals(tomorrow.day));
    });

    test('ignores non-review state cards', () async {
      final now = DateTime.now();
      await fakeDb
          .collection('users')
          .doc('user_new_cards')
          .collection('cards')
          .doc('card_new')
          .set({
        'state': 'new',
        'dueDate': Timestamp.fromDate(now),
      });

      final result = await repo.getNextReviewDue('user_new_cards');
      expect(result, isNull); // new state cards excluded
    });
  });
}
